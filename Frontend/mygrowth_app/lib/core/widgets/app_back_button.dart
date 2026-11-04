import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Consistent app-bar navigation back control with a safe area-home fallback.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Go back',
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
          return;
        }

        final path = GoRouterState.of(context).uri.path;
        context.go(path.startsWith('/admin') ? '/admin' : '/home');
      },
    );
  }
}
