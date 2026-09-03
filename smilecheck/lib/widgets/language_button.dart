import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/locale_controller.dart';
import '../l10n/app_localizations.dart';

/// Language control for the camera chrome.
///
/// The button shows the active language as a two-letter tag rather than a globe
/// alone, so the current choice is readable without opening anything.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.size = 46});

  final double size;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LocaleController>();
    final l = L.of(context);

    return Tooltip(
      message: l.languageTooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.42),
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _pick(context, controller),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Text(
                controller.locale.languageCode.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    LocaleController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => LanguageSheet(controller: controller),
    );
  }
}

/// The picker itself. Split out so it can be shown from anywhere and tested on
/// its own.
class LanguageSheet extends StatelessWidget {
  const LanguageSheet({super.key, required this.controller});

  final LocaleController controller;

  /// Each language is named in its own tongue, which is the one thing a user
  /// who cannot read the current UI language will still recognise.
  static const Map<String, String> _endonyms = <String, String>{
    'en': 'English',
    'he': 'עברית',
  };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: AppMetrics.pill,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.translate_rounded,
                  size: 20,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 10),
                Text(l.languageTitle,
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            for (final locale in LocaleController.supported)
              _LanguageTile(
                label: _endonyms[locale.languageCode] ?? locale.languageCode,
                selected: locale.languageCode ==
                    controller.locale.languageCode,
                onTap: () {
                  controller.setLocale(locale);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.14)
            : AppColors.surfaceRaised,
        borderRadius: AppMetrics.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.accent
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: AppColors.accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
