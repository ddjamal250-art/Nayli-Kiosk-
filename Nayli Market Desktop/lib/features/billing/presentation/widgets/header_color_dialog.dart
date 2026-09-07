import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/header_branding_cubit.dart';
import '../../../../core/localization/app_localizations.dart';

class HeaderColorDialog extends StatelessWidget {
  const HeaderColorDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const HeaderColorDialog(),
    );
  }

  static const List<Color> customColorPalette = [
    Color(0xFF06325C), // Nayli Blue
    Color(0xFF0A2540), // Deep Dark Blue
    Color(0xFF0F172A), // Slate 900
    Color(0xFF000000), // Pure Black AMOLED
    Color(0xFF065F46), // Emerald Forest
    Color(0xFF047857), // Classic Green
    Color(0xFF0D9488), // Teal
    Color(0xFF1E3A8A), // Blue 900
    Color(0xFF312E81), // Indigo 900
    Color(0xFF4F46E5), // Indigo 600
    Color(0xFF6B21A8), // Purple 800
    Color(0xFF881337), // Rose/Ruby 900
    Color(0xFF991B1B), // Red 800
    Color(0xFF78350F), // Amber/Brown
    Color(0xFF334155), // Slate Gray
    Color(0xFFFFFFFF), // Pure White
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<HeaderBrandingCubit, HeaderBrandingState>(
      builder: (context, state) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: state.accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.palette_rounded, color: state.accentColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('custom_header_title'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      context.tr('custom_header_subtitle'),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Live Header Preview Banner
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: state.headerColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: state.isDarkHeader ? Colors.white12 : Colors.black12,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: state.headerColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: state.logoContainerColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.asset('assets/images/app_logo.png', fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Nayli Kiosk POS 🇩🇿',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: state.isDarkHeader ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: state.accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: state.accentColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            context.tr('preview_badge'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: state.isDarkHeader ? Colors.white : state.accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Presets Section
                  Text(
                    context.tr('color_presets_title'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: HeaderBrandingCubit.presets.map((p) {
                      final isSelected = state.presetId == p.id;
                      final locale = Localizations.localeOf(context).languageCode;
                      final name = locale == 'ar' ? p.nameAr : (locale == 'fr' ? p.nameFr : p.nameEn);

                      return InkWell(
                        onTap: () {
                          context.read<HeaderBrandingCubit>().selectPreset(p.id);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? p.accentColor.withOpacity(0.15)
                                : (isDark ? const Color(0xFF1E293B) : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? p.accentColor : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: p.headerColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.check_circle_rounded, color: p.accentColor, size: 16),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Custom Color Palette
                  Text(
                    context.tr('custom_palette_title'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: customColorPalette.map((col) {
                      final isSelected = state.headerColor.value == col.value && state.presetId == 'custom';
                      return InkWell(
                        onTap: () {
                          context.read<HeaderBrandingCubit>().setCustomColors(
                            headerColor: col,
                            accentColor: col == const Color(0xFFFFFFFF)
                                ? const Color(0xFF06325C)
                                : (col == const Color(0xFF000000) ? const Color(0xFF38BDF8) : const Color(0xFFFF6600)),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.amber : (isDark ? Colors.white24 : Colors.black26),
                              width: isSelected ? 3 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: col.withOpacity(0.35),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: col.computeLuminance() < 0.5 ? Colors.white : Colors.black,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: state.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(context.tr('confirm_btn')),
            ),
          ],
        );
      },
    );
  }
}
