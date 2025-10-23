import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/shared_budget.dart';
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
    _tabController = TabController(length: 4, vsync: this);
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
            Tab(text: 'Budgets'),
            Tab(text: 'Privacy'),
            Tab(text: 'Notifications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GeneralTab(householdId: widget.householdId),
          _BudgetsTab(householdId: widget.householdId),
          _PrivacyTab(householdId: widget.householdId),
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

/// Budgets Tab
class _BudgetsTab extends ConsumerWidget {
  final String householdId;

  const _BudgetsTab({required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(householdBudgetsProvider(householdId));
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return budgetsAsync.when(
      data: (budgets) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Add Budget Button
          shadcnui.PrimaryButton(
            onPressed: () => _showCreateBudgetDialog(context, ref),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add),
                SizedBox(width: 8),
                Text('Create Budget'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Budgets List
          if (budgets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No budgets yet. Create one to start tracking!',
                  style: TextStyle(color: colorScheme.mutedForeground),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...budgets.map((budget) => _BudgetCard(
                  budget: budget,
                  householdId: householdId,
                )),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error', style: TextStyle(color: colorScheme.destructive)),
      ),
    );
  }

  void _showCreateBudgetDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    BudgetPeriod selectedPeriod = BudgetPeriod.monthly;
    BudgetType selectedType = BudgetType.household;
    bool countSplitPortionOnly = false;
    double warnThreshold = 0.8;
    double alertThreshold = 1.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Budget'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Budget Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<BudgetPeriod>(
                  value: selectedPeriod,
                  decoration: const InputDecoration(labelText: 'Period'),
                  items: BudgetPeriod.values
                      .map((period) => DropdownMenuItem(
                            value: period,
                            child: Text(period.toJson()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedPeriod = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<BudgetType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Budget Type',
                    helperText: 'Household budgets track all expenses, personal budgets track only yours',
                  ),
                  items: BudgetType.values
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.toJson().toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedType = value;
                      });
                    }
                  },
                ),
                if (selectedType == BudgetType.personal) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Count Split Portion Only'),
                    subtitle: const Text(
                      'Only count your portion of split expenses towards this budget',
                    ),
                    value: countSplitPortionOnly,
                    onChanged: (value) {
                      setState(() {
                        countSplitPortionOnly = value;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (nameController.text.isNotEmpty && amount != null) {
                  await ref.read(householdBudgetsProvider(householdId).notifier).createBudget(
                    name: nameController.text,
                    period: selectedPeriod.toJson(),
                    currency: 'USD',
                    amountCents: (amount * 100).toInt(),
                    warnThreshold: warnThreshold,
                    alertThreshold: alertThreshold,
                    budgetType: selectedType.toJson(),
                    countSplitPortionOnly: countSplitPortionOnly,
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Budget Card
class _BudgetCard extends StatelessWidget {
  final SharedBudget budget;
  final String householdId;

  const _BudgetCard({
    required this.budget,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;
    final amount = budget.amountCents / 100;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: budget.budgetType == BudgetType.personal
                              ? colorScheme.primary.withOpacity(0.1)
                              : colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          budget.budgetType.toJson().toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: budget.budgetType == BudgetType.personal
                                ? colorScheme.primary
                                : colorScheme.secondaryForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  budget.period.toJson().toUpperCase(),
                  style: TextStyle(
                    color: colorScheme.mutedForeground,
                    fontSize: 12,
                  ),
                ),
                if (budget.budgetType == BudgetType.personal && budget.countSplitPortionOnly) ...[
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  Text(
                    'Split portion only',
                    style: TextStyle(
                      color: colorScheme.mutedForeground,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.notifications,
                  size: 16,
                  color: colorScheme.mutedForeground,
                ),
                const SizedBox(width: 4),
                Text(
                  'Budget Boop at ${(budget.warnThreshold * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.warning,
                  size: 16,
                  color: colorScheme.destructive,
                ),
                const SizedBox(width: 4),
                Text(
                  'Purr-suasive Nudge at ${(budget.alertThreshold * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Privacy Tab
class _PrivacyTab extends ConsumerStatefulWidget {
  final String householdId;

  const _PrivacyTab({required this.householdId});

  @override
  ConsumerState<_PrivacyTab> createState() => _PrivacyTabState();
}

class _PrivacyTabState extends ConsumerState<_PrivacyTab> {
  ShareScope? _transactionScope;
  ShareScope? _accountScope;
  Map<String, String> _categoryOverrides = {};
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
        if (prefs != null && _transactionScope == null) {
          _transactionScope = prefs.defaultTransactionShareScope;
          _accountScope = prefs.defaultAccountShareScope;
          _categoryOverrides = Map.from(prefs.perCategoryOverrides);
        } else if (_transactionScope == null) {
          // Default values
          _transactionScope = ShareScope.private;
          _accountScope = ShareScope.private;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Default Privacy Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Control who can see your financial data in this household',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),

            // Transaction Privacy
            _PrivacyOption(
              title: 'Transactions',
              description: 'Who can see your transactions by default',
              value: _formatShareScope(_transactionScope!),
              onTap: () => _showScopePicker(
                context,
                'Transaction Privacy',
                _transactionScope!,
                (scope) {
                  setState(() {
                    _transactionScope = scope;
                  });
                },
              ),
            ),

            // Account Privacy
            _PrivacyOption(
              title: 'Accounts',
              description: 'Who can see your account balances',
              value: _formatShareScope(_accountScope!),
              onTap: () => _showScopePicker(
                context,
                'Account Privacy',
                _accountScope!,
                (scope) {
                  setState(() {
                    _accountScope = scope;
                  });
                },
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Category Overrides',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set different privacy levels for specific categories',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),

            // Category overrides list
            if (_categoryOverrides.isNotEmpty) ...[
              ..._categoryOverrides.entries.map((entry) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(entry.key),
                    subtitle: Text(_formatShareScope(
                      ShareScope.values.firstWhere(
                        (s) => s.toJson() == entry.value,
                      ),
                    )),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: colorScheme.destructive),
                      onPressed: () {
                        setState(() {
                          _categoryOverrides.remove(entry.key);
                        });
                      },
                    ),
                    onTap: () => _showCategoryOverridePicker(context, entry.key, entry.value),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],

            shadcnui.OutlineButton(
              onPressed: () => _showAddCategoryOverride(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add),
                  SizedBox(width: 8),
                  Text('Add Category Override'),
                ],
              ),
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
                  : const Text('Save Privacy Settings'),
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
            defaultTransactionShareScope: _transactionScope,
            defaultAccountShareScope: _accountScope,
            perCategoryOverrides: _categoryOverrides,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Privacy settings saved successfully'),
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

  void _showScopePicker(
    BuildContext context,
    String title,
    ShareScope currentScope,
    Function(ShareScope) onSelected,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ShareScope.values.map((scope) {
            return RadioListTile<ShareScope>(
              title: Text(_formatShareScope(scope)),
              subtitle: Text(_getScopeDescription(scope)),
              value: scope,
              groupValue: currentScope,
              onChanged: (value) {
                if (value != null) {
                  onSelected(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAddCategoryOverride(BuildContext context) {
    final categoryController = TextEditingController();
    ShareScope selectedScope = ShareScope.household;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Category Override'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g., Groceries, Entertainment',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ShareScope>(
                value: selectedScope,
                decoration: const InputDecoration(labelText: 'Privacy Level'),
                items: ShareScope.values.map((scope) {
                  return DropdownMenuItem(
                    value: scope,
                    child: Text(_formatShareScope(scope)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() {
                      selectedScope = value;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (categoryController.text.trim().isNotEmpty) {
                  setState(() {
                    _categoryOverrides[categoryController.text.trim()] = selectedScope.toJson();
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryOverridePicker(BuildContext context, String category, String currentScope) {
    ShareScope scope = ShareScope.values.firstWhere((s) => s.toJson() == currentScope);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$category Privacy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ShareScope.values.map((s) {
            return RadioListTile<ShareScope>(
              title: Text(_formatShareScope(s)),
              subtitle: Text(_getScopeDescription(s)),
              value: s,
              groupValue: scope,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _categoryOverrides[category] = value.toJson();
                  });
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatShareScope(ShareScope scope) {
    switch (scope) {
      case ShareScope.private:
        return 'Private';
      case ShareScope.household:
        return 'Household';
      case ShareScope.custom:
        return 'Custom';
    }
  }

  String _getScopeDescription(ShareScope scope) {
    switch (scope) {
      case ShareScope.private:
        return 'Only you can see this';
      case ShareScope.household:
        return 'All household members can see this';
      case ShareScope.custom:
        return 'Selected members can see this';
    }
  }

  shadcnui.ColorScheme get colorScheme => shadcnui.Theme.of(context).colorScheme;
}

/// Privacy Option Widget
class _PrivacyOption extends StatelessWidget {
  final String title;
  final String description;
  final String value;
  final VoidCallback onTap;

  const _PrivacyOption({
    required this.title,
    required this.description,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        subtitle: Text(description),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(color: colorScheme.primary),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: colorScheme.mutedForeground),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

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
