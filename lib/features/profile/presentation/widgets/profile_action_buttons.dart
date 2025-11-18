import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
Widget buildProfileActionButtons(BuildContext context, WidgetRef ref) {
  return Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: shadcnui.DestructiveButton(
          onPressed: () => ref.read(authProvider.notifier).signOut(),
          child: Text(context.l10n.signOut),
        ),
      ),
    ],
  );
}
