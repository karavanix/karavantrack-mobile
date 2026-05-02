import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../services/debug_service.dart';
import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/floating_dock.dart';
import '../l10n/app_localizations.dart';

const _supportEmail = 'support@yool.live';

/// Settings screen — profile hero, grouped preferences, account actions.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  bool _initialized = false;
  int _versionTapCount = 0;

  AppStore get store => widget.store;

  void _syncControllers() {
    final profile = store.profile;
    if (profile != null && !_initialized) {
      _firstNameCtrl.text = profile.firstName;
      _lastNameCtrl.text = profile.lastName;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final t = AppLocalizations.of(context);
    final error = await store.saveProfile(
      firstName: _firstNameCtrl.text,
      lastName: _lastNameCtrl.text,
    );
    if (!mounted) return;
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() {
      _initialized = false;
      _syncControllers();
    });
    if (navigator.canPop()) navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(t.tr('profileUpdated'))));
  }

  void _openEditSheet() {
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;
        return ListenableBuilder(
          listenable: store,
          builder: (ctx, _) {
            final loading = store.isLoading;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + viewInsets),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    t.tr('editProfile'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _firstNameCtrl,
                    enabled: !loading,
                    decoration: InputDecoration(
                      labelText: t.tr('firstName'),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lastNameCtrl,
                    enabled: !loading,
                    decoration: InputDecoration(
                      labelText: t.tr('lastName'),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveProfile(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : _saveProfile,
                      icon: loading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primaryForeground,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        loading ? t.tr('saving') : t.tr('saveChanges'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openLanguageSheet() {
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _OptionSheet(
          title: t.tr('selectLanguage'),
          options: AppLocalizations.supportedLocales
              .map(
                (code) => _SheetOption(
                  value: code,
                  label: AppLocalizations.languageNames[code]!,
                ),
              )
              .toList(),
          selected: store.locale,
          onSelect: (code) {
            store.setLocale(code);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  void _openThemeSheet() {
    final t = AppLocalizations.of(context);
    final colors = AppTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _OptionSheet<bool>(
          title: t.tr('selectTheme'),
          options: [
            _SheetOption(
              value: true,
              label: t.tr('darkMode'),
              icon: Icons.dark_mode_outlined,
            ),
            _SheetOption(
              value: false,
              label: t.tr('lightMode'),
              icon: Icons.light_mode_outlined,
            ),
          ],
          selected: store.isDarkTheme,
          onSelect: (v) {
            store.setDarkTheme(v);
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  Future<void> _contactSupport() async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(t.tr('copied'))));
  }

  String _initials(String first, String last) {
    String pick(String s) => s.trim().isEmpty ? '' : s.trim()[0].toUpperCase();
    final result = '${pick(first)}${pick(last)}';
    return result.isEmpty ? '' : result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final t = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, child) {
        _syncControllers();
        final profile = store.profile;
        final initials = profile == null
            ? ''
            : _initials(profile.firstName, profile.lastName);

        return Scaffold(
          appBar: AppBar(title: Text(t.tr('settings'))),
          body: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, dockClearance(context)),
            children: [
              // ─── Profile hero ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary.withValues(alpha: 0.15),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: initials.isNotEmpty
                          ? Text(
                              initials,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            )
                          : Icon(
                              Icons.person,
                              size: 36,
                              color: colors.primary,
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile?.fullName ?? t.tr('driver'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (profile?.email != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        profile!.email!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                    if (profile?.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile!.phone!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _openEditSheet,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(t.tr('edit')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Preferences section ───────────────────────────────
              _SectionLabel(label: t.tr('preferences')),
              Card(
                child: Column(
                  children: [
                    _SettingRow(
                      icon: Icons.language,
                      label: t.tr('language'),
                      value: AppLocalizations.languageNames[store.locale] ?? '',
                      onTap: _openLanguageSheet,
                    ),
                    Divider(height: 1, color: colors.border),
                    _SettingRow(
                      icon: Icons.brightness_6_outlined,
                      label: t.tr('theme'),
                      value: store.isDarkTheme
                          ? t.tr('darkMode')
                          : t.tr('lightMode'),
                      onTap: _openThemeSheet,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── Account section ───────────────────────────────────
              _SectionLabel(label: t.tr('account')),
              Card(
                child: _SettingRow(
                  icon: Icons.mail_outline_rounded,
                  label: t.tr('contactSupport'),
                  subtitle: _supportEmail,
                  trailingIcon: Icons.copy_rounded,
                  onTap: _contactSupport,
                ),
              ),

              const SizedBox(height: 24),

              // ─── Sign out ──────────────────────────────────────────
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: store.logout,
                  icon: Icon(Icons.logout, color: colors.destructive, size: 18),
                  label: Text(
                    t.tr('signOut'),
                    style: TextStyle(color: colors.destructive),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: colors.destructive.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ─── Version (tap 5× to open debug panel) ─────────────
              GestureDetector(
                onTap: () {
                  _versionTapCount++;
                  if (_versionTapCount >= 5) {
                    _versionTapCount = 0;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TalkerScreen(talker: DebugService.talker),
                      ),
                    );
                  }
                },
                child: Center(
                  child: Text(
                    'v1.0.1',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ─── Section label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: colors.mutedForeground,
        ),
      ),
    );
  }
}

// ─── Tappable settings row ──────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.subtitle,
    this.trailingIcon = Icons.chevron_right_rounded,
  }) : assert(value == null || subtitle == null,
            'Use either value (inline, right-aligned) or subtitle (stacked)');

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Inline value rendered to the right of the label (right-aligned).
  final String? value;

  /// Subtitle rendered below the label (stacked layout).
  final String? subtitle;

  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final mutedStyle = TextStyle(fontSize: 13, color: colors.mutedForeground);
    final labelStyle = const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );

    final Widget content = subtitle != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: mutedStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          )
        : Row(
            children: [
              Expanded(child: Text(label, style: labelStyle)),
              const SizedBox(width: 12),
              Text(
                value ?? '',
                style: mutedStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ],
          );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(child: content),
            const SizedBox(width: 8),
            Icon(trailingIcon, size: 18, color: colors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

// ─── Generic option-picker bottom sheet ─────────────────────────────────────

class _SheetOption<T> {
  const _SheetOption({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final List<_SheetOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...options.map((opt) {
              final isSelected = opt.value == selected;
              return InkWell(
                onTap: () => onSelect(opt.value),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      if (opt.icon != null) ...[
                        Icon(
                          opt.icon,
                          size: 20,
                          color: isSelected
                              ? colors.primary
                              : colors.mutedForeground,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected ? colors.primary : null,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: colors.primary,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
