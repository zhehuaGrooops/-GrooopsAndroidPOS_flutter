// import 'package:admin_desktop/src/models/data/addons_data.dart';
// import 'package:admin_desktop/src/presentation/pages/main/widgets/right_side/riverpod/right_side_notifier.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
//
// import '../../../../../../core/constants/constants.dart';
// import '../../../../../../core/utils/utils.dart';
// import '../../../../../../models/models.dart';
// import '../riverpod/add_product_state.dart';
//
// class AddProductNotifier extends StateNotifier<AddProductState> {
//   AddProductNotifier() : super(const AddProductState());
//
//   void setProduct(ProductData? product, int bagIndex) {
//     final List<Stocks> stocks = product?.stocks ??
//         (product?.stock == null ? <Stocks>[] : [product!.stock!]);
//     state = state.copyWith(
//       isLoading: false,
//       product: product,
//       initialStocks: stocks,
//       stockCount: 0,
//     );
//     if (stocks.isNotEmpty) {
//       final int groupsCount = stocks[0].extras?.length ?? 0;
//       final List<int> selectedIndexes = List.filled(groupsCount, 0);
//       initialSetSelectedIndexes(selectedIndexes, bagIndex);
//     }
//   }
//
//   void updateSelectedIndexes({
//     required int index,
//     required int value,
//     required int bagIndex,
//   }) {
//     final newList = state.selectedIndexes.sublist(0, index);
//     newList.add(value);
//     final postList =
//         List.filled(state.selectedIndexes.length - newList.length, 0);
//     newList.addAll(postList);
//     initialSetSelectedIndexes(newList, bagIndex);
//   }
//
//   void initialSetSelectedIndexes(List<int> indexes, int bagIndex) {
//     state = state.copyWith(selectedIndexes: indexes);
//     updateExtras(bagIndex);
//   }
//
//   void updateExtras(int bagIndex) {
//     final int groupsCount = state.initialStocks[0].extras?.length ?? 0;
//     final List<TypedExtra> groupExtras = [];
//     for (int i = 0; i < groupsCount; i++) {
//       if (i == 0) {
//         final TypedExtra extras = getFirstExtras(state.selectedIndexes[0]);
//         groupExtras.add(extras);
//       } else {
//         final TypedExtra extras =
//             getUniqueExtras(groupExtras, state.selectedIndexes, i);
//         groupExtras.add(extras);
//       }
//     }
//     final Stocks? selectedStock = getSelectedStock(groupExtras);
//     final int minQty = state.product?.minQty ?? 0;
//     final int selectedStockQty = selectedStock?.quantity ?? 0;
//     final int stockCount =
//         minQty <= selectedStockQty ? minQty : selectedStockQty;
//     state = state.copyWith(
//       typedExtras: groupExtras,
//       selectedStock: selectedStock,
//       stockCount: stockCount,
//     );
//   }
//
//   void updateIngredient(BuildContext context, int selectIndex) {
//     List<Addons>? data = state.selectedStock?.addons;
//     data?[selectIndex].active = !(data[selectIndex].active ?? false);
//     List<Stocks>? stocks = state.product?.stocks;
//     Stocks? newStock = stocks?.first.copyWith(addons: data);
//     ProductData? product = state.product;
//     ProductData? newProduct = product?.copyWith(stocks: [newStock!]);
//     state = state.copyWith(product: newProduct);
//   }
//
//   void addIngredient(
//     BuildContext context,
//     int selectIndex,
//   ) {
//     if ((state.selectedStock?.addons?[selectIndex].product?.maxQty ?? 0) >
//             (state.selectedStock?.addons?[selectIndex].quantity ?? 0) &&
//         (state.selectedStock?.addons?[selectIndex].product?.stock?.quantity ??
//                 0) >
//             (state.selectedStock?.addons?[selectIndex].quantity ?? 0)) {
//       List<Addons>? data = state.selectedStock?.addons;
//       data?[selectIndex].quantity = (data[selectIndex].quantity ?? 0) + 1;
//       List<Stocks>? stocks = state.product?.stocks;
//       Stocks? newStock = stocks?.first.copyWith(addons: data);
//       ProductData? product = state.product;
//       ProductData? newProduct = product?.copyWith(stocks: [newStock!]);
//       state = state.copyWith(product: newProduct);
//     } else {
//       AppHelpers.showSnackBar(context,
//           "${AppHelpers.getTranslation(TrKeys.maxQty)} ${state.selectedStock?.addons?[selectIndex].quantity ?? 1}");
//     }
//   }
//
//   void removeIngredient(BuildContext context, int selectIndex) {
//     if ((state.selectedStock?.addons?[selectIndex].product?.minQty ?? 0) <
//         (state.selectedStock?.addons?[selectIndex].quantity ?? 0)) {
//       List<Addons>? data = state.selectedStock?.addons;
//       data?[selectIndex].quantity = (data[selectIndex].quantity ?? 0) - 1;
//       List<Stocks>? stocks = state.product?.stocks;
//       Stocks? newStock = stocks?.first.copyWith(addons: data);
//       ProductData? product = state.product;
//       ProductData? newProduct = product?.copyWith(stocks: [newStock!]);
//       state = state.copyWith(product: newProduct);
//     } else {
//       AppHelpers.showSnackBar(
//           context, AppHelpers.getTranslation(TrKeys.minQty));
//     }
//   }
//
//   Stocks? getSelectedStock(List<TypedExtra> groupExtras) {
//     List<Stocks> stocks = List.from(state.initialStocks);
//     for (int i = 0; i < groupExtras.length; i++) {
//       String selectedExtrasValue =
//           groupExtras[i].uiExtras[state.selectedIndexes[i]].value;
//       stocks = getSelectedStocks(stocks, selectedExtrasValue, i);
//     }
//     return stocks[0];
//   }
//
//   List<Stocks> getSelectedStocks(List<Stocks> stocks, String value, int index) {
//     List<Stocks> included = [];
//     for (int i = 0; i < stocks.length; i++) {
//       if (stocks[i].extras?[index].value == value) {
//         included.add(stocks[i]);
//       }
//     }
//     return included;
//   }
//
//   TypedExtra getFirstExtras(int selectedIndex) {
//     ExtrasType type = ExtrasType.text;
//     String title = '';
//     final List<String> uniques = [];
//     for (int i = 0; i < state.initialStocks.length; i++) {
//       uniques.add(state.initialStocks[i].extras?[0].value ?? '');
//       title = state.initialStocks[i].extras?[0].group?.translation?.title ?? '';
//       type = AppHelpers.getExtraTypeByValue(
//           state.initialStocks[i].extras?[0].group?.type);
//     }
//     final setOfUniques = uniques.toSet().toList();
//     final List<UiExtra> extras = [];
//     for (int i = 0; i < setOfUniques.length; i++) {
//       if (selectedIndex == i) {
//         extras.add(UiExtra(setOfUniques[i], true, i));
//       } else {
//         extras.add(UiExtra(setOfUniques[i], false, i));
//       }
//     }
//     return TypedExtra(type, extras, title, 0);
//   }
//
//   TypedExtra getUniqueExtras(
//     List<TypedExtra> groupExtras,
//     List<int> selectedIndexes,
//     int index,
//   ) {
//     List<Stocks> includedStocks = List.from(state.initialStocks);
//     for (int i = 0; i < groupExtras.length; i++) {
//       final String includedValue =
//           groupExtras[i].uiExtras[selectedIndexes[i]].value;
//       includedStocks = getIncludedStocks(includedStocks, i, includedValue);
//     }
//     final List<String> uniques = [];
//     String title = '';
//     ExtrasType type = ExtrasType.text;
//     for (int i = 0; i < includedStocks.length; i++) {
//       uniques.add(includedStocks[i].extras?[index].value ?? '');
//       title = includedStocks[i].extras?[index].group?.translation?.title ?? '';
//       type = AppHelpers.getExtraTypeByValue(
//           includedStocks[i].extras?[index].group?.type ?? '');
//     }
//     final setOfUniques = uniques.toSet().toList();
//     final List<UiExtra> extras = [];
//     for (int i = 0; i < setOfUniques.length; i++) {
//       if (selectedIndexes[groupExtras.length] == i) {
//         extras.add(UiExtra(setOfUniques[i], true, i));
//       } else {
//         extras.add(UiExtra(setOfUniques[i], false, i));
//       }
//     }
//     return TypedExtra(type, extras, title, index);
//   }
//
//   List<Stocks> getIncludedStocks(
//     List<Stocks> includedStocks,
//     int index,
//     String includedValue,
//   ) {
//     List<Stocks> stocks = [];
//     for (int i = 0; i < includedStocks.length; i++) {
//       if (includedStocks[i].extras?[index].value == includedValue) {
//         stocks.add(includedStocks[i]);
//       }
//     }
//     return stocks;
//   }
//
//   void increaseStockCount(int bagIndex) {
//     if ((state.selectedStock?.quantity ?? 0) < (state.product?.minQty ?? 0)) {
//       return;
//     }
//     int newCount = state.stockCount;
//     if (newCount >= (state.product?.maxQty ?? 100000) ||
//         newCount >= (state.selectedStock?.quantity ?? 100000)) {
//       return;
//     } else if (newCount < (state.product?.minQty ?? 0)) {
//       newCount = state.product?.minQty ?? 1;
//       state = state.copyWith(stockCount: newCount);
//     } else {
//       newCount = newCount + 1;
//       state = state.copyWith(stockCount: newCount);
//     }
//   }
//
//   void decreaseStockCount(int bagIndex) {
//     int newCount = state.stockCount;
//     if (newCount <= 1) {
//       return;
//     } else if (newCount <= (state.product?.minQty ?? 0)) {
//       newCount = 0;
//       state = state.copyWith(stockCount: newCount);
//       // deleteProductFromCart(state.product?.minQty ?? 0, bagIndex);
//     } else {
//       newCount = newCount - 1;
//       state = state.copyWith(stockCount: newCount);
//       // deleteProductFromCart(1, bagIndex);
//     }
//   }
//
//   void addProductToBag(
//     BuildContext context,
//     int bagIndex,
//     RightSideNotifier rightSideNotifier,
//   ) {
//     final List<BagProductData> bagProducts =
//         LocalStorage.getBags()[bagIndex].bagProducts ?? [];
//
//     int newStockIndex = -1;
//
//     for (int i = 0; i < bagProducts.length; i++) {
//       if (bagProducts[i].stockId == state.selectedStock?.id) {
//         if (bagProducts[i].carts?.length ==
//             state.selectedStock?.addons
//                 ?.where((element) => element.active ?? false)
//                 .length) {
//           state.selectedStock?.addons
//               ?.where((element) => element.active ?? false)
//               .forEach((e) {
//             print('object2');
//
//             if (bagProducts[i]
//                     .carts
//                     ?.map((i) => i.stockId)
//                     .contains(e.product?.stock?.id) ??
//                 false) {
//               print('object3');
//               newStockIndex = i;
//             } else {
//               newStockIndex = -1;
//             }
//           });
//           print('object23');
//           print(bagProducts[i].carts?.map((i) => i.stockId));
//           print(state.selectedStock?.addons
//               ?.where(
//                 (element) => element.active ?? false,
//               )
//               .map(
//                 (e) => e.stockId,
//               ));
//           print(   ((bagProducts[i].carts?.isEmpty ?? true) &&
//               (state.selectedStock?.addons
//                   ?.where(
//                     (element) => element.active ?? false,
//               )
//                   .isEmpty ??
//                   true)));
//           if (bagProducts[i]
//                   .carts
//                   ?.map((i) => i.stockId)
//                   .contains(state.selectedStock?.product?.stock?.id) ??
//               false ||
//                   ((bagProducts[i].carts?.isEmpty ?? true) &&
//                       (state.selectedStock?.addons
//                               ?.where(
//                                 (element) => element.active ?? false,
//                               )
//                               .isEmpty ??
//                           true))) {
//             print('object3');
//             newStockIndex = i;
//           } else {
//             newStockIndex = -1;
//           }
//         }
//       }
//     }
//
//     List<BagProductData> addons = [];
//
//     state.selectedStock?.addons?.forEach(
//       (element) {
//         if (element.active ?? false) {
//           addons.add(BagProductData(
//             parentId: state.selectedStock?.id,
//             quantity: element.quantity,
//             stockId: element.stockId,
//           ));
//         }
//       },
//     );
//
//     if (newStockIndex == -1) {
//       bagProducts.insert(
//         0,
//         BagProductData(
//           stockId: state.selectedStock?.id,
//           quantity: state.stockCount,
//           carts: addons,
//         ),
//       );
//     } else {
//       bagProducts.removeAt(newStockIndex);
//       bagProducts.insert(
//         newStockIndex,
//         BagProductData(
//             stockId: state.selectedStock?.id,
//             quantity: state.stockCount,
//             carts: addons),
//       );
//     }
//
//     List<BagData> bags = List.from(LocalStorage.getBags());
//     bags[bagIndex] = bags[bagIndex].copyWith(bagProducts: bagProducts);
//     LocalStorage.setBags(bags);
//     rightSideNotifier.fetchCarts(
//       checkYourNetwork: () {
//         AppHelpers.showSnackBar(
//           context,
//           AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
//         );
//       },
//     );
//   }
// }

