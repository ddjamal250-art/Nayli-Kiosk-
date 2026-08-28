import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../../../billing/presentation/bloc/billing_bloc.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../../product/domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/input_label.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/data/master_catalog_seed.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/data/quick_item_model.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/language_cubit.dart';
import '../../domain/entities/cart_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );

  bool _isCameraOn = true;
  bool _isFlashOn = false;
  bool _isScanningPaused = false;
  final Map<String, DateTime> _lastScanTimes = {};

  List<QuickItem> _quickItems = [];

  @override
  void initState() {
    super.initState();
    _loadQuickItems();
  }

  void _loadQuickItems() {
    final box = HiveDatabase.quickItemsBox;
    if (box.isEmpty) {
      final defaults = QuickItem.defaultItems;
      for (var item in defaults) {
        box.put(item.id, item.toMap());
      }
      setState(() {
        _quickItems = List.from(defaults);
      });
    } else {
      final List<QuickItem> loaded = [];
      for (var key in box.keys) {
        final data = box.get(key);
        if (data != null && data is Map) {
          loaded.add(QuickItem.fromMap(data));
        }
      }
      setState(() {
        _quickItems = loaded;
      });
    }
  }

  Future<void> _saveQuickItem(QuickItem item) async {
    await HiveDatabase.quickItemsBox.put(item.id, item.toMap());
    _loadQuickItems();
  }

  Future<void> _deleteQuickItem(String id) async {
    await HiveDatabase.quickItemsBox.delete(id);
    _loadQuickItems();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isScanningPaused || !_isCameraOn) return;

    final List<Barcode> barcodes = capture.barcodes;
    final now = DateTime.now();

    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        final rawValue = barcode.rawValue!.trim();

        if (_lastScanTimes.containsKey(rawValue)) {
          final lastScan = _lastScanTimes[rawValue]!;
          if (now.difference(lastScan).inMilliseconds < 1200) {
            continue;
          }
        }

        _lastScanTimes[rawValue] = now;

        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          Vibration.vibrate(duration: 40);
        }

        if (mounted) {
          context.read<BillingBloc>().add(ScanBarcodeEvent(rawValue));
        }
        break;
      }
    }
  }

  void _handleQuickAddProduct(String barcode) async {
    setState(() => _isScanningPaused = true);

    final masterItem = MasterCatalogSeed.lookup(barcode);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: masterItem?.name ?? '');
    final priceController = TextEditingController(
      text: masterItem != null && masterItem.defaultPrice > 0
          ? masterItem.defaultPrice.toStringAsFixed(2)
          : '',
    );
    final qtyController = TextEditingController(text: '10');

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.tr('quick_add_title'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: masterItem != null
                      ? Colors.green.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(masterItem != null ? Icons.auto_awesome : Icons.qr_code,
                        color: masterItem != null ? Colors.green[800] : AppTheme.primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        masterItem != null
                            ? context.tr('master_recognized')
                            : '${context.tr('barcode_label')}: $barcode',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: masterItem != null ? Colors.green[900] : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              InputLabel(text: context.tr('product_name')),
              TextFormField(
                controller: nameController,
                validator: AppValidators.required(context.tr('required')),
                decoration: InputDecoration(hintText: context.tr('product_name')),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InputLabel(text: context.tr('selling_price')),
                        TextFormField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: AppValidators.price,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixText: '${AppConstants.currencySymbol} ',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InputLabel(text: context.tr('initial_stock')),
                        TextFormField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '10'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final price = double.parse(priceController.text.trim());
                    final stock = int.tryParse(qtyController.text.trim()) ?? 10;
                    final newProduct = Product(
                      id: const Uuid().v4(),
                      name: nameController.text.trim(),
                      barcode: barcode,
                      price: price,
                      stock: stock,
                    );

                    context.read<ProductBloc>().add(AddProduct(newProduct));
                    context.read<BillingBloc>().add(AddProductToCartEvent(newProduct));

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('saved_product_msg')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: Icons.check_circle_outline,
                label: context.tr('save_and_add_cart'),
              )
            ],
          ),
        ),
      ),
    );
    } finally {
      if (mounted) {
        setState(() {
          _isScanningPaused = false;
          _lastScanTimes.clear();
        });
      }
    }
  }

  void _addQuickItem(QuickItem item) {
    final quickProduct = Product(
      id: 'quick_${item.id}',
      name: item.name,
      barcode: '',
      price: item.price,
      stock: 999,
    );
    context.read<BillingBloc>().add(AddProductToCartEvent(quickProduct));
    Vibration.vibrate(duration: 30);
  }

  void _showEditQuickItemModal(QuickItem item) {
    final priceController = TextEditingController(text: item.price.toStringAsFixed(0));
    final nameController = TextEditingController(text: item.name);
    final iconController = TextEditingController(text: item.icon);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Text(item.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${context.tr('edit_quick_item')}: ${item.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: priceController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.tr('quick_item_price'),
                prefixText: '${AppConstants.currencySymbol} ',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: context.tr('quick_item_name'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: iconController,
              decoration: InputDecoration(
                labelText: context.tr('quick_item_icon'),
                hintText: '🥖 🥚 🥛 🧃 🍬',
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: context.tr('delete'),
            onPressed: () async {
              await _deleteQuickItem(item.id);
              if (mounted) Navigator.pop(ctx);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final newPrice = double.tryParse(priceController.text.trim()) ?? item.price;
              final newName = nameController.text.trim().isNotEmpty ? nameController.text.trim() : item.name;
              final newIcon = iconController.text.trim().isNotEmpty ? iconController.text.trim() : item.icon;

              final updated = item.copyWith(
                name: newName,
                price: newPrice,
                icon: newIcon,
              );

              await _saveQuickItem(updated);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('price_updated_msg')),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            child: Text(context.tr('save'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddQuickItemModal() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final iconController = TextEditingController(text: '🛍️');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.tr('add_quick_item'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: context.tr('quick_item_name'),
                hintText: 'e.g. قهوة سريعة / حليب شكارة',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.tr('quick_item_price'),
                prefixText: '${AppConstants.currencySymbol} ',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: iconController,
              decoration: InputDecoration(
                labelText: context.tr('quick_item_icon'),
                hintText: 'e.g. 🥖 🥚 ☕ 🧀 🥤',
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                final icon = iconController.text.trim().isNotEmpty ? iconController.text.trim() : '🛍️';

                if (name.isNotEmpty && price > 0) {
                  final newItem = QuickItem(
                    id: 'q_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    price: price,
                    icon: icon,
                  );

                  await _saveQuickItem(newItem);
                  if (mounted) Navigator.pop(ctx);
                }
              },
              icon: Icons.add,
              label: context.tr('save'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<BillingBloc, BillingState>(
        listenWhen: (previous, current) =>
            previous.error != current.error && current.error != null,
        listener: (context, state) {
          if (state.error != null && state.error!.startsWith('Product not found: ')) {
            final barcode = state.error!.replaceFirst('Product not found: ', '').trim();
            _handleQuickAddProduct(barcode);
          } else if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Stack(
          children: [
            // SCANNER VIEW
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.38,
              child: _buildScannerSection(),
            ),

            // BOTTOM PANEL
            Positioned(
              top: (MediaQuery.of(context).size.height * 0.38) - 24,
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomPanel(),
            ),
          ],
        ),
      ),
      bottomSheet:
          BlocBuilder<BillingBloc, BillingState>(builder: (context, state) {
        return PrimaryButton(
          onPressed: state.cartItems.isEmpty
              ? null
              : () async {
                  setState(() => _isScanningPaused = true);
                  await context.push('/checkout');
                  if (mounted) {
                    setState(() {
                      _isScanningPaused = false;
                      _lastScanTimes.clear();
                    });
                  }
                },
          icon: Icons.payment,
          label: '${context.tr('review_order')} (${state.cartItems.length})',
        );
      }),
    );
  }

  Widget _buildScannerSection() {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          if (!_isCameraOn) _buildCameraOffState(),

          // Overlay Actions
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: Column(
              children: [
                _buildOverlayButton(
                  icon: Icons.settings,
                  onPressed: () async {
                    setState(() => _isScanningPaused = true);
                    await context.push('/settings');
                    if (mounted) {
                      setState(() {
                        _isScanningPaused = false;
                        _lastScanTimes.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildOverlayButton(
                  icon: Icons.menu_book_rounded,
                  onPressed: () async {
                    setState(() => _isScanningPaused = true);
                    await context.push('/customers');
                    if (mounted) {
                      setState(() {
                        _isScanningPaused = false;
                        _lastScanTimes.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildOverlayButton(
                  icon: Icons.archive_outlined,
                  onPressed: () async {
                    setState(() => _isScanningPaused = true);
                    await context.push('/products/stock-in');
                    if (mounted) {
                      setState(() {
                        _isScanningPaused = false;
                        _lastScanTimes.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (_isCameraOn)
                  _buildOverlayButton(
                    icon: _isFlashOn ? Icons.flashlight_off : Icons.flashlight_on,
                    onPressed: () {
                      setState(() => _isFlashOn = !_isFlashOn);
                      _scannerController.toggleTorch();
                    },
                  ),
                if (_isCameraOn) const SizedBox(height: 12),
                _buildOverlayButton(
                  icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  onPressed: () {
                    setState(() {
                      _isCameraOn = !_isCameraOn;
                    });
                    if (_isCameraOn) {
                      _scannerController.start();
                    } else {
                      _scannerController.stop();
                    }
                  },
                ),
              ],
            ),
          ),

          // Central Frame
          if (_isCameraOn)
            Center(
              child: Container(
                width: 240,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white38, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraOffState() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(context.tr('camera_off'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            icon: const Icon(Icons.videocam),
            label: Text(context.tr('turn_on_camera')),
            onPressed: () {
              setState(() => _isCameraOn = true);
              _scannerController.start();
            },
          )
        ],
      ),
    );
  }

  Widget _buildOverlayButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, -5))],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),

          // Header with Total and Park Cart
          BlocBuilder<BillingBloc, BillingState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('cart'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${state.cartItems.length} ${context.tr('items_count')}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Park Cart Button
                        if (state.cartItems.isNotEmpty)
                          InkWell(
                            onTap: () {
                              context.read<BillingBloc>().add(ParkCurrentCartEvent());
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.tr('parked_cart_msg')), duration: const Duration(seconds: 1)),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.pause_circle_outline, size: 14, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(context.tr('park_cart'),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                                ],
                              ),
                            ),
                          ),
                        if (state.hasParkedCart) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              context.read<BillingBloc>().add(ResumeParkedCartEvent());
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.tr('resumed_cart_msg')), duration: const Duration(seconds: 1)),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.play_circle_outline, size: 14, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text('${context.tr('resume_cart')} (${state.parkedCartItems.length})',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                                ],
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(context.tr('total_price'),
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text(
                          '${state.totalAmount.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // Quick Items Bar Pro (Interactive with Long-Press & (+) Add)
          Container(
            height: 42,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickItems.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                if (index == _quickItems.length) {
                  return ActionChip(
                    avatar: const Icon(Icons.add, size: 16, color: AppTheme.primaryColor),
                    label: Text(context.tr('add_quick_item'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                    side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: _showAddQuickItemModal,
                  );
                }

                final q = _quickItems[index];
                return GestureDetector(
                  onTap: () => _addQuickItem(q),
                  onLongPress: () => _showEditQuickItemModal(q),
                  child: Chip(
                    avatar: Text(q.icon, style: const TextStyle(fontSize: 14)),
                    label: Text(
                      '${q.name} (${q.price.toStringAsFixed(0)} ${AppConstants.currencySymbol})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Cart Items List
          Expanded(
            child: BlocBuilder<BillingBloc, BillingState>(
              builder: (context, state) {
                if (state.cartItems.isEmpty) {
                  return _buildEmptyCart();
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 90),
                  itemCount: state.cartItems.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = state.cartItems[index];
                    return _buildCartItemCard(context, item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 36, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(context.tr('cart_empty'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(context.tr('cart_empty_hint'),
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, CartItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${item.product.price.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (item.product.stock <= 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(context.tr('stock_zero_warning'),
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
                      )
                    ]
                  ],
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _circularIconButton(
                  icon: Icons.remove,
                  onPressed: () {
                    if (item.quantity > 1) {
                      context.read<BillingBloc>().add(UpdateQuantityEvent(item.product.id, item.quantity - 1));
                    } else {
                      context.read<BillingBloc>().add(RemoveProductFromCartEvent(item.product.id));
                    }
                  },
                ),
                SizedBox(
                  width: 28,
                  child: Text('${item.quantity}',
                      textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                _circularIconButton(
                  icon: Icons.add,
                  onPressed: () {
                    context.read<BillingBloc>().add(UpdateQuantityEvent(item.product.id, item.quantity + 1));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circularIconButton({required IconData icon, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, size: 16, color: Colors.grey[700]),
      ),
    );
  }
}

