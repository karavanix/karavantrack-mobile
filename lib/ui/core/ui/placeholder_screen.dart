import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Stand-in for a screen that hasn't been ported yet: shows the route.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(location, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
