part of 'billing_bloc.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final List<HeldCart> heldCarts;
  final String? error;
  final bool isPrinting;
  final bool printSuccess;
  final double paidAmount;
  final double discountValue;
  final bool isDiscountPercentage;
  final bool isReturnMode;
  final String? stockWarning;

  const BillingState({
    this.cartItems = const [],
    this.heldCarts = const [],
    this.error,
    this.isPrinting = false,
    this.printSuccess = false,
    this.paidAmount = 0.0,
    this.discountValue = 0.0,
    this.isDiscountPercentage = false,
    this.isReturnMode = false,
    this.stockWarning,
  });

  bool get isRefund => isReturnMode || subTotalAmount < 0;
  double get subTotalAmount => cartItems.fold(0, (sum, item) => sum + item.total);
  double get calculatedDiscount => isDiscountPercentage ? (subTotalAmount.abs() * (discountValue / 100.0)) : discountValue;
  double get totalAmount {
    if (isRefund) {
      if (subTotalAmount < 0) {
        return (subTotalAmount + calculatedDiscount.abs()).clamp(-double.infinity, 0.0);
      }
      return -(subTotalAmount - calculatedDiscount).abs();
    }
    return (subTotalAmount - calculatedDiscount).clamp(0.0, double.infinity);
  }
  double get refundAmount => totalAmount.abs();
  double get changeAmount => (!isRefund && paidAmount > totalAmount) ? (paidAmount - totalAmount) : 0.0;
  bool get hasParkedCart => heldCarts.any((c) => !c.isExpired);
  List<HeldCart> get activeHeldCarts => heldCarts.where((c) => !c.isExpired).toList();

  BillingState copyWith({
    List<CartItem>? cartItems,
    List<HeldCart>? heldCarts,
    String? error,
    bool clearError = false,
    bool? isPrinting,
    bool? printSuccess,
    double? paidAmount,
    double? discountValue,
    bool? isDiscountPercentage,
    bool? isReturnMode,
    String? stockWarning,
    bool clearStockWarning = false,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      heldCarts: heldCarts ?? this.heldCarts,
      error: clearError ? null : (error ?? this.error),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      paidAmount: paidAmount ?? this.paidAmount,
      discountValue: discountValue ?? this.discountValue,
      isDiscountPercentage: isDiscountPercentage ?? this.isDiscountPercentage,
      isReturnMode: isReturnMode ?? this.isReturnMode,
      stockWarning: clearStockWarning ? null : (stockWarning ?? this.stockWarning),
    );
  }

  @override
  List<Object?> get props => [
        cartItems,
        heldCarts,
        error,
        isPrinting,
        printSuccess,
        paidAmount,
        discountValue,
        isDiscountPercentage,
        isReturnMode,
        stockWarning,
      ];
}
