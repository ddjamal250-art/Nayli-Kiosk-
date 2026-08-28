import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/cart_item.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/product/data/models/product_model.dart';
import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/data/hive_database.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;

  BillingBloc({required this.getProductByBarcodeUseCase})
      : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<RemoveProductFromCartEvent>(_onRemoveProductFromCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<ClearCartEvent>(_onClearCart);
    on<ParkCurrentCartEvent>(_onParkCurrentCart);
    on<ResumeParkedCartEvent>(_onResumeParkedCart);
    on<SetPaidAmountEvent>(_onSetPaidAmount);
    on<PrintReceiptEvent>(_onPrintReceipt);
  }

  Future<void> _onScanBarcode(
      ScanBarcodeEvent event, Emitter<BillingState> emit) async {
    final result = await getProductByBarcodeUseCase(event.barcode);
    result.fold(
      (failure) =>
          emit(state.copyWith(error: 'Product not found: ${event.barcode}')),
      (product) {
        add(AddProductToCartEvent(product));
      },
    );
  }

  void _onAddProductToCart(
      AddProductToCartEvent event, Emitter<BillingState> emit) {
    // Clear error when adding
    final cleanState = state.copyWith(error: null);

    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.product.id == event.product.id);
    if (existingIndex >= 0) {
      final existingItem = cleanState.cartItems[existingIndex];
      final backendItems = List<CartItem>.from(cleanState.cartItems);
      backendItems[existingIndex] =
          existingItem.copyWith(quantity: existingItem.quantity + 1);
      emit(cleanState.copyWith(cartItems: backendItems, error: null));
    } else {
      final newItem = CartItem(product: event.product);
      emit(cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem], error: null));
    }
  }

  void _onRemoveProductFromCart(
      RemoveProductFromCartEvent event, Emitter<BillingState> emit) {
    final updatedList = state.cartItems
        .where((item) => item.product.id != event.productId)
        .toList();
    emit(state.copyWith(cartItems: updatedList));
  }

  void _onUpdateQuantity(
      UpdateQuantityEvent event, Emitter<BillingState> emit) {
    if (event.quantity <= 0) {
      add(RemoveProductFromCartEvent(event.productId));
      return;
    }

    final index = state.cartItems
        .indexWhere((item) => item.product.id == event.productId);
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(quantity: event.quantity);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(cartItems: [], paidAmount: 0.0, printSuccess: false));
  }

  void _onParkCurrentCart(
      ParkCurrentCartEvent event, Emitter<BillingState> emit) {
    if (state.cartItems.isEmpty) return;
    emit(state.copyWith(
      parkedCartItems: List.from(state.cartItems),
      cartItems: [],
      paidAmount: 0.0,
    ));
  }

  void _onResumeParkedCart(
      ResumeParkedCartEvent event, Emitter<BillingState> emit) {
    if (state.parkedCartItems.isEmpty) return;
    emit(state.copyWith(
      cartItems: List.from(state.parkedCartItems),
      parkedCartItems: [],
      paidAmount: 0.0,
    ));
  }

  void _onSetPaidAmount(
      SetPaidAmountEvent event, Emitter<BillingState> emit) {
    emit(state.copyWith(paidAmount: event.amount));
  }

  Future<void> _onPrintReceipt(
      PrintReceiptEvent event, Emitter<BillingState> emit) async {
    final printerHelper = PrinterHelper();

    if (!printerHelper.isConnected) {
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
                'name': item.product.name,
                'qty': item.quantity,
                'price': item.product.price,
                'total': item.total,
              })
          .toList();

      // 1. Auto-deduct stock from Hive for all sold products
      final productBox = HiveDatabase.productBox;
      for (final cartItem in state.cartItems) {
        final productModel = productBox.get(cartItem.product.id);
        if (productModel != null) {
          final newStock = productModel.stock - cartItem.quantity;
          productBox.put(
            cartItem.product.id,
            ProductModel(
              id: productModel.id,
              name: productModel.name,
              barcode: productModel.barcode,
              price: productModel.price,
              stock: newStock,
            ),
          );
        }
      }

      // 2. Record sale invoice in invoicesBox for Daily Reports & History
      final invoicesBox = HiveDatabase.invoicesBox;
      final invoiceId = DateTime.now().millisecondsSinceEpoch.toString();
      final totalCost = state.cartItems.fold<double>(
        0.0,
        (sum, i) => sum + (i.product.costPrice * i.quantity),
      );

      await invoicesBox.put(invoiceId, {
        'id': invoiceId,
        'timestamp': DateTime.now().toIso8601String(),
        'totalAmount': state.totalAmount,
        'totalCost': totalCost,
        'netProfit': (state.totalAmount - totalCost).clamp(0.0, double.infinity),
        'itemCount': state.cartItems.fold<int>(0, (sum, i) => sum + i.quantity),
        'items': items,
        'isCredit': event.isCredit,
        'customerName': event.customerName,
        'paidAmount': event.paidAmount,
      });

      // 3. Print physical receipt
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
      );

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(state.copyWith(
          isPrinting: false, error: 'Print failed: $e', clearError: false));
      emit(state.copyWith(clearError: true));
    }
  }
}
