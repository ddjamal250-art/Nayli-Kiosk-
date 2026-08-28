part of 'billing_bloc.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final List<HeldCart> heldCarts;
  final String? error;
  final bool isPrinting;
  final bool printSuccess;
  final double paidAmount;

  const BillingState({
    this.cartItems = const [],
    this.heldCarts = const [],
    this.error,
    this.isPrinting = false,
    this.printSuccess = false,
    this.paidAmount = 0.0,
  });

  double get totalAmount => cartItems.fold(0, (sum, item) => sum + item.total);
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
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      heldCarts: heldCarts ?? this.heldCarts,
      error: clearError ? null : (error ?? this.error),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      paidAmount: paidAmount ?? this.paidAmount,
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
      ];
}
