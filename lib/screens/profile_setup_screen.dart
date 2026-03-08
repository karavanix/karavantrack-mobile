import 'package:flutter/material.dart';
import '../store/app_store.dart';

/// Profile setup screen — shown after login if profile is incomplete.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, child) {
        final loading = widget.store.isLoading;
        return Scaffold(
          appBar: AppBar(title: const Text('Complete Profile')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Set up your profile',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter your name to continue.',
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _firstNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'First name *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _lastNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Last name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: loading
                                  ? null
                                  : () async {
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      final error =
                                          await widget.store.saveProfile(
                                        firstName: _firstNameCtrl.text,
                                        lastName: _lastNameCtrl.text,
                                      );
                                      if (error != null) {
                                        messenger.showSnackBar(
                                          SnackBar(content: Text(error)),
                                        );
                                      }
                                    },
                              child: loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Save & Continue'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
