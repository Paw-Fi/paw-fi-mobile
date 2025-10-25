import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:supabase_flutter/supabase_flutter.dart';
// removed shared budgets UI from settings; budgets are managed elsewhere
import '../../domain/entities/household.dart';
import '../providers/household_providers.dart';
import '../providers/selected_household_provider.dart';
import '../widgets/household_image_picker.dart';
import '../../../../core/config/storage_config.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:path/path.dart' as path;

/// Household Settings Page
/// Manage budgets, privacy preferences, and household settings
class HouseholdSettingsPage extends ConsumerStatefulWidget {
  final String householdId;

  const HouseholdSettingsPage({
    super.key,
    required this.householdId,
  });

  @override
  ConsumerState<HouseholdSettingsPage> createState() =>
      _HouseholdSettingsPageState();
}

class _HouseholdSettingsPageState extends ConsumerState<HouseholdSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure controller length matches TabBar tabs after hot reloads/changes
    if (_tabController.length != 2) {
      _tabController.dispose();
      _tabController = TabController(length: 2, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        title: Text(
          'Household Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.foreground,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.mutedForeground,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Notifications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GeneralTab(householdId: widget.householdId),
          _NotificationsTab(householdId: widget.householdId),
        ],
      ),
    );
  }
}

/// General Tab
class _GeneralTab extends ConsumerStatefulWidget {
  final String householdId;

  const _GeneralTab({required this.householdId});

