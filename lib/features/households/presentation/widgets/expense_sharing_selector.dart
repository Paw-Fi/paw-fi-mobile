import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/auth/auth.dart';
import 'package:moneko/shared/widgets/outlined_adaptive_button.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';

import '../../domain/entities/shared_budget.dart' show ShareScope;
import '../../../../../core/l10n/l10n.dart';
import '../providers/household_providers.dart';

/// Widget for selecting expense sharing scope and members
class ExpenseSharingSelector extends ConsumerStatefulWidget {
  final ShareScope selectedScope;
  final String? selectedHouseholdId;
  final List<String>? selectedMemberIds;
  final Function(ShareScope scope, String? householdId, List<String>? memberIds)
      onChanged;

  const ExpenseSharingSelector({
    super.key,
    required this.selectedScope,
    this.selectedHouseholdId,
    this.selectedMemberIds,
    required this.onChanged,
  });

  @override
  ConsumerState<ExpenseSharingSelector> createState() =>
      _ExpenseSharingSelectorState();
}

class _ExpenseSharingSelectorState
    extends ConsumerState<ExpenseSharingSelector> {
  late ShareScope _scope;
  String? _householdId;
  List<String> _memberIds = [];

  @override
  void initState() {
    super.initState();
    _scope = widget.selectedScope;
    _householdId = widget.selectedHouseholdId;
    _memberIds = widget.selectedMemberIds ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userId = ref.watch(currentUserIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.whoCanSeeThisExpense,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 12),

        // Sharing scope selector
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _SharingScopeOption(
                title: context.l10n.privacyPrivate,
                subtitle: context.l10n.onlyVisibleToYou,
                icon: Icons.lock,
                isSelected: _scope == ShareScope.private,
                onTap: () {
                  setState(() {
                    _scope = ShareScope.private;
                    _householdId = null;
                    _memberIds = [];
                  });
                  widget.onChanged(_scope, _householdId, _memberIds);
                },
              ),
              Divider(height: 1, color: colorScheme.border),
              _SharingScopeOption(
                title: context.l10n.household,
                subtitle: context.l10n.sharedWithAllHouseholdMembers,
                icon: Icons.people,
                isSelected: _scope == ShareScope.household,
                onTap: () {
                  setState(() {
                    _scope = ShareScope.household;
                    _memberIds = [];
                  });
                  widget.onChanged(_scope, _householdId, _memberIds);
                },
              ),
              Divider(height: 1, color: colorScheme.border),
              _SharingScopeOption(
                title: context.l10n.custom,
                subtitle: context.l10n.chooseSpecificMembers,
                icon: Icons.tune,
                isSelected: _scope == ShareScope.custom,
                onTap: () {
                  setState(() {
                    _scope = ShareScope.custom;
                  });
                  widget.onChanged(_scope, _householdId, _memberIds);
                },
              ),
            ],
          ),
        ),

        // Household selector (for household and custom scopes)
        if (_scope != ShareScope.private) ...[
          const SizedBox(height: 16),
          if (userId != null)
            Builder(builder: (context) {
              final householdsAsync = ref.watch(userHouseholdsProvider(userId));
              return householdsAsync.when(
                data: (households) {
                  if (households.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.muted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        context.l10n.noHouseholdsAvailableCreateOrJoin,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.mutedForeground,
                        ),
                      ),
                    );
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: _householdId,
                    decoration: InputDecoration(
                      labelText: context.l10n.selectHousehold,
                      border: const OutlineInputBorder(),
                    ),
                    items: households.map((household) {
                      return DropdownMenuItem(
                        value: household.id,
                        child: Text(household.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _householdId = value;
                        _memberIds = [];
                      });
                      widget.onChanged(_scope, _householdId, _memberIds);
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text(
                  context.l10n.errorLoadingHouseholds,
                  style: TextStyle(color: colorScheme.destructive),
                ),
              );
            })
          else
            const SizedBox.shrink(),
        ],

        // Member selector (for custom scope only)
        if (_scope == ShareScope.custom && _householdId != null) ...[
          const SizedBox(height: 16),
          OutlinedAdaptiveButton(
            onPressed: () => _showMemberPicker(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_add, size: 20),
                const SizedBox(width: 8),
                Text(_memberIds.isEmpty
                    ? context.l10n.selectMembers
                    : context.l10n.membersSelectedCount(_memberIds.length)),
              ],
            ),
          ),
          if (_memberIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSelectedMembers(colorScheme),
          ],
        ],
      ],
    );
  }

  Widget _buildSelectedMembers(colorScheme) {
    if (_householdId == null) return const SizedBox.shrink();

    final membersAsync = ref.watch(householdMembersProvider(_householdId!));
    return membersAsync.when(
      data: (members) {
        final selectedMembers =
            members.where((m) => _memberIds.contains(m.userId)).toList();

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selectedMembers.map((member) {
            return Chip(
              label: Text(
                  member.userId), // In real app, fetch user name from profiles
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                setState(() {
                  _memberIds.remove(member.userId);
                });
                widget.onChanged(_scope, _householdId, _memberIds);
              },
            );
          }).toList(),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showMemberPicker(BuildContext context) {
    if (_householdId == null) return;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (context) => _MemberPickerSheet(
        householdId: _householdId!,
        selectedMemberIds: _memberIds,
        onSelectionChanged: (members) {
          if (mounted) {
            setState(() {
              _memberIds = members;
            });
            widget.onChanged(_scope, _householdId, _memberIds);
          }
        },
      ),
    );
  }
}

class _SharingScopeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SharingScopeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.mutedForeground,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberPickerSheet extends ConsumerStatefulWidget {
  final String householdId;
  final List<String> selectedMemberIds;
  final Function(List<String>) onSelectionChanged;

  const _MemberPickerSheet({
    required this.householdId,
    required this.selectedMemberIds,
    required this.onSelectionChanged,
  });

  @override
  ConsumerState<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends ConsumerState<_MemberPickerSheet> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.selectedMemberIds);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final membersAsync =
        ref.watch(householdMembersProvider(widget.householdId));

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.selectMembers,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: membersAsync.when(
              data: (members) {
                if (members.isEmpty) {
                  return Center(
                    child: Text(
                      context.l10n.noMembersFound,
                      style: TextStyle(color: colorScheme.mutedForeground),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isSelected = _selectedIds.contains(member.userId);

                    return CheckboxListTile(
                      title:
                          Text(member.userId), // In real app, fetch user name
                      subtitle: Text(
                          member.role.toString().split('.').last.toUpperCase()),
                      value: isSelected,
                      onChanged: (bool? selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedIds.add(member.userId);
                          } else {
                            _selectedIds.remove(member.userId);
                          }
                        });
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  '${context.l10n.error}: $error',
                  style: TextStyle(color: colorScheme.destructive),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PrimaryAdaptiveButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryAdaptiveButton(
                  onPressed: () {
                    widget.onSelectionChanged(_selectedIds.toList());
                    Navigator.pop(context);
                  },
                  child: Text(context.l10n.done),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
