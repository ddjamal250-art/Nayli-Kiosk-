import sys

file_path = 'd:/repos/Nayli Market -custom-/lib/features/product/presentation/pages/stock_in_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Init state
init_str = '''    _cartonCountController.addListener(_onCartonInputsChanged);
    _unitsPerCartonController.addListener(_onCartonInputsChanged);
    _cartonCostController.addListener(_onCartonCostChanged);'''
new_init_str = init_str + '''
    _packsPerCartonController.addListener(_onCartonInputsChanged);
    _unitsPerPackController.addListener(_onCartonInputsChanged);
    _packCostController.addListener(_onPackCostChanged);
'''
content = content.replace(init_str, new_init_str)

# 2. Dispose
disp_str = '''    _cartonCountController.dispose();
    _unitsPerCartonController.dispose();
    _cartonCostController.dispose();'''
new_disp_str = disp_str + '''
    _packsPerCartonController.dispose();
    _unitsPerPackController.dispose();
    _packCostController.dispose();
    _packPriceController.dispose();
'''
content = content.replace(disp_str, new_disp_str)

# 3. Calculation methods
calc_str = '''  void _onCartonInputsChanged() {
    if (_unitMode != ArrivageUnitMode.cartons || _isUpdatingFromCalculation) return;
    final cartons = int.tryParse(_cartonCountController.text.trim()) ?? 0;
    final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
    final totalUnits = cartons * perCarton;
    _qtyController.text = totalUnits.toString();

    final cartonCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
    if (perCarton > 0 && cartonCost > 0) {
      final unitCost = cartonCost / perCarton;
      _isUpdatingFromCalculation = true;
      _costPriceController.text = unitCost.toStringAsFixed(2);
      _isUpdatingFromCalculation = false;
    }
    setState(() {});
  }

  void _onCartonCostChanged() {
    if (_unitMode != ArrivageUnitMode.cartons || _isUpdatingFromCalculation) return;
    final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
    final cartonCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
    if (perCarton > 0 && cartonCost > 0) {
      final unitCost = cartonCost / perCarton;
      _isUpdatingFromCalculation = true;
      _costPriceController.text = unitCost.toStringAsFixed(2);
      _isUpdatingFromCalculation = false;
    }
    setState(() {});
  }'''

new_calc_str = '''  void _onCartonInputsChanged() {
    if (_unitMode != ArrivageUnitMode.cartons || _isUpdatingFromCalculation) return;
    final cartons = int.tryParse(_cartonCountController.text.trim()) ?? 0;
    
    int totalUnits = 0;
    if (_hasMiddleTier) {
      final packs = int.tryParse(_packsPerCartonController.text.trim()) ?? 0;
      final unitsPerPack = int.tryParse(_unitsPerPackController.text.trim()) ?? 0;
      totalUnits = cartons * packs * unitsPerPack;
    } else {
      final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
      totalUnits = cartons * perCarton;
    }
    
    _qtyController.text = totalUnits.toString();
    _cascadeCostCalculations();
    setState(() {});
  }

  void _onCartonCostChanged() {
    if (_unitMode != ArrivageUnitMode.cartons || _isUpdatingFromCalculation) return;
    _cascadeCostCalculations();
    setState(() {});
  }

  void _onPackCostChanged() {
    if (_unitMode != ArrivageUnitMode.cartons || !_hasMiddleTier || _isUpdatingFromCalculation) return;
    final packCost = double.tryParse(_packCostController.text.trim()) ?? 0.0;
    final unitsPerPack = int.tryParse(_unitsPerPackController.text.trim()) ?? 0;
    if (unitsPerPack > 0 && packCost > 0) {
      final unitCost = packCost / unitsPerPack;
      _isUpdatingFromCalculation = true;
      _costPriceController.text = unitCost.toStringAsFixed(2);
      _isUpdatingFromCalculation = false;
    }
    setState(() {});
  }

  void _cascadeCostCalculations() {
    final cartonCost = double.tryParse(_cartonCostController.text.trim()) ?? 0.0;
    if (cartonCost <= 0) return;

    _isUpdatingFromCalculation = true;
    if (_hasMiddleTier) {
      final packs = int.tryParse(_packsPerCartonController.text.trim()) ?? 0;
      if (packs > 0) {
        final packCost = cartonCost / packs;
        _packCostController.text = packCost.toStringAsFixed(2);
        
        final unitsPerPack = int.tryParse(_unitsPerPackController.text.trim()) ?? 0;
        if (unitsPerPack > 0) {
          final unitCost = packCost / unitsPerPack;
          _costPriceController.text = unitCost.toStringAsFixed(2);
        }
      }
    } else {
      final perCarton = int.tryParse(_unitsPerCartonController.text.trim()) ?? 0;
      if (perCarton > 0) {
        final unitCost = cartonCost / perCarton;
        _costPriceController.text = unitCost.toStringAsFixed(2);
      }
    }
    _isUpdatingFromCalculation = false;
  }'''

content = content.replace(calc_str, new_calc_str)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Phase 1 applied')
