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
  });

  double get subTotalAmount => cartItems.fold(0, (sum, item) => sum + item.total);
  double get calculatedDiscount => isDiscountPercentage ? (subTotalAmount * (discountValue / 100.0)) : discountValue;
  double get totalAmount => (subTotalAmount - calculatedDiscount).clamp(0.0, double.infinity);
  double get changeAmount => paidAmount > totalAmount ? (paidAmount - totalAmount) : 0.0;
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
      ];
}
