part of 'billing_bloc.dart';

abstract class BillingEvent extends Equatable {
  const BillingEvent();
  @override
  List<Object> get props => [];
}

class ScanBarcodeEvent extends BillingEvent {
  final String barcode;
  const ScanBarcodeEvent(this.barcode);
  @override
  List<Object> get props => [barcode];
}

class AddProductToCartEvent extends BillingEvent {
  final Product product;
  final String unitLevel; // 'pack', 'piece', 'carton'
  final int quantity;
  final double? customPrice;

  const AddProductToCartEvent(
    this.product, {
    this.unitLevel = 'pack',
    this.quantity = 1,
    this.customPrice,
  });

  @override
  List<Object> get props => [product, unitLevel, quantity, customPrice ?? 0.0];
}

class SwitchCartItemUnitEvent extends BillingEvent {
  final String cartKey;
  final String targetUnit; // 'piece', 'pack', 'carton'
  final int? newQuantity;

  const SwitchCartItemUnitEvent({
    required this.cartKey,
    required this.targetUnit,
    this.newQuantity,
  });

  @override
  List<Object> get props => [cartKey, targetUnit, newQuantity ?? 0];
}

class AddCustomItemEvent extends BillingEvent {
  final String name;
  final double price;
  final int quantity;
  final double costPrice;
  final String? barcode;

  const AddCustomItemEvent({
    required this.name,
    required this.price,
    this.quantity = 1,
    this.costPrice = 0.0,
    this.barcode,
  });

  @override
  List<Object> get props => [name, price, quantity, costPrice, barcode ?? ''];
}

class RemoveProductFromCartEvent extends BillingEvent {
  final String productId;
  const RemoveProductFromCartEvent(this.productId);
  @override
  List<Object> get props => [productId];
}

class UpdateQuantityEvent extends BillingEvent {
  final String productId;
  final int quantity;
  const UpdateQuantityEvent(this.productId, this.quantity);
  @override
  List<Object> get props => [productId, quantity];
}

class ClearCartEvent extends BillingEvent {}

class ParkCurrentCartEvent extends BillingEvent {
  final String? label;
  const ParkCurrentCartEvent({this.label});
  @override
  List<Object> get props => [label ?? ''];
}

class ResumeHeldCartEvent extends BillingEvent {
  final String heldCartId;
  const ResumeHeldCartEvent(this.heldCartId);
  @override
  List<Object> get props => [heldCartId];
}

class DeleteHeldCartEvent extends BillingEvent {
  final String heldCartId;
  const DeleteHeldCartEvent(this.heldCartId);
  @override
  List<Object> get props => [heldCartId];
}

class CleanExpiredHeldCartsEvent extends BillingEvent {}

class ResumeParkedCartEvent extends BillingEvent {}

class SetPaidAmountEvent extends BillingEvent {
  final double amount;
  const SetPaidAmountEvent(this.amount);
  @override
  List<Object> get props => [amount];
}

class PrintReceiptEvent extends BillingEvent {
  final String shopName;
  final String address1;
  final String address2;
  final String phone;
  final String footer;
  final String? customerName;
  final bool isCredit;
  final String paymentMethod;
  final double paidAmount;
  final double previousDebt;
  final double newDebtTotal;
  final bool skipPhysicalPrint;
  final String? specificPrinterName;

  const PrintReceiptEvent({
    required this.shopName,
    required this.address1,
    required this.address2,
    required this.phone,
    required this.footer,
    this.customerName,
    this.isCredit = false,
    this.paymentMethod = 'Espèces',
    this.paidAmount = 0.0,
    this.previousDebt = 0.0,
    this.newDebtTotal = 0.0,
    this.skipPhysicalPrint = false,
    this.specificPrinterName,
  });

  @override
  List<Object> get props => [
        shopName,
        address1,
        address2,
        phone,
        footer,
        customerName ?? '',
        isCredit,
        paymentMethod,
        paidAmount,
        previousDebt,
        newDebtTotal,
        skipPhysicalPrint,
        specificPrinterName ?? '',
      ];
}

class ApplyDiscountEvent extends BillingEvent {
  final double value;
  final bool isPercentage;

  const ApplyDiscountEvent({required this.value, required this.isPercentage});

  @override
  List<Object> get props => [value, isPercentage];
}

class RemoveDiscountEvent extends BillingEvent {}

class ToggleReturnModeEvent extends BillingEvent {}

