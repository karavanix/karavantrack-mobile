import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';

/// The setting a mockup points at.
enum SettingsFocus { always, precise }

/// The app's location page in the phone's settings, drawn rather than a
/// screenshot: it comes in the phone's language and theme, and the option
/// to pick is ringed. A picture of the screen is found at a glance; three
/// steps in words have to be read and kept in mind.
///
/// Labels follow stock iOS and Android 11+ (the system's own permission
/// page, the same on Honor).
class LocationSettingsMockup extends StatelessWidget {
  const LocationSettingsMockup({super.key, required this.focus});

  final SettingsFocus focus;

  @override
  Widget build(BuildContext context) => _Picture(
    child: defaultTargetPlatform == TargetPlatform.iOS
        ? _IosLocationPage(focus: focus)
        : _AndroidLocationPage(focus: focus),
  );
}

/// The Location Services switch in iOS Settings (Privacy & Security), the
/// end of the way when they're off.
class LocationServicesMockup extends StatelessWidget {
  const LocationServicesMockup({super.key});

  @override
  Widget build(BuildContext context) {
    final c = _IosColors.of(context);
    return _Picture(
      child: ColoredBox(
        color: c.background,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _IosGroup(
            colors: c,
            rows: [
              _Ringed(
                radius: 10,
                child: _IosRow(
                  colors: c,
                  label: context.l10n.settingsMockIosLocationServices,
                  trailing: _MockSwitch(on: true, color: c.switchOn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A mockup is a picture: no taps, and screen readers skip it (the steps
/// and the title say the same in words).
class _Picture extends StatelessWidget {
  const _Picture({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// The option to pick, ringed.
class _Ringed extends StatelessWidget {
  const _Ringed({required this.child, this.radius = 8});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.orange, width: 2.5),
    ),
    child: child,
  );
}

class _MockSwitch extends StatelessWidget {
  const _MockSwitch({required this.on, required this.color});

  final bool on;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 28,
    padding: const EdgeInsets.all(3),
    alignment: on ? Alignment.centerRight : Alignment.centerLeft,
    decoration: BoxDecoration(
      color: on ? color : Colors.grey.shade400,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    ),
  );
}

// ─── iOS ─────────────────────────────────────────────────────────────────────

/// iOS system colours, light and dark.
class _IosColors {
  const _IosColors._({
    required this.background,
    required this.group,
    required this.text,
    required this.secondary,
    required this.separator,
  });

  factory _IosColors.of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const _IosColors._(
          background: Color(0xFF1C1C1E),
          group: Color(0xFF2C2C2E),
          text: Colors.white,
          secondary: Color(0xFF8E8E93),
          separator: Color(0xFF3A3A3C),
        )
      : const _IosColors._(
          background: Color(0xFFF2F2F7),
          group: Colors.white,
          text: Colors.black,
          secondary: Color(0xFF8E8E93),
          separator: Color(0xFFC6C6C8),
        );

  final Color background;
  final Color group;
  final Color text;
  final Color secondary;
  final Color separator;
  Color get tint => const Color(0xFF007AFF);
  Color get switchOn => const Color(0xFF34C759);
}

/// Settings → YoolLive → Location.
class _IosLocationPage extends StatelessWidget {
  const _IosLocationPage({required this.focus});

  final SettingsFocus focus;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final c = _IosColors.of(context);
    final check = Icon(Icons.check, size: 20, color: c.tint);
    final always = _IosRow(
      colors: c,
      label: t.settingsMockIosAlways,
      trailing: check,
    );
    final precise = _IosRow(
      colors: c,
      label: t.settingsMockIosPrecise,
      trailing: _MockSwitch(on: true, color: c.switchOn),
    );
    return ColoredBox(
      color: c.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios_new, size: 16, color: c.tint),
                        const SizedBox(width: 2),
                        Text(
                          'YoolLive',
                          style: TextStyle(color: c.tint, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    t.settingsMockIosTitle,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Text(
                t.settingsMockIosHeader,
                style: TextStyle(color: c.secondary, fontSize: 12),
              ),
            ),
            _IosGroup(
              colors: c,
              rows: [
                _IosRow(colors: c, label: t.settingsMockIosNever),
                _IosRow(colors: c, label: t.settingsMockIosAskNext),
                _IosRow(colors: c, label: t.settingsMockIosWhileUsing),
                if (focus == SettingsFocus.always)
                  _Ringed(child: always)
                else
                  always,
              ],
            ),
            const SizedBox(height: 20),
            _IosGroup(
              colors: c,
              rows: [
                if (focus == SettingsFocus.precise)
                  _Ringed(radius: 10, child: precise)
                else
                  precise,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IosGroup extends StatelessWidget {
  const _IosGroup({required this.colors, required this.rows});

  final _IosColors colors;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: colors.group,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Divider(
                height: 0.5,
                thickness: 0.5,
                color: colors.separator,
              ),
            ),
          row,
        ],
      ],
    ),
  );
}

class _IosRow extends StatelessWidget {
  const _IosRow({required this.colors, required this.label, this.trailing});

  final _IosColors colors;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 44),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.text, fontSize: 15),
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}

// ─── Android ─────────────────────────────────────────────────────────────────

/// App info → Permissions → Location: the system's own page, Material.
class _AndroidLocationPage extends StatelessWidget {
  const _AndroidLocationPage({required this.focus});

  final SettingsFocus focus;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final allTime = _AndroidRadioRow(
      label: t.settingsMockAndroidAllowAllTime,
      selected: true,
    );
    final precise = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t.settingsMockAndroidPrecise,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          _MockSwitch(on: true, color: scheme.primary),
        ],
      ),
    );
    return ColoredBox(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_back, size: 20, color: scheme.onSurface),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      t.settingsMockAndroidTitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                t.settingsMockAndroidHeader,
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (focus == SettingsFocus.always)
              _Ringed(child: allTime)
            else
              allTime,
            _AndroidRadioRow(label: t.settingsMockAndroidWhileUsing),
            _AndroidRadioRow(label: t.settingsMockAndroidAskEveryTime),
            _AndroidRadioRow(label: t.settingsMockAndroidDeny),
            const Divider(height: 16),
            if (focus == SettingsFocus.precise)
              _Ringed(child: precise)
            else
              precise,
          ],
        ),
      ),
    );
  }
}

class _AndroidRadioRow extends StatelessWidget {
  const _AndroidRadioRow({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: selected
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
