import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
        _buildCoverImageSection(context, ref, colorScheme),
        const SizedBox(height: 40),
        _buildNameInput(context, colorScheme),
      ],
    );
  }

  Widget _buildCoverImageSection(
      BuildContext context, WidgetRef ref, ColorScheme colorScheme) {
    return Semantics(
      label: HouseholdConstants.coverImageSemanticLabel,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: colorScheme.border.withValues(alpha: 0.12),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: selectedImageFile != null
                      ? Image.file(
                          selectedImageFile!,
                          fit: BoxFit.cover,
                        )
                      : selectedImageUrl != null
                          ? Image.network(
                              selectedImageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: colorScheme.muted,
                                  child: Center(
                                    child: SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        value: progress.expectedTotalBytes !=
                                                null
                                            ? progress.cumulativeBytesLoaded /
                                                progress.expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stack) {
                                return Container(
                                  color: colorScheme.muted,
                                  child:
                                      const Icon(Icons.home_rounded, size: 48),
                                );
                              },
                            )
                          : Container(
                              color: colorScheme.muted,
                              child: const Icon(Icons.home_rounded, size: 48),
                            ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Semantics(
                  label: HouseholdConstants.editCoverButtonLabel,
                  button: true,
                  child: Material(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: isLoading
                          ? null
                          : () => HouseholdImagePicker.showImageSourceModal(
                                context: context,
                                ref: ref,
                                currentImageUrl: selectedImageUrl,
                                onImageSelected: onImageSelected,
                              ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.appBackground,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          Icons.edit,
                          size: 18,
                          color: colorScheme.primaryForeground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.tapToChangeCover,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameInput(BuildContext context, ColorScheme colorScheme) {
    return Semantics(
      label: context.l10n.householdNameInput,
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.householdName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: nameController,
            enabled: !isLoading,
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.foreground,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: context.l10n.householdNameHint,
              hintStyle: TextStyle(
                color: colorScheme.mutedForeground.withValues(alpha: 0.4),
                fontWeight: FontWeight.normal,
              ),
              filled: true,
              fillColor: colorScheme.muted.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.border.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.border.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.destructive,
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.destructive,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
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
        ],
      ),
    );
  }
}