import 'package:admin_desktop/src/models/data/addons_data.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/right_side/riverpod/right_side_notifier.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/utils.dart';
import '../../../../../../models/models.dart';
import '../riverpod/add_product_state.dart';

class AddProductNotifier extends StateNotifier<AddProductState> {
  AddProductNotifier() : super(const AddProductState());

  void setProduct(ProductData? product, int bagIndex) {
    final List<Stocks> stocks = product?.stocks ??
        (product?.stock == null ? <Stocks>[] : [product!.stock!]);
    state = state.copyWith(
      isLoading: false,
      product: product,
      initialStocks: stocks,
      stockCount: 0,
    );
    if (stocks.isNotEmpty) {
      final int groupsCount = stocks[0].extras?.length ?? 0;
      final List<int> selectedIndexes = List.filled(groupsCount, 0);
      initialSetSelectedIndexes(selectedIndexes, bagIndex);
    }
  }

  void updateSelectedIndexes({
    required int index,
    required int value,
    required int bagIndex,
  }) {
    final newList = state.selectedIndexes.sublist(0, index);
    newList.add(value);
    final postList =
        List.filled(state.selectedIndexes.length - newList.length, 0);
    newList.addAll(postList);
    initialSetSelectedIndexes(newList, bagIndex);
  }

