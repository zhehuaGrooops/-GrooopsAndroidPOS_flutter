import 'package:flutter_test/flutter_test.dart';
import 'package:admin_desktop/src/core/db/hive_service.dart';
import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/repository/hive_repository/currencies_hive_repository.dart';
import 'package:admin_desktop/src/repository/hive_repository/users_hive_repository.dart';
import 'package:admin_desktop/src/models/data/user_data.dart';

void main() {
  test('CurrenciesHiveRepository returns empty success when box empty',
      () async {
    await HiveService.init();
    final repo = CurrenciesHiveRepository();
    final res = await repo.getCurrencies();
    res.when(
      success: (data) {
        expect(data.data, isEmpty);
      },
      failure: (error, _) {
        fail('Expected success, got failure: $error');
      },
    );
  });

  test('UsersHiveRepository.saveUsers stores users in Hive box', () async {
    await HiveService.init();
    final box = await HiveService.openBox(HiveBoxes.users);
    await box.clear();
    final repo = UsersHiveRepository();
    final users = [
      UserData(
          id: 1,
          firstname: 'John',
          lastname: 'Doe',
          email: 'john.doe@example.com',
          phone: '123456789'),
      UserData(
          id: 2,
          firstname: 'Jane',
          lastname: 'Smith',
          email: 'jane.smith@example.com',
          phone: '987654321'),
    ];
    final res = await repo.saveUsers(users);
    res.when(
      success: (_) async {
        final fetched = await repo.getUsers();
        fetched.when(
          success: (data) {
            expect(data.users?.length, users.length);
            expect(data.users?.first.id, users.first.id);
            expect(data.users?.first.firstname, users.first.firstname);
          },
          failure: (error, _) {
            fail('Expected success fetching users, got failure: $error');
          },
        );
      },
      failure: (error, _) {
        fail('Expected success saving users, got failure: $error');
      },
    );
  });

  test('UsersHiveRepository.saveUsers preserves existing profile entry',
      () async {
    await HiveService.init();
    final box = await HiveService.openBox(HiveBoxes.users);
    await box.clear();
    await box.put('profile', {'firstname': 'Existing', 'lastname': 'User'});
    final repo = UsersHiveRepository();
    final users = [
      UserData(
          id: 3,
          firstname: 'New',
          lastname: 'User',
          email: 'new.user@example.com',
          phone: '111222333'),
    ];
    final res = await repo.saveUsers(users);
    res.when(
      success: (_) async {
        final profile = box.get('profile') as Map?;
        expect(profile, isNotNull);
        expect(profile?['firstname'], 'Existing');
        final fetched = await repo.getUsers();
        fetched.when(
          success: (data) {
            expect(data.users?.any((u) => u.id == 3), isTrue);
          },
          failure: (error, _) {
            fail('Expected success fetching users, got failure: $error');
          },
        );
      },
      failure: (error, _) {
        fail('Expected success saving users, got failure: $error');
      },
    );
  });
}
