import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/themes/app_theme.dart';
import '../view_models/language_view_model.dart';

/// First-launch language picker. Shows once before onboarding.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, required this.viewModel});

  final LanguageViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.language_rounded, size: 40, color: colors.primary),
                const SizedBox(height: 20),
                // Title shown in all three languages so any speaker recognises it.
                Text(
                  'Choose your language',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Выберите язык  ·  Tilingizni tanlang',
                  style: TextStyle(fontSize: 14, color: colors.mutedForeground),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView.separated(
                    itemCount: viewModel.locales.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final locale = viewModel.locales[i];
                      return _LanguageRow(
                        label: viewModel.nameOf(locale),
                        code: locale.languageCode,
                        selected: viewModel.selected == locale,
                        onTap: () => viewModel.select(locale),
                      );
                    },
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: viewModel.confirm.execute,
                    child: Text(context.l10n.continueButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Material(
      color: selected ? colors.primary.withValues(alpha: 0.10) : colors.muted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  code.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: colors.mutedForeground,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? colors.primary : colors.mutedForeground,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
