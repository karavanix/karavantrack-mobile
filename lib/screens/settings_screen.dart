import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../services/debug_service.dart';
import '../store/app_store.dart';
import '../l10n/app_localizations.dart';

/// Settings screen — user profile info, editable name, language, support, logout.
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
    final t = AppLocalizations.of(context);
    final error = await store.saveProfile(
      firstName: _firstNameCtrl.text,
      lastName: _lastNameCtrl.text,
    );
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(error)),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(t.tr('profileUpdated'))),
      );
      // Re-sync controllers with the updated profile
      setState(() {
        _initialized = false;
        _syncControllers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final t = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, child) {
        _syncControllers();
        final profile = store.profile;
        final loading = store.isLoading;

        return Scaffold(
          appBar: AppBar(title: Text(t.tr('settings'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Profile card ──────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                theme.colorScheme.primary.withValues(alpha: 0.15),
                            child: Icon(
                              Icons.person,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile?.fullName ?? t.tr('driver'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (profile?.email != null)
                                  Text(
                                    profile!.email!,
                                    style: TextStyle(
                                        fontSize: 13, color: mutedColor),
                                  ),
                                if (profile?.phone != null)
                                  Text(
                                    profile!.phone!,
                                    style: TextStyle(
                                        fontSize: 13, color: mutedColor),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── Language card ───────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.language,
                              size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            t.tr('language'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: AppLocalizations.supportedLocales
                              .map((code) => ButtonSegment<String>(
                                    value: code,
                                    label: Text(
                                      AppLocalizations.languageNames[code]!,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ))
                              .toList(),
                          selected: {store.locale},
                          onSelectionChanged: (selected) {
                            store.setLocale(selected.first);
                          },
                          showSelectedIcon: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── Theme card ──────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.brightness_6_outlined,
                              size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            t.tr('theme'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          segments: [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text(t.tr('darkMode'),
                                  style: const TextStyle(fontSize: 13)),
                              icon: const Icon(Icons.dark_mode_outlined,
                                  size: 16),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text(t.tr('lightMode'),
                                  style: const TextStyle(fontSize: 13)),
                              icon: const Icon(Icons.light_mode_outlined,
                                  size: 16),
                            ),
                          ],
                          selected: {store.isDarkTheme},
                          onSelectionChanged: (selected) {
                            store.setDarkTheme(selected.first);
                          },
                          showSelectedIcon: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── Edit Profile card ─────────────────────────────────

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            t.tr('editProfile'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
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
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: loading ? null : _saveProfile,
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                              loading ? t.tr('saving') : t.tr('saveChanges')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── Support ───────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.tr('support'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'support@yool.live',
                        style: TextStyle(color: mutedColor, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── Logout ────────────────────────────────────────────
              Card(
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    Icons.logout,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    t.tr('signOut'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: store.logout,
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
                    style: TextStyle(fontSize: 12, color: mutedColor),
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
