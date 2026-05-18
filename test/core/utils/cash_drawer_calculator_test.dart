import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/repository/repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_desktop/src/core/utils/cash_drawer_calculator.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

class MockPaymentsRepository extends Mock implements PaymentsRepository {}

void main() {
  group('CashDrawerCalculator Tests', () {
    late Map<String, dynamic> mockSession;
    late Map<String, dynamic> mockUser;
    late List<Map<String, dynamic>> mockAllSessionsToday;
    late MockPaymentsRepository mockPaymentsRepo;

    setUp(() {
      mockPaymentsRepo = MockPaymentsRepository();
      final getIt = GetIt.I;
      if (getIt.isRegistered<PaymentsRepository>()) {
        getIt.unregister<PaymentsRepository>();
      }
      getIt.registerSingleton<PaymentsRepository>(mockPaymentsRepo);

      // Default mock response
      when(() => mockPaymentsRepo.getPayments()).thenAnswer(
        (_) async => ApiResult.success(data: PaymentsResponse(data: [])),
      );

      mockSession = {
        'id': 1,
        'opening_balance': 100.0,
        'user_id': 123,
      };
      mockUser = {
        'id': 123,
        'firstname': 'John',
        'lastname': 'Doe',
      };
      mockAllSessionsToday = [
        {
          'id': 2,
          'user_id': 123,
          'revenue_amount': 500.0,
          'closed_at': DateTime.now().toIso8601String(),
          'firstname': 'John',
          'lastname': 'Doe',
        }
      ];
    });

    test(
        'computeSessionSummary should return correct summary for a basic order',
        () async {
      // Given
      final orders = [
        OrderHiveModel(
          id: 1,
          totalPrice: 115.0,
          body: OrderBodyData(
            deliveryType: 'dine_in',
            userId: 123,
            phone: '',
            address: AddressModel(),
            deliveryDate: '',
            deliveryTime: '',
            bagData: BagData(),
            billDiscountAmount: 10.0,
            enhancedProducts: [
              EnhancedProductOrder(
                stockId: 1,
                quantity: 1,
                originalPrice: 100.0,
                finalPrice: 125.0,
                itemDiscountAmount: 0.0,
                taxAmount: 15.0,
                serviceChargeAmount: 10.0,
                categoryId: 1,
                categoryName: 'Food',
              ),
            ],
          ),
        ),
      ];

      final transactions = [
        {
          'order_id': 1,
          'payment_tag': 'cash',
          'price': 115.0,
        }
      ];

      // When
      final summary = await CashDrawerCalculator.computeSessionSummary(
        orders: orders,
        transactions: transactions,
        session: mockSession,
        allSessionsToday: mockAllSessionsToday,
        currentUser: mockUser,
      );

      // Then
      expect(summary['date'], DateFormat('yyyy-MM-dd').format(DateTime.now()));

      // 1. Revenue Summary
      final rev = summary['revenue_summary'];
      expect(rev['cash_sales'],
          90.0); // 100 (origin) - 0 (detail discount) - 10 (bill discount) = 90
      expect(rev['service_charge'], 10.0);
      expect(rev['tax'], 15.0);
      expect(rev['rounding'],
          0.0); // Updated: Rounding is now 0.0 by default in new implementation
      expect(rev['total'], 115.0);

      // 2. Service Types
      final serviceTypes = summary['service_types'];
      expect(serviceTypes['total'], 115.0);
      expect(serviceTypes['items'][0]['type'], 'Dine In');
      expect(serviceTypes['items'][0]['amount'], 115.0);
      expect(serviceTypes['items'][0]['percentage'], 100.0);

      // 3. MOP Collections
      final mop = summary['mop_collections'];
      expect(mop['total'], 115.0);
      expect(mop['count'], 1);
      expect(mop['items'][0]['method'], 'Cash');
      expect(mop['items'][0]['amount'], 115.0);

      // 4. Cashier Collections
      final cashier = summary['cashier_collections'];
      expect(cashier['total'], 115.0);
      expect(cashier['items'][0]['name'], 'John Doe');
      expect(cashier['items'][0]['amount'], 115.0);

      // 5. Categories
      final categories = summary['categories'];
      expect(categories['total'], 115.0); // 125 - 10 (proportional discount)
      expect(categories['qty'], 1);
      expect(categories['items'][0]['name'], 'Food');
      expect(categories['items'][0]['amount'], 115.0);

      // 6. Tax Summary
      final tax = summary['tax_summary'];
      expect(tax['gross'], 100.0); // srGross (10) + nonGross (90)
      expect(tax['tax'], 15.0); // total tax
      expect(tax['net'], 115.0); // totalGross + totalTax

      // 7. Sales Stats
      final stats = summary['sales_stats'];
      expect(stats['bills_count'], 1);
      expect(stats['items_qty_sold'], 1);
    });

    test('computeSessionSummary should handle empty orders and transactions',
        () async {
      // Given
      final List<OrderHiveModel> orders = [];
      final List<Map<String, dynamic>> transactions = [];

      // When
      final summary = await CashDrawerCalculator.computeSessionSummary(
        orders: orders,
        transactions: transactions,
        session: mockSession,
        allSessionsToday: [],
        currentUser: mockUser,
      );

      // Then
      expect(summary['revenue_summary']['total'], 0.0);
      expect(summary['service_types']['total'], 0.0);
      expect(summary['mop_collections']['total'], 0.0);
      expect(summary['cashier_collections']['total'], 0.0);
      expect(summary['categories']['total'], 0.0);
      expect(summary['tax_summary']['net'], 0.0);
      expect(summary['sales_stats']['bills_count'], 0);
    });

    test(
        'computeSessionSummary should exclude voided orders from items sold and count them as refunded',
        () async {
      // Given
      final orders = [
        OrderHiveModel(
          id: 1,
          totalPrice: 100.0,
          body: OrderBodyData(
            deliveryType: 'dine_in',
            phone: '',
            address: AddressModel(),
            deliveryDate: '',
            deliveryTime: '',
            bagData: BagData(),
            enhancedProducts: [
              EnhancedProductOrder(
                stockId: 1,
                quantity: 2,
                originalPrice: 50.0,
                finalPrice: 50.0,
                itemDiscountAmount: 0.0,
                taxAmount: 0.0,
                serviceChargeAmount: 0.0,
                categoryId: 1,
                categoryName: 'Food',
              ),
            ],
          ),
        ),
        OrderHiveModel(
          id: 2,
          totalPrice: 80.0,
          isVoided: true,
          body: OrderBodyData(
            deliveryType: 'dine_in',
            phone: '',
            address: AddressModel(),
            deliveryDate: '',
            deliveryTime: '',
            bagData: BagData(),
            isVoided: true,
            enhancedProducts: [
              EnhancedProductOrder(
                stockId: 2,
                quantity: 3,
                originalPrice: 20.0,
                finalPrice: 20.0,
                itemDiscountAmount: 0.0,
                taxAmount: 0.0,
                serviceChargeAmount: 0.0,
                categoryId: 1,
                categoryName: 'Food',
              ),
            ],
          ),
        ),
      ];

      final transactions = [
        {'order_id': 1, 'payment_tag': 'cash', 'price': 100.0},
        {'order_id': 2, 'payment_tag': 'cash', 'price': 80.0},
      ];

      // When
      final summary = await CashDrawerCalculator.computeSessionSummary(
        orders: orders,
        transactions: transactions,
        session: mockSession,
        allSessionsToday: [],
        currentUser: mockUser,
      );

      // Then
      final stats = summary['sales_stats'];
      expect(stats['bills_count'], 1);
      expect(stats['voided_settled_bills'], 1);
      expect(stats['items_qty_sold'], 2);
      expect(stats['items_qty_refunded'], 3);
    });

    test('computeSessionSummary should handle multiple MOPs and service types',
        () async {
      // Given
      final orders = [
        OrderHiveModel(
          id: 1,
          totalPrice: 100.0,
          body: OrderBodyData(
            deliveryType: 'delivery',
            phone: '',
            address: AddressModel(),
            deliveryDate: '',
            deliveryTime: '',
            bagData: BagData(),
            enhancedProducts: [
              EnhancedProductOrder(
                stockId: 1,
                quantity: 2,
                originalPrice: 100.0,
                finalPrice: 100.0,
                itemDiscountAmount: 0.0,
                taxAmount: 0.0,
                serviceChargeAmount: 0.0,
              ),
            ],
          ),
        ),
        OrderHiveModel(
          id: 2,
          totalPrice: 200.0,
          body: OrderBodyData(
            deliveryType: 'dine_in',
            phone: '',
            address: AddressModel(),
            deliveryDate: '',
            deliveryTime: '',
            bagData: BagData(),
            enhancedProducts: [
              EnhancedProductOrder(
                stockId: 2,
                quantity: 1,
                originalPrice: 200.0,
                finalPrice: 200.0,
                itemDiscountAmount: 0.0,
                taxAmount: 0.0,
                serviceChargeAmount: 0.0,
              ),
            ],
          ),
        ),
      ];

      final transactions = [
        {'order_id': 1, 'payment_tag': 'cash', 'price': 100.0},
        {'order_id': 2, 'payment_tag': 'card', 'price': 200.0},
      ];

      // When
      final summary = await CashDrawerCalculator.computeSessionSummary(
        orders: orders,
        transactions: transactions,
        session: mockSession,
        allSessionsToday: [],
        currentUser: mockUser,
      );

      // Then
      expect(summary['revenue_summary']['cash_sales'], 300.0);
      expect(summary['revenue_summary']['total'], 300.0);

      final serviceTypes = summary['service_types']['items'] as List;
      expect(
          serviceTypes
              .any((e) => e['type'] == 'Delivery' && e['amount'] == 100.0),
          isTrue);
      expect(
          serviceTypes
              .any((e) => e['type'] == 'Dine In' && e['amount'] == 200.0),
          isTrue);

      final mopItems = summary['mop_collections']['items'] as List;
      expect(mopItems.any((e) => e['method'] == 'Cash' && e['amount'] == 100.0),
          isTrue);
      expect(mopItems.any((e) => e['method'] == 'Card' && e['amount'] == 200.0),
          isTrue);
    });

    test(
        'computeSessionSummary should handle proportional discount distribution in categories',
        () async {
      // Given
      final orders = [
        OrderHiveModel(
          id: 1,
          totalPrice: 150.0,
          body: OrderBodyData(
            deliveryType: 'pickup',
            phone: '',
            address: AddressModel(),
            deliveryDate: '',
            deliveryTime: '',
            bagData: BagData(),
            billDiscountAmount: 50.0,
            enhancedProducts: [
              EnhancedProductOrder(
                stockId: 1,
                quantity: 1,
                originalPrice: 100.0,
                finalPrice: 100.0,
                itemDiscountAmount: 0.0,
                taxAmount: 0.0,
                serviceChargeAmount: 0.0,
                categoryId: 1,
                categoryName: 'Food',
              ),
              EnhancedProductOrder(
                stockId: 2,
                quantity: 1,
                originalPrice: 100.0,
                finalPrice: 100.0,
                itemDiscountAmount: 0.0,
                taxAmount: 0.0,
                serviceChargeAmount: 0.0,
                categoryId: 2,
                categoryName: 'Drink',
              ),
            ],
          ),
        ),
      ];

      final transactions = [
        {'order_id': 1, 'payment_tag': 'cash', 'price': 150.0},
      ];

      // When
      final summary = await CashDrawerCalculator.computeSessionSummary(
        orders: orders,
        transactions: transactions,
        session: mockSession,
        allSessionsToday: [],
        currentUser: mockUser,
      );

      // Then
      final categories = summary['categories']['items'] as List;
      expect(categories.firstWhere((e) => e['id'] == 1)['amount'],
          75.0); // 100 - 25
      expect(categories.firstWhere((e) => e['id'] == 2)['amount'],
          75.0); // 100 - 25
      expect(summary['categories']['total'], 150.0);
    });

    test('computeSessionSummary should handle null/missing data gracefully',
        () async {
      // Given
      final orders = [
        OrderHiveModel(
          id: 1,
          // Missing body
        ),
      ];
      final transactions = [
        {'order_id': 1}, // Missing payment_tag, price
      ];

      // When
      final summary = await CashDrawerCalculator.computeSessionSummary(
        orders: orders,
        transactions: transactions,
        session: mockSession,
        allSessionsToday: [],
        currentUser: null,
      );

      // Then
      expect(summary, isNotNull);
      expect(summary['revenue_summary']['total'], 0.0);
      expect(summary['sales_stats']['bills_count'], 1);
    });
    test('computeSessionSummary should use payment names from repository',
        () async {
      // Given
      final orders = [
        OrderHiveModel(
          id: 1,
          totalPrice: 100.0,
          body: OrderBodyData(
            deliveryType: 'dine_in',
            phone: '',
            address: AddressModel(),
            deliveryDate: '',
            deliveryTime: '',
            bagData: BagData(),
            enhancedProducts: [
              EnhancedProductOrder(
                stockId: 1,
                quantity: 1,
                originalPrice: 100.0,
                finalPrice: 100.0,
                itemDiscountAmount: 0.0,
                taxAmount: 0,
                serviceChargeAmount: 0,
              ),
            ],
          ),
        ),
      ];

      final transactions = [
        {
          'order_id': 1,
          'payment_id': 1, // Using ID instead of tag
          'price': 100.0,
        }
      ];

      // Mock payments with a translation
      when(() => mockPaymentsRepo.getPayments()).thenAnswer(
        (_) async => ApiResult.success(
          data: PaymentsResponse(
            data: [
              PaymentData.fromJson({
                'id': 1,
                'tag': 'cash_tag',
                'translation': {'title': 'Cash Payment'},
              })
            ],
          ),
        ),
      );

      // When
      final summary = await CashDrawerCalculator.computeSessionSummary(
        orders: orders,
        transactions: transactions,
        session: mockSession,
        allSessionsToday: [],
        currentUser: mockUser,
      );

      // Then
      final mop = summary['mop_collections'];
      expect(mop['items'][0]['method'], 'Cash Payment');
      expect(mop['items'][0]['amount'], 100.0);
    });
  });
}