  void initialSetSelectedIndexes(List<int> indexes, int bagIndex) {
    state = state.copyWith(selectedIndexes: indexes);
    updateExtras(bagIndex);
  }

  void updateExtras(int bagIndex) {
    if (state.initialStocks.isEmpty) {
      return;
    }
    final int groupsCount = state.initialStocks[0].extras?.length ?? 0;
    final List<TypedExtra> groupExtras = [];
    for (int i = 0; i < groupsCount; i++) {
      if (i == 0) {
        final TypedExtra extras = getFirstExtras(state.selectedIndexes[0]);
        groupExtras.add(extras);
      } else {
        final TypedExtra extras =
            getUniqueExtras(groupExtras, state.selectedIndexes, i);
        groupExtras.add(extras);
      }
    }
    final Stocks? selectedStock = getSelectedStock(groupExtras);
    final int minQty = state.product?.minQty ?? 0;
    final int selectedStockQty = selectedStock?.quantity ?? 0;
    final int stockCount =
        minQty <= selectedStockQty ? minQty : selectedStockQty;
    state = state.copyWith(
      typedExtras: groupExtras,
      selectedStock: selectedStock,
      stockCount: stockCount,
    );
  }

  void updateIngredient(BuildContext context, int selectIndex) {
    List<Addons>? data = state.selectedStock?.addons;
    if (data == null || selectIndex >= data.length) return;
    data[selectIndex].active = !(data[selectIndex].active ?? false);

    // Set quantity to minQty if current quantity is less
    final int minQty = data[selectIndex].product?.minQty ?? 1;
    if ((data[selectIndex].quantity ?? 0) < minQty) {
      data[selectIndex].quantity = minQty;
    }
    final Stocks? currentSelectedStock = state.selectedStock;
    if (currentSelectedStock == null) return;

    final Stocks newStock = currentSelectedStock.copyWith(addons: data);

    List<Stocks> stocks = List.from(state.product?.stocks ?? []);
    int stockIndex = stocks.indexWhere((s) => s.id == newStock.id);
    if (stockIndex != -1) {
      stocks[stockIndex] = newStock;
    } else {
      stocks = [newStock];
    }

    ProductData? product = state.product;
    ProductData? newProduct = product?.copyWith(stocks: stocks);
    state = state.copyWith(product: newProduct, selectedStock: newStock);
  }

