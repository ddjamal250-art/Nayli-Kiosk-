import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/held_cart.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/data/models/product_model.dart';
import '../../../product/domain/usecases/product_usecases.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/scale_barcode_parser.dart';
import '../../../../core/utils/barcode_normalizer.dart';
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
        // باركود يحتوي على سعر جاهز مباشرة
        add(AddCustomItemEvent(
          name: 'سلعة ميزان (${scaleResult.productCode})',
          price: scaleResult.embeddedPrice!,
          barcode: event.barcode,
        ));
        return;
      } else if (scaleResult.weightKg != null) {
        // باركود يحتوي على وزن → ابحث عن المنتج بـ PLU أولاً
        final pluNum = scaleResult.productCode.replaceFirst(RegExp(r'^0+'), '');

        // محاولة 1: بحث بـ PLU
        var result = await getProductByBarcodeUseCase('PLU_$pluNum');
        // محاولة 2: بحث بكود المنتج 5 أرقام
        if (result.isLeft()) {
          result = await getProductByBarcodeUseCase(scaleResult.productCode);
        }
        // محاولة 3: بكود مختصر
        if (result.isLeft() && scaleResult.productCodeAlt.isNotEmpty) {
          result = await getProductByBarcodeUseCase(scaleResult.productCodeAlt);
        }

        result.fold(
          (_) {
            // لم يُجد المنتج → أضف عنصر ميزان مجهول بسعر 0
            final weightGrams = (scaleResult.weightKg! * 1000).toInt();
            add(AddCustomItemEvent(
              name: '⚖️ ميزان ${weightGrams}غ [PLU $pluNum]',
              price: 0.0,
              barcode: event.barcode,
            ));
          },
          (prod) {
            final weightKg = scaleResult.weightKg!;
            final weightGrams = (weightKg * 1000).toInt();
            // إيجاد وحدة الميزان المفعّلة
            final weighableUnit = prod.units.firstWhereOrNull(
                (u) => u.isWeighable && u.isEnabled);
            final pricePerKg = weighableUnit?.price ?? prod.price;
            final costPerKg = (weighableUnit != null && weighableUnit.cost > 0)
                ? weighableUnit.cost : prod.costPrice;
            final totalSale = weightKg * pricePerKg;
            final totalCost = weightKg * costPerKg;

            add(AddProductToCartEvent(
              prod,
              unitLevel: weighableUnit?.name ?? 'base',
              quantity: 1,
              customPrice: totalSale,
              customUnitCost: totalCost,
              customUnitName: '${weightGrams}غ',
              weightKg: weightKg,
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
        String targetUnitName = 'base';
        if (BarcodeNormalizer.matches(product.barcode, event.barcode)) {
          targetUnitName = 'base';
        } else {
          final matchedUnit = product.units.where((u) => u.barcode != null && u.barcode!.isNotEmpty && BarcodeNormalizer.matches(u.barcode!, event.barcode)).firstOrNull;
          if (matchedUnit != null) {
            targetUnitName = matchedUnit.name;
          }
        }
        add(AddProductToCartEvent(product, unitLevel: targetUnitName));
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

    // للمنتجات الميزانية: كل مسح = عنصر جديد (لا ندمج بالوزن)
    final isWeighableAdd = event.weightKg != null;

    final targetKey = '${event.product.id}_${event.unitLevel}';
    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.cartKey == targetKey);
    if (!isWeighableAdd && existingIndex >= 0) {
      // منتج عادي موجود → نزيد الكمية
      final existingItem = cleanState.cartItems[existingIndex];
      final backendItems = List<CartItem>.from(cleanState.cartItems);
      backendItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + event.quantity,
        customUnitPrice: event.customPrice ?? existingItem.customUnitPrice,
        customUnitName: event.customUnitName ?? existingItem.customUnitName,
        customUnitCost: event.customUnitCost ?? existingItem.customUnitCost,
      );
      emit(cleanState.copyWith(cartItems: backendItems, error: null));
    } else {
      // منتج جديد أو منتج ميزاني (يُضاف دائماً كعنصر جديد)
      final newItem = CartItem(
        product: event.product,
        quantity: event.quantity,
        unitLevel: event.unitLevel,
        customUnitPrice: event.customPrice,
        customUnitName: event.customUnitName,
        customUnitCost: event.customUnitCost,
        weightKg: event.weightKg,
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
    final updatedCart = List<CartItem>.from(state.cartItems);
    final targetQuantity = event.newQuantity ?? currentItem.quantity;
    final targetWeight = event.weightKg ?? currentItem.weightKg;
    final isWeighableSwitch = targetWeight != null;

    // Direct update of custom price, custom name, or quantity on same unit
    if (currentItem.unitLevel == event.targetUnit) {
      updatedCart[index] = currentItem.copyWith(
        quantity: targetQuantity,
        customUnitPrice: event.customUnitPrice ?? currentItem.customUnitPrice,
        customUnitName: event.customUnitName ?? currentItem.customUnitName,
        weightKg: targetWeight,
      );
      emit(state.copyWith(cartItems: updatedCart, error: null));
      return;
    }

    final targetKey = '${currentItem.product.id}_${event.targetUnit}';
    final targetExistingIndex = state.cartItems.indexWhere((item) => item.cartKey == targetKey);

    // Only merge if it's NOT a weighable item
    if (!isWeighableSwitch && targetExistingIndex >= 0 && targetExistingIndex != index) {
      final existingTarget = updatedCart[targetExistingIndex];
      updatedCart[targetExistingIndex] = existingTarget.copyWith(
        quantity: existingTarget.quantity + targetQuantity,
        customUnitPrice: event.customUnitPrice ?? existingTarget.customUnitPrice,
        customUnitName: event.customUnitName ?? existingTarget.customUnitName,
      );
      updatedCart.removeAt(index);
    } else {
      updatedCart[index] = currentItem.copyWith(
        unitLevel: event.targetUnit,
        quantity: targetQuantity,
        customUnitPrice: event.customUnitPrice,
        customUnitName: event.customUnitName,
        weightKg: targetWeight,
      );
    }

    emit(state.copyWith(cartItems: updatedCart, error: null));
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
                'weightKg': item.weightKg,
                'price': item.unitPrice,
                'costPrice': item.unitCost,
                'category': item.product.category,
                'total': item.total,
                'profit': item.profit,
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
          double newStock = 0.0;

          if (productModel.coffeeRecipeJson != null) {
            // Deduct raw materials instead of this product's stock.
            // The cup itself has stock=999, no need to deduct.
            try {
              final recipe = jsonDecode(productModel.coffeeRecipeJson!);
              if (recipe.isNotEmpty) {
                 final item = recipe.first;
                 final rawId = item['rawProductId'];
                 final double gramsPerCup = (item['qty'] as num).toDouble();
                 final rawProduct = productBox.get(rawId);
                 if (rawProduct != null) {
                    final deductGrams = (gramsPerCup * cartItem.quantity).round();
                    final double newRawStock = state.isReturnMode 
                        ? (rawProduct.stock + deductGrams).toDouble() : (rawProduct.stock - deductGrams).toDouble().clamp(0.0, 9999999.0);
                    
          // FIFO Batch Deduction
          List<PurchaseBatch> updatedBatches = List.from(rawProduct.stockBatches);
          if (!state.isReturnMode && updatedBatches.isNotEmpty) {
             double remainingToDeduct = (rawProduct.stock - newRawStock).toDouble();
             updatedBatches.sort((a, b) => a.dateAdded.compareTo(b.dateAdded)); // Oldest first
             
             for (int i = 0; i < updatedBatches.length; i++) {
                 if (remainingToDeduct <= 0) break;
                 
                 final batch = updatedBatches[i];
                 if (batch.remainingQuantity <= remainingToDeduct) {
                     remainingToDeduct -= batch.remainingQuantity;
                     updatedBatches[i] = batch.copyWith(remainingQuantity: 0);
                 } else {
                     updatedBatches[i] = batch.copyWith(remainingQuantity: batch.remainingQuantity - remainingToDeduct);
                     remainingToDeduct = 0;
                 }
             }
             updatedBatches.removeWhere((b) => b.remainingQuantity <= 0);
          } else if (state.isReturnMode) {
             // On return, just add it to the newest batch or create one
             if (updatedBatches.isNotEmpty) {
                 updatedBatches.sort((a, b) => b.dateAdded.compareTo(a.dateAdded)); // Newest first
                 final newest = updatedBatches.first;
                 updatedBatches[0] = newest.copyWith(remainingQuantity: newest.remainingQuantity + (newRawStock - rawProduct.stock).toDouble());
             }
          }

          productBox.put(rawId, rawProduct.copyWith(stock: newRawStock, stockBatches: updatedBatches));
                 }
              }
            } catch (_) {}
            continue; // Skip the rest of the deduction for the cup itself
          }

          // fallback to original weighable check
          final hasWeighable = productModel.units.any((u) => u.isWeighable && u.isEnabled);
          if (hasWeighable && cartItem.weightKg != null) {
            final deductGrams = (cartItem.weightKg! * 1000).round();
            newStock = state.isReturnMode
                ? (productModel.stock + deductGrams).toDouble() : (productModel.stock - deductGrams).toDouble().clamp(0.0, 9999999.0);
          } else {
            // منتج عادي: stock بالحبة
            final deductInt = cartItem.totalStockDeduct.round();
            newStock = state.isReturnMode
                ? (productModel.stock + deductInt).toDouble()
                : (productModel.stock - deductInt).toDouble().clamp(0.0, 999999.0);
          }

          
          // FIFO Batch Deduction
          List<PurchaseBatch> updatedBatches = List.from(productModel.stockBatches);
          if (!state.isReturnMode && updatedBatches.isNotEmpty) {
             double remainingToDeduct = (productModel.stock - newStock).toDouble();
             updatedBatches.sort((a, b) => a.dateAdded.compareTo(b.dateAdded)); // Oldest first
             
             for (int i = 0; i < updatedBatches.length; i++) {
                 if (remainingToDeduct <= 0) break;
                 
                 final batch = updatedBatches[i];
                 if (batch.remainingQuantity <= remainingToDeduct) {
                     remainingToDeduct -= batch.remainingQuantity;
                     updatedBatches[i] = batch.copyWith(remainingQuantity: 0);
                 } else {
                     updatedBatches[i] = batch.copyWith(remainingQuantity: batch.remainingQuantity - remainingToDeduct);
                     remainingToDeduct = 0;
                 }
             }
             updatedBatches.removeWhere((b) => b.remainingQuantity <= 0);
          } else if (state.isReturnMode) {
             // On return, just add it to the newest batch or create one
             if (updatedBatches.isNotEmpty) {
                 updatedBatches.sort((a, b) => b.dateAdded.compareTo(a.dateAdded)); // Newest first
                 final newest = updatedBatches.first;
                 updatedBatches[0] = newest.copyWith(remainingQuantity: newest.remainingQuantity + (newStock - productModel.stock).toDouble());
             }
          }

          productBox.put(originalId, productModel.copyWith(stock: newStock, stockBatches: updatedBatches));

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
      // استخدم totalCostForInvoice لدعم المنتجات الميزانية (وزن × تكلفة/كغ)
      // Recalculate true cost for invoice (especially for coffee recipes)
      double totalCost = 0.0;
      double coffeeCost = 0.0;
      double tobaccoCost = 0.0;
      
      for (final i in state.cartItems) {
         double itemCost = i.totalCostForInvoice;
         
         // Dynamic Coffee Cost Evaluation based on Raw Material's current FIFO batches
         if (i.product.coffeeRecipeJson != null) {
            try {
              final recipe = jsonDecode(i.product.coffeeRecipeJson!);
              if (recipe.isNotEmpty) {
                 final rawId = recipe.first['rawProductId'];
                 final double gramsPerCup = (recipe.first['qty'] as num).toDouble();
                 final rawProduct = productBox.get(rawId);
                 if (rawProduct != null && rawProduct.stockBatches.isNotEmpty) {
                    final newestBatch = rawProduct.stockBatches.first; // Or oldest batch
                    final costPerGram = newestBatch.costPrice / 1000.0;
                    itemCost = costPerGram * gramsPerCup * i.quantity;
                 }
              }
            } catch (_) {}
            coffeeCost += itemCost;
         } else if (i.product.category.toLowerCase().contains('تبغ') || i.product.category.toLowerCase().contains('سجائر')) {
            tobaccoCost += itemCost;
         }
         
         totalCost += itemCost;
      }

      final subtotal = state.subTotalAmount;
      final discountRatio = (subtotal > 0) ? (state.totalAmount / subtotal) : 1.0;

      final tobaccoItems = state.cartItems.where(
        (i) => i.product.category.toLowerCase().contains('تبغ') || i.product.category.toLowerCase().contains('سجائر'),
      );
      final rawTobaccoSales = tobaccoItems.fold<double>(0.0, (sum, i) => sum + i.total);
      final tobaccoSales = rawTobaccoSales * discountRatio;
      
      final tobaccoProfit = tobaccoSales - tobaccoCost;

      final coffeeItems = state.cartItems.where(
        (i) => i.product.category.toLowerCase().contains('قهوة') || i.product.category.toLowerCase().contains('شاي'),
      );
      final rawCoffeeSales = coffeeItems.fold<double>(0.0, (sum, i) => sum + i.total);
      final coffeeSales = rawCoffeeSales * discountRatio;
      
      final coffeeProfit = coffeeSales - coffeeCost;
      final coffeeCupsCount = coffeeItems.fold<double>(0.0, (sum, i) => sum + i.quantity);

      final generalSales = (state.totalAmount - tobaccoSales - coffeeSales).clamp(0.0, double.infinity);
      final generalCost = (totalCost - tobaccoCost - coffeeCost).clamp(0.0, double.infinity);
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
        'coffeeSales': coffeeSales,
        'coffeeCost': coffeeCost,
        'coffeeProfit': coffeeProfit,
        'coffeeCupsCount': coffeeCupsCount,
        'generalSales': generalSales,
        'generalCost': generalCost,
        'generalProfit': generalProfit,
        'itemCount': state.cartItems.fold<double>(0.0, (sum, i) => sum + i.quantity),
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
