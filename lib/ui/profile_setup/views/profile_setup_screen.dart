import 'package:material_ui/material_ui.dart';

import '../../../utils/result.dart';
import '../../core/errors.dart';
import '../../core/l10n/l10n.dart';
import '../view_models/profile_setup_view_model.dart';

/// Profile setup screen — shown after login if profile is incomplete.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.viewModel});

  final ProfileSetupViewModel viewModel;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final _firstNameCtrl = TextEditingController(
    text: widget.viewModel.initial.firstName,
  );
  late final _lastNameCtrl = TextEditingController(
    text: widget.viewModel.initial.lastName,
  );

  @override
  void initState() {
    super.initState();
    widget.viewModel.save.addListener(_onSaveChanged);
  }

  @override
  void dispose() {
    widget.viewModel.save.removeListener(_onSaveChanged);
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  void _onSaveChanged() {
    final save = widget.viewModel.save;
    if (save.result case Error(:final error)) {
      save.clearResult();
      final t = context.l10n;
      final text = error is FirstNameMissing
          ? t.firstNameIsRequired
          : errorText(t, error);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.l10n;

    return ListenableBuilder(
      listenable: widget.viewModel.save,
      builder: (context, child) {
        final loading = widget.viewModel.save.running;
        return Scaffold(
          appBar: AppBar(title: Text(t.completeProfile)),
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
                            t.setUpYourProfile,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.enterNameToContinue,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _firstNameCtrl,
                            decoration: InputDecoration(
                              labelText: t.firstNameRequired,
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _lastNameCtrl,
                            decoration: InputDecoration(
                              labelText: t.lastName,
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: loading
                                  ? null
                                  : () => widget.viewModel.save.execute((
                                      firstName: _firstNameCtrl.text,
                                      lastName: _lastNameCtrl.text,
                                    )),
                              child: loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(t.saveAndContinue),
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