  void addIngredient(
    BuildContext context,
    int selectIndex,
  ) {
    List<Addons>? data = state.selectedStock?.addons;
    if (data == null || selectIndex >= data.length) return;

    final int maxQty = data[selectIndex].product?.maxQty ?? 1;
    final int currentQty = data[selectIndex].quantity ?? 0;
    final int stockQty = data[selectIndex].stocks?.quantity ?? 1000000;

    if (currentQty < maxQty && currentQty < stockQty) {
      data[selectIndex].quantity = currentQty + 1;

      final Stocks? currentSelectedStock = state.selectedStock;
      if (currentSelectedStock == null) return;

      final Stocks newStock = currentSelectedStock.copyWith(addons: data);

      List<Stocks> stocks = List.from(state.product?.stocks ?? []);
      int stockIndex = stocks.indexWhere((s) => s.id == newStock.id);
      if (stockIndex != -1) {
        stocks[stockIndex] = newStock;
      } else {
        stocks = [newStock];
      }

      ProductData? product = state.product;
      ProductData? newProduct = product?.copyWith(stocks: stocks);
      state = state.copyWith(product: newProduct, selectedStock: newStock);
    } else {
      AppHelpers.showSnackBar(
          context, "${AppHelpers.getTranslation(TrKeys.maxQty)} $currentQty");
    }
  }

