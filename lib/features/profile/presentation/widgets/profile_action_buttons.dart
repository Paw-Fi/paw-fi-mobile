import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/auth/presentation/states/auth.dart';

Widget buildProfileActionButtons(WidgetRef ref) {
  return Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: shadcnui.DestructiveButton(
          onPressed: () => ref.read(authProvider.notifier).signOut(),
          child: const Text('Sign Out'),
        ),
      ),
    ],
  );
}
