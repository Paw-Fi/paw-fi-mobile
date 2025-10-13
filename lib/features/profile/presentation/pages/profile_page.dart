import 'package:flutter/material.dart' hide IconButton, Card, Divider, Switch, Chip;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/features/auth/presentation/states/auth.dart';
import 'package:moneko/features/profile/presentation/widgets/widgets.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: shadcnui.Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: shadcnui.SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                buildProfileHeader(context, ref),
                const shadcnui.Gap(40),
                buildProfileAvatarHeader(context, user),
                const shadcnui.Gap(32),
                buildWhatsAppBindingCard(context, ref),
                const shadcnui.Gap(24),
                buildProfileActionButtons(ref),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
