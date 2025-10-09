import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Home/Dashboard Page - Empty for now, will be implemented later
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Home Dashboard - Coming Soon',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
