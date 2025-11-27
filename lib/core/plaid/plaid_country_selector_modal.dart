import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:moneko/core/plaid/plaid_countries.dart';
import 'package:moneko/core/plaid/plaid_country_flags.dart';
import 'package:moneko/core/navigation/main_menu_screen.dart';
import 'package:moneko/core/theme/app_theme.dart';

Future<String?> showPlaidCountrySelectorModal(
  BuildContext context,
  WidgetRef ref,
) async {
  final initialCode = ref.read(plaidCountryCodeProvider);
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PlaidCountrySelectorScreen(initialCode: initialCode),
    ),
  );
}

class PlaidCountrySelectorScreen extends ConsumerStatefulWidget {
  const PlaidCountrySelectorScreen({
    super.key,
    required this.initialCode,
  });

  final String initialCode;

  @override
  ConsumerState<PlaidCountrySelectorScreen> createState() =>
      _PlaidCountrySelectorScreenState();
}

class _PlaidCountrySelectorScreenState
    extends ConsumerState<PlaidCountrySelectorScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final query = _searchQuery.trim().toLowerCase();
    final options = plaidCountryOptions.where((option) {
      if (query.isEmpty) return true;
      final label = option.label.toLowerCase();
      final code = option.code.toLowerCase();
      return label.contains(query) || code.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: colorScheme.appBackground,
      appBar: AppBar(
        backgroundColor: colorScheme.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.foreground),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: Text(
          'Select country',
          style: TextStyle(
            color: colorScheme.foreground,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.search,
                    color: colorScheme.mutedForeground,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: colorScheme.mutedForeground,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  hintText: 'Search country',
                  filled: true,
                  fillColor: colorScheme.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option.code == widget.initialCode;
                  final flagPath = getPlaidCountryFlagPath(option.code);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(context, option.code);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.border
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    flagPath,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option.label,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.foreground,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      option.code,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
