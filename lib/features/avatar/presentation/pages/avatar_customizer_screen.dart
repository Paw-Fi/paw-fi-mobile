import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;

class AvatarCustomizerScreen extends StatelessWidget {
  const AvatarCustomizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Avatar placeholder icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: shadcnui.Theme.of(context).colorScheme.muted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  size: 60,
                  color: shadcnui.Theme.of(context).colorScheme.mutedForeground,
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Create Your Avatar',
                style: shadcnui.Theme.of(context).typography.h2,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                'Customize your profile picture',
                style: shadcnui.Theme.of(context).typography.textMuted,
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Skip button
              SizedBox(
                width: double.infinity,
                child: shadcnui.PrimaryButton(
                  onPressed: () {
                    context.go('/onboarding');
                  },
                  child: const Text('Skip for now'),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
