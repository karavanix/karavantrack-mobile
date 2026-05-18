import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';

/// First-launch language picker. Shows once before onboarding.
class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  late String _selected = widget.store.locale;

  Future<void> _confirm() async {
    await widget.store.setLocale(_selected);
    await widget.store.markLanguageSeen();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);

    return Scaffold(
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
                style: TextStyle(
                  fontSize: 14,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: AppLocalizations.supportedLocales.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final code = AppLocalizations.supportedLocales[i];
                    final name = AppLocalizations.languageNames[code]!;
                    return _LanguageRow(
                      label: name,
                      code: code,
                      selected: _selected == code,
                      onTap: () => setState(() => _selected = code),
                    );
                  },
                ),
              ),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _confirm,
                  child: Text(t.tr('continueButton')),
                ),
              ),
            ],
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
