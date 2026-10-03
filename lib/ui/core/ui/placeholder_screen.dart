import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

/// Stand-in for a screen that hasn't been ported yet: shows the route and
/// optional buttons that move the flow along.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;
  final List<({String label, VoidCallback onPressed})> actions;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(location, style: Theme.of(context).textTheme.bodySmall),
            for (final action in actions)
              FilledButton(
                onPressed: action.onPressed,
                child: Text(action.label),
              ),
          ],
        ),
      ),
    );
  }
}
