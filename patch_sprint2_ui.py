import sys

file_path = 'd:/repos/Nayli Market -custom-/lib/features/product/presentation/pages/stock_in_page.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_ui = '''                  if (_unitMode == ArrivageUnitMode.cartons) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cartonCountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '??? ????????', suffixText: '??????', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _unitsPerCartonController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '??? ???????? (???)', suffixText: '???/??????', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cartonCostController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '??? ???? ???????? ???????', suffixText: 'DA/??????', border: OutlineInputBorder()),
                    ),
                  ] else if (_unitMode == ArrivageUnitMode.coffeeMachine) ...['''

new_ui = '''                  if (_unitMode == ArrivageUnitMode.cartons) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('????? ???????? ??? ??? ??????', style: TextStyle(fontWeight: FontWeight.bold)),
                        Switch(
                          value: _hasMiddleTier,
                          onChanged: (val) {
                            setState(() {
                              _hasMiddleTier = val;
                              _onCartonInputsChanged();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cartonCountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '??? ????????', suffixText: '??????', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _hasMiddleTier ? _packsPerCartonController : _unitsPerCartonController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: _hasMiddleTier ? '??? ???????? (????)' : '??? ???????? (???)',
                              suffixText: _hasMiddleTier ? '????' : '???',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cartonCostController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '????? ????????', suffixText: 'DA', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _cartonsPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '??? ??? ????????', suffixText: 'DA', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    if (_hasMiddleTier) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('?????? ?????? (??????? ??????)', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _unitsPerPackController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: '??? ?????? (???)', suffixText: '???/????', border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _packCostController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: '????? ??????', suffixText: 'DA', border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _packPriceController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: '??? ??? ??????', suffixText: 'DA', border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else if (_unitMode == ArrivageUnitMode.coffeeMachine) ...['''

content = content.replace(old_ui, new_ui)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('UI patch applied')
