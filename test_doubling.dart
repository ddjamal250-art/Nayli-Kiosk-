
void main() {
  double cartonCapUI = 4.0;
  double packCapUI = 6.0;
  bool _hasPack = true;
  
  // Save logic
  double cartonMultiplier = _hasPack ? (cartonCapUI * packCapUI) : (cartonCapUI > 0 ? cartonCapUI : 24.0);
  double cartonUnitMultiplier = cartonMultiplier;
  double packUnitMultiplier = packCapUI;
  
  print("Saved DB -> carton: $cartonUnitMultiplier, pack: $packUnitMultiplier");
  
  // Load logic
  double loadedPackMultiplier = (_hasPack && packUnitMultiplier > 0) ? packUnitMultiplier : 1.0;
  double cartonUIVal = (_hasPack && loadedPackMultiplier > 1.0 && cartonUnitMultiplier >= loadedPackMultiplier)
          ? (cartonUnitMultiplier / loadedPackMultiplier)
          : cartonUnitMultiplier;
          
  print("Loaded UI -> cartonCapUI: $cartonUIVal");
}

