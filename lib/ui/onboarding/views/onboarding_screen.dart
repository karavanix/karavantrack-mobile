import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/themes/app_theme.dart';
import '../view_models/onboarding_view_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.viewModel});

  final OnboardingViewModel viewModel;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static final _slides = <_SlideData>[
    _SlideData(
      icon: Icons.local_shipping_rounded,
      title: (l) => l.onboardTitle1,
      body: (l) => l.onboardBody1,
    ),
    _SlideData(
      icon: Icons.gps_fixed_rounded,
      title: (l) => l.onboardTitle2,
      body: (l) => l.onboardBody2,
    ),
    _SlideData(
      icon: Icons.payments_rounded,
      title: (l) => l.onboardTitle3,
      body: (l) => l.onboardBody3,
    ),
  ];

  bool get _isLast => _index == _slides.length - 1;

  void _finish() => widget.viewModel.finish.execute();

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colors = AppTheme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (top-right). Hidden on last slide where CTA becomes "Get started".
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: TextButton(
                  onPressed: _isLast ? null : _finish,
                  child: Text(
                    _isLast ? '' : t.skip,
                    style: TextStyle(color: colors.mutedForeground),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.icon, size: 56, color: colors.primary),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          s.title(t),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: colors.foreground,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.body(t),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? colors.primary
                        : colors.mutedForeground.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(_isLast ? t.getStarted : t.next),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  const _SlideData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) body;
}