  @override
  ConsumerState<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends ConsumerState<_GeneralTab> {
  final _nameController = TextEditingController();
  String? _selectedImageUrl;
  File? _selectedImageFile;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(householdProvider(widget.householdId));
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return householdAsync.when(
      data: (household) {
        if (household == null) {
          return Center(
            child: Text(
              'Household not found',
              style: TextStyle(color: colorScheme.destructive),
            ),
          );
        }

        // Initialize controller with current name if not already set
        if (_nameController.text.isEmpty) {
          _nameController.text = household.name;
        }
        if (_selectedImageUrl == null && _selectedImageFile == null) {
          _selectedImageUrl = household.coverImageUrl;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Household Name
            Text(
              'Household Name',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter household name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: colorScheme.card,
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 24),

            // Cover Photo
            Text(
              'Cover Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showImagePicker(context, household),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.border.withOpacity(0.12),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image preview
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: _selectedImageFile != null
                          ? Image.file(
                              _selectedImageFile!,
                              fit: BoxFit.cover,
                            )
                          : _selectedImageUrl != null
                              ? Image.network(
                                  _selectedImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) =>
                                      Container(
                                    color: colorScheme.muted,
                                    child: Icon(
                                      Icons.home_rounded,
                                      size: 48,
                                      color: colorScheme.mutedForeground,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: colorScheme.muted,
                                  child: Icon(
                                    Icons.home_rounded,
                                    size: 48,
                                    color: colorScheme.mutedForeground,
                                  ),
                                ),
                    ),
                    // Overlay button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Change Cover Photo',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            shadcnui.PrimaryButton(
              onPressed: _isSaving ? null : () => _saveChanges(household),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading household: $error',
          style: TextStyle(color: colorScheme.destructive),
        ),
      ),
    );
  }

  void _showImagePicker(BuildContext context, Household household) {
    HouseholdImagePicker.showImageSourceModal(
      context: context,
      ref: ref,
      currentImageUrl: _selectedImageUrl,
      onImageSelected: (imageUrl, imageFile) {
        setState(() {
          _selectedImageUrl = imageUrl;
          _selectedImageFile = imageFile;
        });
      },
    );
  }

  Future<void> _saveChanges(Household household) async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter a household name');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? imageUrl = _selectedImageUrl;

      // Upload image if file was selected
      if (_selectedImageFile != null) {
        imageUrl = await _uploadImage(_selectedImageFile!);
      }

      // Update household via repository
      final repository = ref.read(householdRepositoryProvider);
      await repository.updateHousehold(
        householdId: widget.householdId,
        name: _nameController.text.trim(),
        coverImageUrl: imageUrl,
      );
      
      // Invalidate providers to refresh UI
      ref.invalidate(householdProvider(widget.householdId));
      ref.invalidate(userHouseholdsProvider(ref.read(authProvider).uid));

      // Refresh selected household if this is the selected one
      final selectedState = ref.read(selectedHouseholdProvider);
      if (selectedState.householdId == widget.householdId) {
        final user = ref.read(authProvider);
        await ref.read(selectedHouseholdProvider.notifier).refresh(user.uid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Household updated successfully'),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to update household: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final supabase = Supabase.instance.client;
      final user = ref.read(authProvider);
      final fileName = '${StorageConfig.householdCoversPath}/${user.uid}/${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

      await supabase.storage
          .from(StorageConfig.publicBucket)
          .upload(fileName, imageFile);

      final publicUrl = supabase.storage
          .from(StorageConfig.publicBucket)
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: shadcnui.Theme.of(context).colorScheme.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  shadcnui.ColorScheme get colorScheme => shadcnui.Theme.of(context).colorScheme;
}

// Budgets tab removed per requirements

/// Notifications Tab
class _NotificationsTab extends ConsumerStatefulWidget {
  final String householdId;

  const _NotificationsTab({required this.householdId});

  @override
  ConsumerState<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<_NotificationsTab> {
  bool? _enableNudges;
  TimeOfDay? _quietHoursStart;
  TimeOfDay? _quietHoursEnd;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final user = ref.read(authProvider);

    final prefsParams = SharingPrefsParams(
      userId: user.uid,
      householdId: widget.householdId,
    );
    final prefsAsync = ref.watch(sharingPrefsProvider(prefsParams));

    return prefsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading preferences: $error',
          style: TextStyle(color: colorScheme.destructive),
        ),
      ),
      data: (prefs) {
        // Initialize values from loaded preferences
        if (prefs != null && _enableNudges == null) {
          _enableNudges = prefs.enableNudges;
          _quietHoursStart = prefs.nudgeQuietHoursStart != null
              ? _parseTimeString(prefs.nudgeQuietHoursStart!)
              : null;
          _quietHoursEnd = prefs.nudgeQuietHoursEnd != null
              ? _parseTimeString(prefs.nudgeQuietHoursEnd!)
              : null;
        } else if (_enableNudges == null) {
          // Default values
          _enableNudges = true;
          _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
          _quietHoursEnd = const TimeOfDay(hour: 8, minute: 0);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Budget Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage when and how you receive budget nudges',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),

            // Enable Nudges Toggle
            Card(
              child: SwitchListTile(
                title: const Text('Enable Budget Nudges'),
                subtitle: const Text(
                  'Receive notifications when approaching budget limits',
                ),
                value: _enableNudges!,
                onChanged: (value) {
                  setState(() {
                    _enableNudges = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Quiet Hours Section
            Text(
              'Quiet Hours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set times when you don\'t want to receive budget nudges',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),

            // Quiet Hours Start
            Card(
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.bedtime,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: const Text('Quiet Hours Start'),
                subtitle: Text(
                  _quietHoursStart != null
                      ? 'No nudges after ${_quietHoursStart!.format(context)}'
                      : 'Not set',
                ),
                trailing: Icon(Icons.chevron_right, color: colorScheme.mutedForeground),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _quietHoursStart ?? const TimeOfDay(hour: 22, minute: 0),
                  );
                  if (time != null) {
                    setState(() {
                      _quietHoursStart = time;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 8),

            // Quiet Hours End
            Card(
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.wb_sunny,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: const Text('Quiet Hours End'),
                subtitle: Text(
                  _quietHoursEnd != null
                      ? 'Resume nudges at ${_quietHoursEnd!.format(context)}'
                      : 'Not set',
                ),
                trailing: Icon(Icons.chevron_right, color: colorScheme.mutedForeground),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _quietHoursEnd ?? const TimeOfDay(hour: 8, minute: 0),
                  );
                  if (time != null) {
                    setState(() {
                      _quietHoursEnd = time;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // Clear Quiet Hours Button
            if (_quietHoursStart != null || _quietHoursEnd != null)
              shadcnui.OutlineButton(
                onPressed: () {
                  setState(() {
                    _quietHoursStart = null;
                    _quietHoursEnd = null;
                  });
                },
                child: const Text('Clear Quiet Hours'),
              ),
            const SizedBox(height: 32),

            // Save Button
            shadcnui.PrimaryButton(
              onPressed: _isSaving ? null : _savePreferences,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save Notification Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final user = ref.read(authProvider);
      final prefsParams = SharingPrefsParams(
        userId: user.uid,
        householdId: widget.householdId,
      );

      await ref.read(sharingPrefsProvider(prefsParams).notifier).updatePreferences(
            enableNudges: _enableNudges,
            nudgeQuietHoursStart: _quietHoursStart != null
                ? _formatTimeOfDay(_quietHoursStart!)
                : null,
            nudgeQuietHoursEnd: _quietHoursEnd != null
                ? _formatTimeOfDay(_quietHoursEnd!)
                : null,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification settings saved successfully'),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: colorScheme.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  TimeOfDay _parseTimeString(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  shadcnui.ColorScheme get colorScheme => shadcnui.Theme.of(context).colorScheme;
}
