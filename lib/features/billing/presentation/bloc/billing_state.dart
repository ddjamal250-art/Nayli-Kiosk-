part of 'billing_bloc.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final List<CartItem> parkedCartItems;
  final String? error;
  final bool isPrinting;
  final bool printSuccess;
  final double paidAmount;

  const BillingState({
    this.cartItems = const [],
    this.parkedCartItems = const [],
    this.error,
    this.isPrinting = false,
    this.printSuccess = false,
    this.paidAmount = 0.0,
  });

  double get totalAmount => cartItems.fold(0, (sum, item) => sum + item.total);
  double get changeAmount => paidAmount > totalAmount ? (paidAmount - totalAmount) : 0.0;
  bool get hasParkedCart => parkedCartItems.isNotEmpty;

  BillingState copyWith({
    List<CartItem>? cartItems,
    List<CartItem>? parkedCartItems,
    String? error,
    bool clearError = false,
    bool? isPrinting,
    bool? printSuccess,
    double? paidAmount,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      parkedCartItems: parkedCartItems ?? this.parkedCartItems,
      error: clearError ? null : (error ?? this.error),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }

  @override
  List<Object?> get props => [
        cartItems,
        parkedCartItems,
        error,
        isPrinting,
        printSuccess,
        paidAmount,
      ];
}