  void removeIngredient(BuildContext context, int selectIndex) {
    List<Addons>? data = state.selectedStock?.addons;
    if (data == null || selectIndex >= data.length) return;

    final int minQty = data[selectIndex].product?.minQty ?? 0;
    final int currentQty = data[selectIndex].quantity ?? 0;

    if (currentQty > minQty) {
      data[selectIndex].quantity = currentQty - 1;

      // If it reaches 0 or below minQty, we could deactivate it,
      // but usually we just let the user toggle it off.

      final Stocks? currentSelectedStock = state.selectedStock;
      if (currentSelectedStock == null) return;

      final Stocks newStock = currentSelectedStock.copyWith(addons: data);

      List<Stocks> stocks = List.from(state.product?.stocks ?? []);
      int stockIndex = stocks.indexWhere((s) => s.id == newStock.id);
      if (stockIndex != -1) {
        stocks[stockIndex] = newStock;
      } else {
        stocks = [newStock];
      }

      ProductData? product = state.product;
      ProductData? newProduct = product?.copyWith(stocks: stocks);
      state = state.copyWith(product: newProduct, selectedStock: newStock);
    } else {
      AppHelpers.showSnackBar(
          context, AppHelpers.getTranslation(TrKeys.minQty));
    }
  }

  Stocks? getSelectedStock(List<TypedExtra> groupExtras) {
    List<Stocks> stocks = List.from(state.initialStocks);
    for (int i = 0; i < groupExtras.length; i++) {
      String selectedExtrasValue =
          groupExtras[i].uiExtras[state.selectedIndexes[i]].value;
      stocks = getSelectedStocks(stocks, selectedExtrasValue, i);
    }
    return stocks[0];
  }

