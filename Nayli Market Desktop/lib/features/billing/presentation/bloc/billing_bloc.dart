import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/held_cart.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/data/models/product_model.dart';
import '../../../product/domain/usecases/product_usecases.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/scale_barcode_parser.dart';
import '../../../../core/data/hive_database.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;

  BillingBloc({required this.getProductByBarcodeUseCase})
      : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<SwitchCartItemUnitEvent>(_onSwitchCartItemUnit);
    on<AddCustomItemEvent>(_onAddCustomItem);
    on<RemoveProductFromCartEvent>(_onRemoveProductFromCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<ClearCartEvent>(_onClearCart);
    on<ParkCurrentCartEvent>(_onParkCurrentCart);
    on<ResumeHeldCartEvent>(_onResumeHeldCart);
    on<DeleteHeldCartEvent>(_onDeleteHeldCart);
    on<ResumeParkedCartEvent>(_onResumeParkedCart);
    on<SetPaidAmountEvent>(_onSetPaidAmount);
    on<PrintReceiptEvent>(_onPrintReceipt);
    on<ApplyDiscountEvent>(_onApplyDiscount);
    on<RemoveDiscountEvent>(_onRemoveDiscount);
    on<ToggleReturnModeEvent>(_onToggleReturnMode);
  }

  void _onApplyDiscount(ApplyDiscountEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(
      discountValue: event.value,
      isDiscountPercentage: event.isPercentage,
    ));
  }

  void _onRemoveDiscount(RemoveDiscountEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(
      discountValue: 0.0,
      isDiscountPercentage: false,
    ));
  }

  void _onToggleReturnMode(ToggleReturnModeEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(
      isReturnMode: !state.isReturnMode,
    ));
  }

  Future<void> _onScanBarcode(
      ScanBarcodeEvent event, Emitter<BillingState> emit) async {
    // 1. Check if barcode is an in-store weighing scale barcode (Prefix 20, 21, 22...)
    final scaleResult = ScaleBarcodeParser.parse(event.barcode);
    if (scaleResult.isScaleBarcode) {
      if (scaleResult.embeddedPrice != null) {
        add(AddCustomItemEvent(
          name: 'سلعة ميزان (${scaleResult.productCode})',
          price: scaleResult.embeddedPrice!,
          barcode: event.barcode,
        ));
        return;
      } else if (scaleResult.weightKg != null) {
        var result = await getProductByBarcodeUseCase(scaleResult.productCode);
        if (result.isLeft() && scaleResult.productCodeAlt.isNotEmpty) {
          result = await getProductByBarcodeUseCase(scaleResult.productCodeAlt);
        }
        result.fold(
          (_) {
            // Add as generic weight item
            final weightGrams = (scaleResult.weightKg! * 1000).toInt();
            add(AddCustomItemEvent(
              name: 'ميزان $weightGrams غرام (${scaleResult.productCode})',
              price: (scaleResult.weightKg! * 200).roundToDouble(), // default rate if not found
              barcode: event.barcode,
            ));
          },
          (prod) {
            final weightGrams = (scaleResult.weightKg! * 1000).toInt();
            final totalPrice = (prod.price * scaleResult.weightKg!).roundToDouble();
            add(AddCustomItemEvent(
              name: '${prod.name} ($weightGrams غ)',
              price: totalPrice,
              costPrice: (prod.costPrice * scaleResult.weightKg!).roundToDouble(),
              barcode: event.barcode,
            ));
          },
        );
        return;
      }
    }

    final result = await getProductByBarcodeUseCase(event.barcode);
    result.fold(
      (failure) =>
          emit(state.copyWith(error: 'Product not found: ${event.barcode}')),
      (product) {
        if (product.packBarcode.isNotEmpty && BarcodeNormalizer.matches(product.packBarcode, event.barcode)) {
          add(AddProductToCartEvent(product, unitLevel: 'carton'));
        } else {
          add(AddProductToCartEvent(product, unitLevel: 'pack'));
        }
      },
    );
  }

  void _onAddCustomItem(
      AddCustomItemEvent event, Emitter<BillingState> emit) {
    final customProduct = Product(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: event.name,
      barcode: event.barcode ?? 'CUSTOM',
      price: event.price,
      costPrice: event.costPrice,
      stock: 999,
    );
    final newItem = CartItem(product: customProduct, quantity: event.quantity);
    emit(state.copyWith(
      cartItems: [...state.cartItems, newItem],
      error: null,
    ));
  }

  void _onAddProductToCart(
      AddProductToCartEvent event, Emitter<BillingState> emit) {
    // Clear error when adding
    final cleanState = state.copyWith(error: null);

    final targetKey = '${event.product.id}_${event.unitLevel}';
    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.cartKey == targetKey);
    if (existingIndex >= 0) {
      final existingItem = cleanState.cartItems[existingIndex];
      final backendItems = List<CartItem>.from(cleanState.cartItems);
      backendItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + event.quantity,
        customUnitPrice: event.customPrice ?? existingItem.customUnitPrice,
      );
      emit(cleanState.copyWith(cartItems: backendItems, error: null));
    } else {
      final newItem = CartItem(
        product: event.product,
        quantity: event.quantity,
        unitLevel: event.unitLevel,
        customUnitPrice: event.customPrice,
      );
      emit(cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem], error: null));
    }
  }

  void _onSwitchCartItemUnit(
      SwitchCartItemUnitEvent event, Emitter<BillingState> emit) {
    final index = state.cartItems.indexWhere((item) => item.cartKey == event.cartKey);
    if (index < 0) return;

    final currentItem = state.cartItems[index];
    if (currentItem.unitLevel == event.targetUnit) return;

    final targetKey = '${currentItem.product.id}_${event.targetUnit}';
    final targetExistingIndex = state.cartItems.indexWhere((item) => item.cartKey == targetKey);

    final updatedCart = List<CartItem>.from(state.cartItems);
    final targetQuantity = event.newQuantity ?? currentItem.quantity;

    if (targetExistingIndex >= 0 && targetExistingIndex != index) {
      final existingTarget = updatedCart[targetExistingIndex];
      updatedCart[targetExistingIndex] = existingTarget.copyWith(
        quantity: existingTarget.quantity + targetQuantity,
      );
      updatedCart.removeAt(index);
    } else {
      updatedCart[index] = currentItem.copyWith(
        unitLevel: event.targetUnit,
        quantity: targetQuantity,
        customUnitPrice: null, // Reset custom price when changing units
      );
    }

    emit(state.copyWith(cartItems: updatedCart));
  }

  void _onRemoveProductFromCart(
      RemoveProductFromCartEvent event, Emitter<BillingState> emit) {
    final hasExactCartKey = state.cartItems.any((item) => item.cartKey == event.productId);
    final updatedList = state.cartItems.where((item) {
      if (hasExactCartKey) {
        return item.cartKey != event.productId;
      }
      return item.product.id != event.productId;
    }).toList();
    emit(state.copyWith(cartItems: updatedList));
  }

  void _onUpdateQuantity(
      UpdateQuantityEvent event, Emitter<BillingState> emit) {
    if (event.quantity <= 0) {
      add(RemoveProductFromCartEvent(event.productId));
      return;
    }

    int index = state.cartItems
        .indexWhere((item) => item.cartKey == event.productId);
    if (index < 0) {
      index = state.cartItems
          .indexWhere((item) => item.product.id == event.productId);
    }
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(quantity: event.quantity);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(
      cartItems: [],
      paidAmount: 0.0,
      printSuccess: false,
      discountValue: 0.0,
      isDiscountPercentage: false,
      isReturnMode: false,
    ));
  }

  void _onParkCurrentCart(
      ParkCurrentCartEvent event, Emitter<BillingState> emit) {
    if (state.cartItems.isEmpty) return;

    // 1. Purge any expired carts (>20 mins)
    final freshCarts = state.heldCarts.where((c) => !c.isExpired).toList();

    // 2. Create new held cart
    final cartIndex = freshCarts.length + 1;
    final label = (event.label != null && event.label!.trim().isNotEmpty)
        ? event.label!.trim()
        : 'سلة مؤقتة #$cartIndex';

    final newHeld = HeldCart(
      id: 'held_${DateTime.now().millisecondsSinceEpoch}',
      label: label,
      parkedAt: DateTime.now(),
      items: List.from(state.cartItems),
    );

    emit(state.copyWith(
      heldCarts: [newHeld, ...freshCarts],
      cartItems: [],
      paidAmount: 0.0,
    ));
  }

  void _onResumeHeldCart(
      ResumeHeldCartEvent event, Emitter<BillingState> emit) {
    final freshCarts = state.heldCarts.where((c) => !c.isExpired).toList();
    final targetIndex = freshCarts.indexWhere((c) => c.id == event.heldCartId);
    if (targetIndex < 0) return;

    final targetCart = freshCarts[targetIndex];
    final remainingCarts = List<HeldCart>.from(freshCarts)..removeAt(targetIndex);

    // If current cart has items, park them first or append
    List<CartItem> combinedItems;
    if (state.cartItems.isNotEmpty) {
      combinedItems = [...targetCart.items, ...state.cartItems];
    } else {
      combinedItems = List.from(targetCart.items);
    }

    emit(state.copyWith(
      cartItems: combinedItems,
      heldCarts: remainingCarts,
      paidAmount: 0.0,
    ));
  }

  void _onDeleteHeldCart(
      DeleteHeldCartEvent event, Emitter<BillingState> emit) {
    final updated = state.heldCarts.where((c) => c.id != event.heldCartId).toList();
    emit(state.copyWith(heldCarts: updated));
  }

  void _onCleanExpiredHeldCarts(
      CleanExpiredHeldCartsEvent event, Emitter<BillingState> emit) {
    final freshCarts = state.heldCarts.where((c) => !c.isExpired).toList();
    if (freshCarts.length != state.heldCarts.length) {
      emit(state.copyWith(heldCarts: freshCarts));
    }
  }

  void _onResumeParkedCart(
      ResumeParkedCartEvent event, Emitter<BillingState> emit) {
    final freshCarts = state.activeHeldCarts;
    if (freshCarts.isEmpty) return;
    add(ResumeHeldCartEvent(freshCarts.first.id));
  }

  void _onSetPaidAmount(
      SetPaidAmountEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(paidAmount: event.amount));
  }

  Future<void> _onPrintReceipt(
      PrintReceiptEvent event, Emitter<BillingState> emit) async {
    final printerHelper = PrinterHelper();

    if (!Platform.isWindows && !printerHelper.isConnected) {
      final savedMac = HiveDatabase.settingsBox.get('printer_mac');
      if (savedMac != null) {
        final connected = await printerHelper.connect(savedMac);
        if (!connected) {
          emit(state.copyWith(
              error: 'Failed to auto-connect to printer!', clearError: false));
          emit(state.copyWith(clearError: true));
          return;
        }
      } else {
        emit(state.copyWith(
            error: 'Printer not connected & no saved printer found!',
            clearError: false));
        emit(state.copyWith(clearError: true));
        return;
      }
    }

    emit(state.copyWith(
        isPrinting: true, printSuccess: false, clearError: true));

    try {
      final items = state.cartItems
          .map((item) => {
                'id': item.product.id,
                'cartKey': item.cartKey,
                'name': item.displayNameWithUnit,
                'unitLevel': item.unitLevel,
                'unitName': item.unitDisplayName,
                'qty': item.quantity,
                'price': item.unitPrice,
                'costPrice': item.unitCost,
                'isTobacco': item.product.isTobacco || item.product.category.contains('تبغ') || item.product.category.contains('سجائر'),
                'category': item.product.category,
                'total': item.total,
                'profit': (item.unitPrice - item.unitCost) * item.quantity,
              })
          .toList();

      // 1. Auto-deduct stock from Hive for all sold products
      final productBox = HiveDatabase.productBox;
      for (final cartItem in state.cartItems) {
        String originalId = cartItem.product.id;
        if (originalId.contains('_carton_')) {
          originalId = originalId.split('_carton_').first;
        } else if (originalId.contains('_piece_')) {
          originalId = originalId.split('_piece_').first;
        } else if (originalId.contains('_meter_')) {
          originalId = originalId.split('_meter_').first;
        } else if (originalId.contains('_ml_')) {
          originalId = originalId.split('_ml_').first;
        } else if (originalId.endsWith('_pack')) {
          originalId = originalId.replaceAll('_pack', '');
        }

        final productModel = productBox.get(originalId);
        if (productModel != null) {
          int deductAmount = 1;
          if (cartItem.unitLevel == 'carton' || cartItem.product.id.contains('_carton_')) {
            final multiplier = productModel.packsPerCarton > 0
                ? productModel.packsPerCarton
                : (productModel.packMultiplier > 0 ? productModel.packMultiplier : 10);
            deductAmount = cartItem.quantity * multiplier;
          } else if (cartItem.unitLevel == 'piece' || cartItem.product.id.contains('_piece_')) {
            final pPerPack = productModel.piecesPerPack > 0 ? productModel.piecesPerPack : 20;
            deductAmount = (cartItem.quantity / pPerPack).ceil();
            if (deductAmount < 1 && cartItem.quantity > 0) deductAmount = 1;
          } else if (cartItem.product.id.endsWith('_pack')) {
            deductAmount = cartItem.quantity * (cartItem.product.packMultiplier > 0 ? cartItem.product.packMultiplier : 1);
          } else {
            deductAmount = cartItem.quantity;
          }

          final newStock = (productModel.stock - deductAmount).clamp(0, 999999);
          productBox.put(
            originalId,
            productModel.copyWith(stock: newStock),
          );

          // SMART SHOPPING LIST AUTOMATION
          if (newStock <= 5) {
            final shoppingList = HiveDatabase.shoppingListBox;
            final existingList = shoppingList.get(originalId);
            if (existingList == null) {
              shoppingList.put(originalId, {
                'id': originalId,
                'name': productModel.name,
                'currentStock': newStock,
                'qtyToBuy': 10, // Suggested refill qty
              });
            } else if (existingList is Map) {
               final updatedList = Map<String, dynamic>.from(existingList);
               updatedList['currentStock'] = newStock;
               shoppingList.put(originalId, updatedList);
            }
          }
        }
      }

      // 2. Record sale invoice in invoicesBox with separate Tobacco vs General analytics
      final invoicesBox = HiveDatabase.invoicesBox;
      final invoiceId = DateTime.now().millisecondsSinceEpoch.toString();
      final totalCost = state.cartItems.fold<double>(
        0.0,
        (sum, i) => sum + (i.unitCost * i.quantity),
      );

      final subtotal = state.subTotalAmount;
      final discountRatio = (subtotal > 0) ? (state.totalAmount / subtotal) : 1.0;

      final tobaccoItems = state.cartItems.where(
        (i) => i.product.isTobacco || i.product.category.contains('تبغ') || i.product.category.contains('سجائر'),
      );
      final rawTobaccoSales = tobaccoItems.fold<double>(0.0, (sum, i) => sum + i.total);
      final tobaccoSales = rawTobaccoSales * discountRatio;
      final tobaccoCost = tobaccoItems.fold<double>(0.0, (sum, i) => sum + (i.unitCost * i.quantity));
      final tobaccoProfit = tobaccoSales - tobaccoCost;

      final generalSales = (state.totalAmount - tobaccoSales).clamp(0.0, double.infinity);
      final generalCost = (totalCost - tobaccoCost).clamp(0.0, double.infinity);
      final generalProfit = generalSales - generalCost;
      final netProfit = state.totalAmount - totalCost;

      await invoicesBox.put(invoiceId, {
        'id': invoiceId,
        'timestamp': DateTime.now().toIso8601String(),
        'totalAmount': state.totalAmount,
        'totalCost': totalCost,
        'netProfit': netProfit,
        'tobaccoSales': tobaccoSales,
        'tobaccoCost': tobaccoCost,
        'tobaccoProfit': tobaccoProfit,
        'generalSales': generalSales,
        'generalCost': generalCost,
        'generalProfit': generalProfit,
        'itemCount': state.cartItems.fold<int>(0, (sum, i) => sum + i.quantity),
        'items': items,
        'isCredit': event.isCredit,
        'paymentMethod': event.paymentMethod,
        'customerName': event.customerName,
        'paidAmount': event.paidAmount,
      });

      // 3. Print physical receipt (unless skipped)
      if (!event.skipPhysicalPrint) {
        await printerHelper.printReceipt(
          shopName: event.shopName,
          address1: event.address1,
          address2: event.address2,
          phone: event.phone,
          items: items,
          total: state.totalAmount,
          footer: event.footer,
          customerName: event.customerName,
          isCredit: event.isCredit,
          paidAmount: event.paidAmount,
          previousDebt: event.previousDebt,
          newDebtTotal: event.newDebtTotal,
          specificPrinterName: event.specificPrinterName,
        );
      }

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(state.copyWith(
          isPrinting: false, error: 'Print failed: $e', clearError: false));
      emit(state.copyWith(clearError: true));
    }
  }
}
