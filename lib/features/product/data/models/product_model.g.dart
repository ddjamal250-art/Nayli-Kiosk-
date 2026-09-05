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
      imageUrl: fields[14] as String?,
      isTobacco: fields[15] as bool? ?? false,
      piecesPerPack: (fields[16] as num?)?.toInt() ?? 20,
      packsPerCarton: (fields[17] as num?)?.toInt() ?? 10,
      singlePiecePrice: (fields[18] as num?)?.toDouble() ?? 0.0,
      cartonPrice: (fields[19] as num?)?.toDouble() ?? 0.0,
      wholesaleCartonPrice: (fields[20] as num?)?.toDouble() ?? 0.0,
      wholesalePackPrice: (fields[21] as num?)?.toDouble() ?? 0.0,
      cartonCostPrice: (fields[22] as num?)?.toDouble() ?? 0.0,
      unitType: fields[23] as String? ?? 'unit',
    );
  }

  @override
  void write(BinaryWriter writer, ProductModel obj) {
    writer
      ..writeByte(24)
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
      ..write(obj.packName)
      ..writeByte(14)
      ..write(obj.imageUrl)
      ..writeByte(15)
      ..write(obj.isTobacco)
      ..writeByte(16)
      ..write(obj.piecesPerPack)
      ..writeByte(17)
      ..write(obj.packsPerCarton)
      ..writeByte(18)
      ..write(obj.singlePiecePrice)
      ..writeByte(19)
      ..write(obj.cartonPrice)
      ..writeByte(20)
      ..write(obj.wholesaleCartonPrice)
      ..writeByte(21)
      ..write(obj.wholesalePackPrice)
      ..writeByte(22)
      ..write(obj.cartonCostPrice)
      ..writeByte(23)
      ..write(obj.unitType);
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
