fix_tobacco = r'd:\repos\Nayli Market -custom-\lib\features\billing\presentation\widgets\kiosk_tobacco_modal.dart'
fix_hive = r'd:\repos\Nayli Market -custom-\lib\core\data\hive_database.dart'

# --- Fix kiosk_tobacco_modal.dart ---
with open(fix_tobacco, 'r', encoding='utf-8') as f:
    text = f.read()

old_block = """  // --- Tobacco calculations ---
  double get _singlePiecePrice {
    final p = widget.product;
    if (p.singlePiecePrice > 0) return p.singlePiecePrice;
    final pieces = p.piecesPerPack > 0 ? p.quantity: _packQty,
      customPrice: _isWholesale ? _));

    SoundService.playScanBeep();
    Navigator.pop(context);
    SnackbarHelper.showSuccess(context, '\u2705 $_packQty ${context.tr("pack")} "${p.name}" ' + (_isWholesale ? context.tr('wholesale_badge') : '') + ' ' + context.tr('added_to_cart'));
  }"""

new_block = """  // --- Tobacco calculations ---
  double get _singlePiecePrice {
    final p = widget.product;
    if (p.singlePiecePrice > 0) return p.singlePiecePrice;
    final pieces = p.piecesPerPack > 0 ? p.piecesPerPack : 20;
    if (_isWholesale && p.wholesalePackPrice > 0) return p.wholesalePackPrice / pieces;
    return p.price / pieces;
  }

  void _addPackToCart() {
    final p = widget.product;
    context.read<BillingBloc>().add(AddProductToCartEvent(
      p,
      unitLevel: 'pack',
      quantity: _packQty,
      customPrice: _isWholesale && p.wholesalePackPrice > 0 ? p.wholesalePackPrice : null,
    ));

    SoundService.playScanBeep();
    Navigator.pop(context);
    SnackbarHelper.showSuccess(context, '\u2705 $_packQty ${context.tr("pack")} "${p.name}" ' + (_isWholesale ? context.tr('wholesale_badge') : '') + ' ' + context.tr('added_to_cart'));
  }"""

text = text.replace(old_block, new_block)

old_carton = """    customPrice: _isWholesale ? _));

    SoundService.playScanBeep();
    Navigator.pop(context);
    SnackbarHelper.showSuccess(context, '\U0001f4e6 $_cartonQty ${context.tr("carton")} "${p.name}" ' + (_isWholesale ? context.tr('wholesale_badge') : '') + ' ' + context.tr('added_to_cart'));
  }"""

new_carton = """      customPrice: _isWholesale && p.wholesaleCartonPrice > 0 ? p.wholesaleCartonPrice : null,
    ));

    SoundService.playScanBeep();
    Navigator.pop(context);
    SnackbarHelper.showSuccess(context, '\U0001f4e6 $_cartonQty ${context.tr("carton")} "${p.name}" ' + (_isWholesale ? context.tr('wholesale_badge') : '') + ' ' + context.tr('added_to_cart'));
  }"""

text = text.replace(old_carton, new_carton)

with open(fix_tobacco, 'w', encoding='utf-8') as f:
    f.write(text)

print("Done fixing kiosk_tobacco_modal.dart")