  List<Stocks> getSelectedStocks(List<Stocks> stocks, String value, int index) {
    List<Stocks> included = [];
    for (int i = 0; i < stocks.length; i++) {
      if (stocks[i].extras?[index].value == value) {
        included.add(stocks[i]);
      }
    }
    return included;
  }

  TypedExtra getFirstExtras(int selectedIndex) {
    ExtrasType type = ExtrasType.text;
    String title = '';
    final List<String> uniques = [];
    for (int i = 0; i < state.initialStocks.length; i++) {
      uniques.add(state.initialStocks[i].extras?[0].value ?? '');
      title = state.initialStocks[i].extras?[0].group?.translation?.title ?? '';
      type = AppHelpers.getExtraTypeByValue(
          state.initialStocks[i].extras?[0].group?.type);
    }
    final setOfUniques = uniques.toSet().toList();
    final List<UiExtra> extras = [];
    for (int i = 0; i < setOfUniques.length; i++) {
      if (selectedIndex == i) {
        extras.add(UiExtra(setOfUniques[i], true, i));
      } else {
        extras.add(UiExtra(setOfUniques[i], false, i));
      }
    }
    return TypedExtra(type, extras, title, 0);
  }

  TypedExtra getUniqueExtras(
    List<TypedExtra> groupExtras,
    List<int> selectedIndexes,
    int index,
  ) {
    List<Stocks> includedStocks = List.from(state.initialStocks);
    for (int i = 0; i < groupExtras.length; i++) {
      final String includedValue =
          groupExtras[i].uiExtras[selectedIndexes[i]].value;
      includedStocks = getIncludedStocks(includedStocks, i, includedValue);
    }
    final List<String> uniques = [];
    String title = '';
    ExtrasType type = ExtrasType.text;
    for (int i = 0; i < includedStocks.length; i++) {
      uniques.add(includedStocks[i].extras?[index].value ?? '');
      title = includedStocks[i].extras?[index].group?.translation?.title ?? '';
      type = AppHelpers.getExtraTypeByValue(
          includedStocks[i].extras?[index].group?.type ?? '');
    }
    final setOfUniques = uniques.toSet().toList();
    final List<UiExtra> extras = [];
    for (int i = 0; i < setOfUniques.length; i++) {
      if (selectedIndexes[groupExtras.length] == i) {
        extras.add(UiExtra(setOfUniques[i], true, i));
      } else {
        extras.add(UiExtra(setOfUniques[i], false, i));
      }
    }
    return TypedExtra(type, extras, title, index);
  }

  List<Stocks> getIncludedStocks(
    List<Stocks> includedStocks,
    int index,
    String includedValue,
  ) {
    List<Stocks> stocks = [];
    for (int i = 0; i < includedStocks.length; i++) {
      if (includedStocks[i].extras?[index].value == includedValue) {
        stocks.add(includedStocks[i]);
      }
    }
    return stocks;
  }

  void increaseStockCount(int bagIndex) {
    if ((state.selectedStock?.quantity ?? 0) < (state.product?.minQty ?? 0)) {
      return;
    }
    int newCount = state.stockCount;
    if (newCount >= (state.product?.maxQty ?? 100000) ||
        newCount >= (state.selectedStock?.quantity ?? 100000)) {
      return;
    } else if (newCount < (state.product?.minQty ?? 0)) {
      newCount = state.product?.minQty ?? 1;
      state = state.copyWith(stockCount: newCount);
    } else {
      newCount = newCount + 1;
      state = state.copyWith(stockCount: newCount);
    }
  }

  void decreaseStockCount(int bagIndex) {
    int newCount = state.stockCount;
    if (newCount <= 1) {
      return;
    } else if (newCount <= (state.product?.minQty ?? 0)) {
      newCount = 0;
      state = state.copyWith(stockCount: newCount);
      // deleteProductFromCart(state.product?.minQty ?? 0, bagIndex);
    } else {
      newCount = newCount - 1;
      state = state.copyWith(stockCount: newCount);
      // deleteProductFromCart(1, bagIndex);
    }
  }

