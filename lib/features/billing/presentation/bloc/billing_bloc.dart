import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:bloc/bloc.dart';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/held_cart.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/domain/entities/product_option.dart';
import '../../../product/data/models/product_model.dart';
import '../../../product/domain/usecases/product_usecases.dart';
import '../../../shifts/data/shift_service.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/scale_barcode_parser.dart';
import '../../../../core/utils/barcode_normalizer.dart';
import '../../../../core/utils/staff_permissions_service.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/data/local_sync_server.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;

  BillingBloc({required this.getProductByBarcodeUseCase})
      : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<UpdateCartItemNoteEvent>(_onUpdateCartItemNote);
    on<ClearStockWarningEvent>((event, emit) => emit(state.copyWith(clearStockWarning: true)));
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

    final tempItem = CartItem(
      product: event.product,
      unitLevel: event.unitLevel,
      customUnitPrice: event.customPrice,
      customUnitName: event.customUnitName,
      customUnitCost: event.customUnitCost,
      weightKg: event.weightKg,
      customMultiplier: event.customMultiplier,
      itemNote: event.itemNote,
      selectedOptions: event.selectedOptions,
    );
    final targetKey = tempItem.cartKey;

    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.cartKey == targetKey);
    if (!isWeighableAdd && existingIndex >= 0) {
      // منتج عادي موجود بنفس الخيارات والملاحظات → نزيد الكمية
      final existingItem = cleanState.cartItems[existingIndex];
      final backendItems = List<CartItem>.from(cleanState.cartItems);
      final newQty = existingItem.quantity + event.quantity;
      final mult = event.customMultiplier ?? (existingItem.customMultiplier ?? (existingItem.selectedUnit?.multiplier ?? 1.0));
      final proposedDeduct = newQty * mult;
      String? warning;
      if (!event.suppressStockWarning &&
          !event.product.isUnlimitedStock &&
          (event.product.stock <= 0 || proposedDeduct > event.product.stock)) {
        warning = '${event.product.id}|${event.product.name}|${event.product.stock}|$proposedDeduct';
      }
      
      backendItems[existingIndex] = existingItem.copyWith(
        quantity: newQty,
        customUnitPrice: event.customPrice ?? existingItem.customUnitPrice,
        customUnitName: event.customUnitName ?? existingItem.customUnitName,
        customUnitCost: event.customUnitCost ?? existingItem.customUnitCost,
        customMultiplier: event.customMultiplier ?? existingItem.customMultiplier,
      );
      emit(cleanState.copyWith(cartItems: backendItems, error: null, stockWarning: warning));
    } else {
      // منتج جديد أو منتج ميزاني أو خيارات مختلفة
      final newItem = CartItem(
        product: event.product,
        quantity: event.quantity,
        unitLevel: event.unitLevel,
        customUnitPrice: event.customPrice,
        customUnitName: event.customUnitName,
        customUnitCost: event.customUnitCost,
        weightKg: event.weightKg,
        customMultiplier: event.customMultiplier,
        itemNote: event.itemNote,
        selectedOptions: event.selectedOptions,
      );
      final proposedDeduct = newItem.totalStockDeduct;
      String? warning;
      if (!event.suppressStockWarning &&
          !event.product.isUnlimitedStock &&
          (event.product.stock <= 0 || proposedDeduct > event.product.stock)) {
        warning = '${event.product.id}|${event.product.name}|${event.product.stock}|$proposedDeduct';
      }
      emit(cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem], error: null, stockWarning: warning));
    }
  }

  void _onUpdateCartItemNote(
      UpdateCartItemNoteEvent event, Emitter<BillingState> emit) {
    final index = state.cartItems.indexWhere((item) => item.cartKey == event.cartKey);
    if (index < 0) return;
    final updatedCart = List<CartItem>.from(state.cartItems);
    updatedCart[index] = updatedCart[index].copyWith(itemNote: event.note);
    emit(state.copyWith(cartItems: updatedCart));
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
        customMultiplier: event.customMultiplier ?? currentItem.customMultiplier,
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
        customMultiplier: event.customMultiplier ?? existingTarget.customMultiplier,
      );
      updatedCart.removeAt(index);
    } else {
      updatedCart[index] = currentItem.copyWith(
        unitLevel: event.targetUnit,
        quantity: targetQuantity,
        customUnitPrice: event.customUnitPrice,
        customUnitName: event.customUnitName,
        weightKg: targetWeight,
        customMultiplier: event.customMultiplier ?? currentItem.customMultiplier,
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
      final currentItem = items[index];
      items[index] = currentItem.copyWith(quantity: event.quantity);
      final proposedDeduct = items[index].totalStockDeduct;
      String? warning;
      if (!event.suppressStockWarning &&
          !currentItem.product.isUnlimitedStock &&
          (currentItem.product.stock <= 0 || proposedDeduct > currentItem.product.stock)) {
        warning = '${currentItem.product.id}|${currentItem.product.name}|${currentItem.product.stock}|$proposedDeduct';
      }
      emit(state.copyWith(cartItems: items, stockWarning: warning));
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

    if (!event.skipPhysicalPrint && !Platform.isWindows && !printerHelper.isConnected) {
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
      final currentCartItems = List<CartItem>.from(state.cartItems);
      if (currentCartItems.isEmpty) {
        emit(state.copyWith(isPrinting: false, printSuccess: false));
        return;
      }

      final bool isReturn = event.isReturn ?? state.isReturnMode ?? (state.isRefund || currentCartItems.any((i) => i.isReturnItem));
      final double snapSubtotal = state.subTotalAmount;
      final double snapDiscount = event.explicitDiscount ?? state.calculatedDiscount;
      final double magnitude = event.explicitTotal != null && event.explicitTotal != 0
          ? event.explicitTotal!.abs()
          : (state.totalAmount != 0 ? state.totalAmount.abs() : snapSubtotal.abs());
      final double positiveTotal = magnitude;
      final bool allowNegativeStock = StaffPermissionsService.allowNegativeStockSale;

      // 1. Auto-deduct or restock from Hive for all products & compute true FIFO cost per cart item
      final productBox = HiveDatabase.productBox;
      final modifiedInventoryItems = <Map<String, dynamic>>[];
      final Map<int, double> fifoItemTotalCosts = {};

      for (int cartIdx = 0; cartIdx < currentCartItems.length; cartIdx++) {
        final cartItem = currentCartItems[cartIdx];
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
          final bool isItemReturn = isReturn || cartItem.isReturnItem || cartItem.total < 0;
          double newStock = 0.0;

          if (productModel.coffeeRecipeJson != null) {
            // Deduct or restock raw materials instead of this product's stock and calculate true FIFO recipe cost.
            double recipeTotalCost = 0.0;
            try {
              final recipe = jsonDecode(productModel.coffeeRecipeJson!);
              if (recipe is List && recipe.isNotEmpty) {
                for (final item in recipe) {
                  if (item is! Map) continue;
                  final rawId = item['rawProductId']?.toString();
                  if (rawId == null) continue;
                  final double qtyPerCup = (item['qty'] as num?)?.toDouble() ?? 0.0;
                  final String rawUnit = item['unit']?.toString() ?? 'غرام';
                  final bool isPieceUnit = rawUnit == 'حبة' || rawUnit == 'قطعة';
                  final rawProduct = productBox.get(rawId);
                  if (rawProduct != null) {
                    final double deductUnits = qtyPerCup * cartItem.quantity.abs();
                    final double newRawStock = isItemReturn
                        ? (rawProduct.stock + deductUnits).toDouble()
                        : (allowNegativeStock
                            ? (rawProduct.stock - deductUnits).toDouble()
                            : (rawProduct.stock - deductUnits).toDouble().clamp(0.0, 9999999.0));

                    // Compute FIFO ingredient cost before mutating batches
                    double baseRawCost = rawProduct.effectiveCostPrice;
                    if (rawProduct.stockBatches.isNotEmpty) {
                      final sortedBatches = List<PurchaseBatch>.from(rawProduct.stockBatches)
                        ..sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
                      if (sortedBatches.first.costPrice > 0) {
                        baseRawCost = sortedBatches.first.costPrice;
                      }
                    }
                    final double unitIngredientCost = isPieceUnit ? baseRawCost : (baseRawCost / 1000.0);
                    recipeTotalCost += unitIngredientCost * deductUnits;

                    // FIFO Batch Deduction or Restock
                    List<PurchaseBatch> updatedBatches = List.from(rawProduct.stockBatches);
                    if (!isItemReturn && updatedBatches.isNotEmpty) {
                      double remainingToDeduct = deductUnits;
                      updatedBatches.sort((a, b) => a.dateAdded.compareTo(b.dateAdded)); // Oldest first
                      final PurchaseBatch lastReferenceBatch = updatedBatches.last;

                      for (int i = 0; i < updatedBatches.length; i++) {
                        if (remainingToDeduct <= 0) break;

                        final batch = updatedBatches[i];
                        if (batch.remainingQuantity <= remainingToDeduct) {
                          remainingToDeduct -= batch.remainingQuantity.clamp(0.0, double.infinity);
                          updatedBatches[i] = batch.copyWith(remainingQuantity: 0);
                        } else {
                          updatedBatches[i] = batch.copyWith(
                              remainingQuantity: batch.remainingQuantity - remainingToDeduct);
                          remainingToDeduct = 0;
                        }
                      }
                      updatedBatches.removeWhere((b) => b.remainingQuantity <= 0);
                      if (updatedBatches.isEmpty) {
                        updatedBatches.add(lastReferenceBatch.copyWith(remainingQuantity: 0));
                      }
                    } else if (isItemReturn) {
                      if (updatedBatches.isNotEmpty) {
                        updatedBatches.sort((a, b) => b.dateAdded.compareTo(a.dateAdded)); // Newest first
                        final newest = updatedBatches.first;
                        updatedBatches[0] = newest.copyWith(
                            remainingQuantity: newest.remainingQuantity + deductUnits);
                      } else {
                        updatedBatches.add(PurchaseBatch(
                          remainingQuantity: deductUnits,
                          costPrice: rawProduct.costPrice,
                          dateAdded: DateTime.now(),
                        ));
                      }
                    }

                    productBox.put(rawId, rawProduct.copyWith(stock: newRawStock, stockBatches: updatedBatches));
                    modifiedInventoryItems.add({
                      'id': rawId,
                      'barcode': rawProduct.barcode,
                      'newStock': newRawStock,
                    });
                  }
                }
              }
            } catch (_) {}
            if (recipeTotalCost > 0) {
              fifoItemTotalCosts[cartIdx] = recipeTotalCost;
            }
            continue; // Skip the rest of the deduction for the cup itself
          }

          // الخصم أو الاسترجاع الحقيقي للمخزون (يدعم القطع، المقاسات، والمنتجات الموزونة بالكيلوغرام مباشرة)
          final deductQty = cartItem.totalStockDeduct.abs();
          newStock = isItemReturn
              ? (productModel.stock + deductQty).toDouble()
              : (allowNegativeStock
                  ? (productModel.stock - deductQty).toDouble()
                  : (productModel.stock - deductQty).toDouble().clamp(0.0, 9999999.0));

          // FIFO Batch Deduction or Restock + True FIFO COGS Calculation (Graviola Section 5.1)
          List<PurchaseBatch> updatedBatches = List.from(productModel.stockBatches);
          if (!isItemReturn && updatedBatches.isNotEmpty) {
            double remainingToDeduct = deductQty;
            double fifoCostSum = 0.0;
            updatedBatches.sort((a, b) => a.dateAdded.compareTo(b.dateAdded)); // Oldest first
            final PurchaseBatch lastReferenceBatch = updatedBatches.last;
            final double fallbackBaseCost = lastReferenceBatch.costPrice > 0
                ? lastReferenceBatch.costPrice
                : productModel.effectiveCostPrice;

            for (int i = 0; i < updatedBatches.length; i++) {
              if (remainingToDeduct <= 0) break;

              final batch = updatedBatches[i];
              if (batch.remainingQuantity <= 0) continue;
              final double batchUnitCost =
                  batch.costPrice > 0 ? batch.costPrice : fallbackBaseCost;

              if (batch.remainingQuantity <= remainingToDeduct) {
                final double taken = batch.remainingQuantity;
                fifoCostSum += taken * batchUnitCost;
                remainingToDeduct -= taken;
                updatedBatches[i] = batch.copyWith(remainingQuantity: 0);
              } else {
                fifoCostSum += remainingToDeduct * batchUnitCost;
                updatedBatches[i] = batch.copyWith(
                    remainingQuantity: batch.remainingQuantity - remainingToDeduct);
                remainingToDeduct = 0;
              }
            }

            if (remainingToDeduct > 0) {
              fifoCostSum += remainingToDeduct * fallbackBaseCost;
            }

            // If cartItem did not specify a custom unit cost override, use the exact FIFO batch cost
            if (cartItem.customUnitCost == null && fifoCostSum > 0) {
              fifoItemTotalCosts[cartIdx] = fifoCostSum;
            }

            updatedBatches.removeWhere((b) => b.remainingQuantity <= 0);
            // الحفاظ على آخر دفعة مرجعية بكمية 0 عند نفاذ المخزون لعدم ضياع سعر الشراء المرجعي والمورد
            if (updatedBatches.isEmpty) {
              updatedBatches.add(lastReferenceBatch.copyWith(remainingQuantity: 0));
            }
          } else if (isItemReturn) {
            // On return, add returned quantity back to the newest batch or create one
            final double returnedQty = deductQty;
            if (updatedBatches.isNotEmpty) {
              updatedBatches.sort((a, b) => b.dateAdded.compareTo(a.dateAdded)); // Newest first
              final newest = updatedBatches.first;
              updatedBatches[0] = newest.copyWith(
                  remainingQuantity: (newest.remainingQuantity > 0 ? newest.remainingQuantity : 0.0) + returnedQty);
            } else {
              updatedBatches.add(PurchaseBatch(
                remainingQuantity: returnedQty,
                costPrice: productModel.effectiveCostPrice,
                dateAdded: DateTime.now(),
              ));
            }
          }

          productBox.put(originalId, productModel.copyWith(stock: newStock, stockBatches: updatedBatches));
          modifiedInventoryItems.add({
            'id': originalId,
            'barcode': productModel.barcode,
            'newStock': newStock,
          });

          // SMART SHOPPING LIST AUTOMATION
          final bool isLiquid = productModel.liquidConfigJson != null || productModel.isLiquidProduct;
          final double lowStockThreshold = isLiquid
              ? (productModel.liquidConfig?.containerVolume ?? 100.0) * 0.15
              : 5.0;

          if (newStock <= lowStockThreshold) {
            final shoppingList = HiveDatabase.shoppingListBox;
            final existingList = shoppingList.get(originalId);
            final double refillQty = isLiquid ? (productModel.liquidConfig?.containerVolume ?? 100.0) : 10.0;
            if (existingList == null) {
              shoppingList.put(originalId, {
                'id': originalId,
                'name': productModel.name,
                'currentStock': newStock,
                'qtyToBuy': refillQty, // Suggested refill qty
              });
            } else if (existingList is Map) {
              final updatedList = Map<String, dynamic>.from(existingList);
              updatedList['currentStock'] = newStock;
              shoppingList.put(originalId, updatedList);
            }
          }
        }
      }

      // 2. Record sale invoice in invoicesBox with true FIFO cost & separate Tobacco vs General analytics
      final invoicesBox = HiveDatabase.invoicesBox;
      final invoiceId = DateTime.now().millisecondsSinceEpoch.toString();
      final subtotal = snapSubtotal;
      final discountRatio = (subtotal > 0) ? (positiveTotal / subtotal) : 1.0;

      double totalCost = 0.0;
      double coffeeCost = 0.0;
      double tobaccoCost = 0.0;
      final items = <Map<String, dynamic>>[];

      for (int idx = 0; idx < currentCartItems.length; idx++) {
        final i = currentCartItems[idx];
        double itemCost = fifoItemTotalCosts[idx] ?? i.totalCostForInvoice.abs();

        if (i.product.coffeeRecipeJson != null) {
          if (!fifoItemTotalCosts.containsKey(idx)) {
            try {
              final recipe = jsonDecode(i.product.coffeeRecipeJson!);
              if (recipe is List && recipe.isNotEmpty) {
                double totalCupCost = 0.0;
                for (final rawEntry in recipe) {
                  if (rawEntry is! Map) continue;
                  final rawId = rawEntry['rawProductId']?.toString();
                  if (rawId == null) continue;
                  final double qtyPerCup = (rawEntry['qty'] as num?)?.toDouble() ?? 0.0;
                  final String rawUnit = rawEntry['unit']?.toString() ?? 'غرام';
                  final bool isPieceUnit = rawUnit == 'حبة' || rawUnit == 'قطعة';
                  final rawProduct = productBox.get(rawId);
                  if (rawProduct != null) {
                    double baseCost = rawProduct.effectiveCostPrice;
                    if (rawProduct.stockBatches.isNotEmpty) {
                      final sorted = List<PurchaseBatch>.from(rawProduct.stockBatches)
                        ..sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
                      if (sorted.first.costPrice > 0) {
                        baseCost = sorted.first.costPrice;
                      }
                    }
                    final double costPerUnit = isPieceUnit ? baseCost : (baseCost / 1000.0);
                    totalCupCost += costPerUnit * qtyPerCup;
                  }
                }
                if (totalCupCost > 0) {
                  itemCost = totalCupCost * i.quantity.abs();
                }
              }
            } catch (_) {}
          }
          coffeeCost += itemCost;
        } else if (i.product.category.toLowerCase().contains('تبغ') ||
            i.product.category.toLowerCase().contains('سجائر')) {
          tobaccoCost += itemCost;
        }

        totalCost += itemCost;

        final double effectiveQty = i.weightKg ?? i.quantity.abs();
        final double effectiveUnitCost = effectiveQty > 0 ? (itemCost / effectiveQty) : i.unitCost;
        final double discountedItemTotal = i.total.abs() * discountRatio;
        final double itemNetProfit = isReturn
            ? -(discountedItemTotal - itemCost)
            : (discountedItemTotal - itemCost);

        items.add({
          'id': i.product.id,
          'barcode': i.product.barcode,
          'cartKey': i.cartKey,
          'name': i.displayNameWithUnit,
          'unitLevel': i.unitLevel,
          'unitName': i.unitDisplayName,
          'unitMultiplier': i.customMultiplier ?? i.selectedUnit?.multiplier ?? 1.0,
          'stockDeducted': i.totalStockDeduct,
          'qty': i.quantity,
          'weightKg': i.weightKg,
          'price': i.unitPrice,
          'costPrice': effectiveUnitCost,
          'totalCost': itemCost,
          'category': i.product.category,
          'total': i.total,
          'profit': itemNetProfit,
          'itemNote': i.itemNote,
          'selectedOptions': i.selectedOptions?.map((o) => o.toMap()).toList(),
        });
      }

      final tobaccoItems = currentCartItems.where(
        (i) => i.product.category.toLowerCase().contains('تبغ') || i.product.category.toLowerCase().contains('سجائر'),
      );
      final rawTobaccoSales = tobaccoItems.fold<double>(0.0, (sum, i) => sum + i.total);
      final tobaccoSales = rawTobaccoSales * discountRatio;
      
      final tobaccoProfit = tobaccoSales - tobaccoCost;

      final coffeeItems = currentCartItems.where(
        (i) => i.product.category.toLowerCase().contains('قهوة') || i.product.category.toLowerCase().contains('شاي'),
      );
      final rawCoffeeSales = coffeeItems.fold<double>(0.0, (sum, i) => sum + i.total);
      final coffeeSales = rawCoffeeSales * discountRatio;
      
      final coffeeProfit = coffeeSales - coffeeCost;
      final coffeeCupsCount = coffeeItems.fold<double>(0.0, (sum, i) => sum + i.quantity);

      final generalSales = (positiveTotal - tobaccoSales - coffeeSales).clamp(0.0, double.infinity);
      final generalCost = (totalCost - tobaccoCost - coffeeCost).clamp(0.0, double.infinity);
      final generalProfit = generalSales - generalCost;
      final netProfit = positiveTotal - totalCost;

      final double finalTotalAmount = isReturn ? -positiveTotal : positiveTotal;
      final double finalTotalCost = isReturn ? -totalCost : totalCost;
      final double finalNetProfit = isReturn ? -netProfit : netProfit;
      
      final double tenderedCash = event.receivedAmount ?? (event.paidAmount > 0 ? event.paidAmount : positiveTotal);
      final double changeBack = event.changeAmount ?? ((tenderedCash > positiveTotal && !event.isCredit) ? (tenderedCash - positiveTotal) : 0.0);
      final double effectiveCashPaid = event.isCredit
          ? (event.paidAmount > positiveTotal ? positiveTotal : event.paidAmount)
          : positiveTotal;

      final activeShift = await ShiftService.getActiveShift();

      await invoicesBox.put(invoiceId, {
        'shiftId': activeShift?.id,
        'workerName': activeShift?.workerName ?? 'Unknown',
        'id': invoiceId,
        'timestamp': DateTime.now().toIso8601String(),
        'subTotalAmount': isReturn ? -snapSubtotal.abs() : snapSubtotal.abs(),
        'discountAmount': snapDiscount.abs(),
        'totalAmount': finalTotalAmount,
        'totalCost': finalTotalCost,
        'netProfit': finalNetProfit,
        'isReturn': isReturn,
        'status': isReturn ? 'return' : (event.isCredit ? 'credit' : 'completed'),
        'tobaccoSales': isReturn ? -tobaccoSales : tobaccoSales,
        'tobaccoCost': isReturn ? -tobaccoCost : tobaccoCost,
        'tobaccoProfit': isReturn ? -tobaccoProfit : tobaccoProfit,
        'coffeeSales': isReturn ? -coffeeSales : coffeeSales,
        'coffeeCost': isReturn ? -coffeeCost : coffeeCost,
        'coffeeProfit': isReturn ? -coffeeProfit : coffeeProfit,
        'coffeeCupsCount': isReturn ? -coffeeCupsCount : coffeeCupsCount,
        'generalSales': isReturn ? -generalSales : generalSales,
        'generalCost': isReturn ? -generalCost : generalCost,
        'generalProfit': isReturn ? -generalProfit : generalProfit,
        'itemCount': isReturn ? -currentCartItems.fold<double>(0.0, (sum, i) => sum + i.quantity) : currentCartItems.fold<double>(0.0, (sum, i) => sum + i.quantity),
        'items': items,
        'isCredit': event.isCredit,
        'paymentMethod': event.paymentMethod,
        'customerName': event.customerName,
        'paidAmount': isReturn ? -positiveTotal : effectiveCashPaid,
        'receivedAmount': isReturn ? -positiveTotal : tenderedCash,
        'changeAmount': changeBack,
        'splitPayments': event.splitPayments,
        'orderNote': event.orderNote,
      });

      // بث التحديثات اللحظية لجميع الهواتف المتصلة (LAN أو WAN)
      if (modifiedInventoryItems.isNotEmpty) {
        try {
          LocalSyncServer.broadcastInventoryChange(modifiedInventoryItems);
        } catch (_) {}
      }
      try {
        LocalSyncServer.broadcastSaleCompleted({
          'id': invoiceId,
          'totalAmount': finalTotalAmount,
          'timestamp': DateTime.now().toIso8601String(),
          'items': items,
        });
      } catch (_) {}

      // تفريغ السلة وإنهاء عملية البيع فوراً في واجهة المستخدم دون أي تأخير
      emit(state.copyWith(
        cartItems: const [],
        isPrinting: false,
        printSuccess: true,
        discountValue: 0.0,
        isDiscountPercentage: false,
        isReturnMode: false,
      ));

      // 3. طباعة الإيصال في الخلفية بدون حجز الواجهة أو تأخير عمليات البيع
      if (!event.skipPhysicalPrint) {
        unawaited(
          printerHelper.printReceipt(
            shopName: event.shopName,
            address1: event.address1,
            address2: event.address2,
            phone: event.phone,
            items: items,
            total: positiveTotal,
            discount: snapDiscount,
            footer: event.footer,
            customerName: event.customerName,
            isCredit: event.isCredit,
            paidAmount: tenderedCash,
            previousDebt: event.previousDebt,
            newDebtTotal: event.newDebtTotal,
            specificPrinterName: event.specificPrinterName,
            invoiceId: invoiceId,
            isReturn: isReturn,
          ).catchError((e) {
            debugPrint('Physical receipt background printing error: $e');
          }),
        );
      }
    } catch (e) {
      emit(state.copyWith(
          isPrinting: false, error: 'Print failed: $e', clearError: false));
      emit(state.copyWith(clearError: true));
    }
  }
}
