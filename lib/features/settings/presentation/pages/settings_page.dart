import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:app_settings/app_settings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/language_cubit.dart';

import '../bloc/printer_bloc.dart';
import '../bloc/printer_event.dart';
import '../bloc/printer_state.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('settings'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile / Store Header
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              child: BlocBuilder<ShopBloc, ShopState>(
                builder: (context, state) {
                  String shopName = AppConstants.defaultShopName;
                  String initials = 'MS';
                  if (state is ShopLoaded && state.shop.name.isNotEmpty) {
                    shopName = state.shop.name;
                    final parts = shopName.split(' ');
                    initials = parts
                        .take(2)
                        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
                        .join('');
                    if (initials.isEmpty) initials = 'S';
                  }

                  return Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                              blurRadius: 12,
                              spreadRadius: 4,
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        shopName.toUpperCase(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Language Selector Section
            _buildSectionHeader(context, context.tr('language')),
            BlocBuilder<LanguageCubit, Locale>(
              builder: (context, currentLocale) {
                return _buildListGroup(
                  children: [
                    _buildLanguageItem(
                      context: context,
                      title: 'العربية (Arabic)',
                      flag: '🇩🇿',
                      code: 'ar',
                      isSelected: currentLocale.languageCode == 'ar',
                    ),
                    _buildDivider(),
                    _buildLanguageItem(
                      context: context,
                      title: 'Français (French)',
                      flag: '🇫🇷',
                      code: 'fr',
                      isSelected: currentLocale.languageCode == 'fr',
                    ),
                    _buildDivider(),
                    _buildLanguageItem(
                      context: context,
                      title: 'English (English)',
                      flag: '🇬🇧',
                      code: 'en',
                      isSelected: currentLocale.languageCode == 'en',
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Management Section
            _buildSectionHeader(context, context.tr('products_management')),
            _buildListGroup(
              children: [
                _buildListItem(
                  icon: Icons.qr_code_scanner,
                  title: context.tr('products_management'),
                  subtitle: context.tr('edit'),
                  onTap: () => context.push('/products'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.archive_outlined,
                  title: context.tr('stock_in'),
                  subtitle: context.tr('stock_in_hint'),
                  onTap: () => context.push('/products/stock-in'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.bar_chart_rounded,
                  title: context.tr('daily_report'),
                  subtitle: context.tr('print_z_report'),
                  onTap: () => context.push('/reports'),
                ),
                _buildDivider(),
                _buildListItem(
                  icon: Icons.storefront,
                  title: context.tr('shop_details'),
                  subtitle: context.tr('shop_details'),
                  onTap: () => context.push('/shop'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Hardware Section
            _buildSectionHeader(context, context.tr('hardware')),
            BlocConsumer<PrinterBloc, PrinterState>(
              listener: (context, state) {
                if (state.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
                  );
                } else if (state.status == PrinterStatus.connected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('connected')), backgroundColor: Colors.green),
                  );
                }
              },
              builder: (context, state) {
                return _buildListGroup(
                  children: [
                    _buildListItem(
                      icon: Icons.print,
                      title: context.tr('print_device'),
                      subtitleWidget: Row(
                        children: [
                          Text(
                            state.connectedMac != null
                                ? (state.connectedName ?? context.tr('connected'))
                                : context.tr('disconnected'),
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                          if (state.connectedMac != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal[100],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.teal[200]!),
                              ),
                              child: Text(
                                context.tr('connected'),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal[700],
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                      trailingWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.status == PrinterStatus.scanning ||
                              state.status == PrinterStatus.connecting)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () => context.read<PrinterBloc>().add(RefreshPrinterEvent()),
                              color: AppTheme.primaryColor,
                            ),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () {
                              AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
                            },
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageItem({
    required BuildContext context,
    required String title,
    required String flag,
    required String code,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        context.read<LanguageCubit>().setLanguage(code);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryColor : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 20)
            else
              Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Align(
        alignment: Directionality.of(context) == TextDirection.rtl ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildListGroup({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    VoidCallback? onTap,
    Widget? trailingWidget,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (subtitleWidget != null) ...[
                    const SizedBox(height: 2),
                    subtitleWidget,
                  ] else if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ],
              ),
            ),
            if (trailingWidget != null)
              trailingWidget
            else if (onTap != null)
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF2F2F7));
  }
}
