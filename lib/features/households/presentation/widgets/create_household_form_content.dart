import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/features/households/presentation/widgets/household_image_picker.dart';
import '../../core/household_constants.dart';
import 'package:moneko/core/theme/app_theme.dart';

class CreateHouseholdFormContent extends ConsumerWidget {
  const CreateHouseholdFormContent({
    super.key,
    required this.nameController,
    required this.selectedImageUrl,
    required this.selectedImageFile,
    required this.onImageSelected,
    required this.isLoading,
  });

  final TextEditingController nameController;
  final String? selectedImageUrl;
  final File? selectedImageFile;
  final Function(String?, File?) onImageSelected;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Centered Image Picker with softer aesthetic
        Center(
          child: _buildCoverImageSection(context, ref, colorScheme),
        ),
        const SizedBox(height: 48),

        // Minimalist Floating Input
        _buildNameInput(context, colorScheme),
      ],
    );
  }

  Widget _buildCoverImageSection(
      BuildContext context, WidgetRef ref, ColorScheme colorScheme) {
    return Semantics(
      label: HouseholdConstants.coverImageSemanticLabel,
      child: GestureDetector(
        onTap: isLoading
            ? null
            : () => HouseholdImagePicker.showImageSourceModal(
                  context: context,
                  ref: ref,
                  currentImageUrl: selectedImageUrl,
                  onImageSelected: onImageSelected,
                ),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.cardSurface,
                borderRadius: BorderRadius.circular(40), // Softer, more organic radius
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: selectedImageFile != null
                    ? Image.file(
                        selectedImageFile!,
                        fit: BoxFit.cover,
                      )
                    : selectedImageUrl != null
                        ? Image.network(
                            selectedImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildPlaceholder(colorScheme),
                          )
                        : _buildPlaceholder(colorScheme),
              ),
            ),
            Transform.translate(
              offset: const Offset(4, 4),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.cardSurface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Center(
      child: Icon(
        Icons.credit_card_rounded,
        size: 40,
        color: colorScheme.mutedForeground.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildNameInput(BuildContext context, ColorScheme colorScheme) {
    return Semantics(
      label: context.l10n.householdNameInput,
      textField: true,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.cardSurface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: AdaptiveTextFormField(
          controller: nameController,
          enabled: !isLoading,
          placeholder: 'Name This Space',
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: colorScheme.foreground,
            letterSpacing: -0.5,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            hintStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: colorScheme.mutedForeground.withValues(alpha: 0.5),
              letterSpacing: -0.5,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return context.l10n.pleaseEnterHouseholdName;
            }
            if (value.trim().length < HouseholdConstants.minNameLength) {
              return context.l10n
                  .nameMinLength(HouseholdConstants.minNameLength);
            }
            if (value.trim().length > HouseholdConstants.maxNameLength) {
              return context.l10n
                  .nameMaxLength(HouseholdConstants.maxNameLength);
            }
            return null;
          },
        ),
      ),
    );
  }
}
