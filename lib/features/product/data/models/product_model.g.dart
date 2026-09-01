// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductModelAdapter extends TypeAdapter<ProductModel> {
  @override
  final int typeId = 0;

  @override
  ProductModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductModel(
      id: fields[0] as String? ?? '',
      name: fields[1] as String? ?? '',
      barcode: fields[2] as String? ?? '',
      price: (fields[3] as num?)?.toDouble() ?? 0.0,
      stock: (fields[4] as num?)?.toInt() ?? 0,
      costPrice: (fields[5] as num?)?.toDouble() ?? 0.0,
      category: fields[6] as String? ?? 'عام',
      isWeighted: fields[7] as bool? ?? false,
      wholesalePrice: (fields[8] as num?)?.toDouble() ?? 0.0,
      expiryDate: fields[9] as String?,
      packBarcode: fields[10] as String?,
      packMultiplier: (fields[11] as num?)?.toInt() ?? 1,
      packPrice: (fields[12] as num?)?.toDouble() ?? 0.0,
      packName: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.barcode)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.stock)
      ..writeByte(5)
      ..write(obj.costPrice)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.isWeighted)
      ..writeByte(8)
      ..write(obj.wholesalePrice)
      ..writeByte(9)
      ..write(obj.expiryDate)
      ..writeByte(10)
      ..write(obj.packBarcode)
      ..writeByte(11)
      ..write(obj.packMultiplier)
      ..writeByte(12)
      ..write(obj.packPrice)
      ..writeByte(13)
      ..write(obj.packName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