  void addProductToBag(
    BuildContext context,
    int bagIndex,
    RightSideNotifier rightSideNotifier,
  ) {
    final user = LocalStorage.getUser();
    final int shopId = user?.role == TrKeys.waiter
        ? user?.invite?.shopId ?? 0
        : user?.shop?.id ?? 0;

    if (user?.role == TrKeys.admin || shopId == 0) {
      AppHelpers.showSnackBar(
        context,
        user?.role == TrKeys.admin
            ? AppHelpers.getTranslation(TrKeys.adminCannotAddProduct)
            : AppHelpers.getTranslation(TrKeys.noShopLinked),
      );
      return;
    }

    final List<BagProductData> bagProducts =
        LocalStorage.getBags()[bagIndex].bagProducts ?? [];

    int newStockIndex = -1;

    if (bagProducts
        .map(
          (e) => e.stockId,
        )
        .contains(state.selectedStock?.id)) {
      // for (int i = 0; i < bagProducts.length; i++) {
      //   if (bagProducts[i].stockId == state.selectedStock?.id) {
      //     print('contains at index: $i');
      //     newStockIndex = i;
      //   }
      //   // if (bagProducts[i].stockId == state.selectedStock?.id) {
      //   //   print('elbek2');
      //   //   if (bagProducts[i].carts?.length ==
      //   //       state.selectedStock?.addons
      //   //           ?.where((element) => element.active ?? false)
      //   //           .length) {
      //   //     print("elbek2.5");
      //   //     state.selectedStock?.addons
      //   //         ?.where((element) => element.active ?? false)
      //   //         .forEach((e) {
      //   //       print('elbek3');
      //   //       if (bagProducts[i]
      //   //               .carts
      //   //               ?.map((i) => i.stockId)
      //   //               .contains(e.product?.stock?.id) ??
      //   //           false) {
      //   //         print('elbek41');
      //   //         newStockIndex = i;
      //   //       } else {
      //   //         newStockIndex = -1;
      //   //       }
      //   //     });
      //   //   }
      //   // }
      // }
    }

    // snapshot discountSetting from product/category so bag item keeps it
    final DiscountSetting? snapshotDiscountSetting =
        state.selectedStock?.product?.category?.discountSetting ??
            state.selectedStock?.product?.stock?.product?.category
                ?.discountSetting ??
            state.selectedStock?.product?.category?.discountSetting;

    List<BagProductData> list = [];
    state.selectedStock?.addons?.forEach((element) {
      if (element.active ?? false) {
        final int? addonStockId = element.addonId;

        list.add(BagProductData(
          stockId: addonStockId,
          parentId: state.selectedStock?.id,
          quantity: element.quantity,
          selectedDiscountSetting: snapshotDiscountSetting,
        ));
      }
    });

    if (newStockIndex == -1) {
      bagProducts.insert(
        0,
        BagProductData(
            stockId: state.selectedStock?.id,
            quantity: state.stockCount,
            carts: list,
            selectedDiscountSetting: snapshotDiscountSetting),
      );
    } else {
      int oldCount = bagProducts[newStockIndex].quantity ?? 0;
      bagProducts.removeAt(newStockIndex);
      bagProducts.insert(
        newStockIndex,
        BagProductData(
            stockId: state.selectedStock?.id,
            quantity: state.stockCount + oldCount,
            carts: list,
            selectedDiscountSetting: snapshotDiscountSetting),
      );
    }

    List<BagData> bags = List.from(LocalStorage.getBags());
    bags[bagIndex] = bags[bagIndex].copyWith(bagProducts: bagProducts);
    LocalStorage.setBags(bags);

    rightSideNotifier.fetchCarts(
      checkYourNetwork: () {
        AppHelpers.showSnackBar(
          context,
          AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
        );
      },
    );
  }
}
