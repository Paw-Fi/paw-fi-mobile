import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/utils/currency.dart';
import 'package:moneko/features/utils/currency_display_names.dart';
import 'package:moneko/features/utils/currency_flags.dart';

class ManageCurrenciesSheet extends StatefulWidget {
  const ManageCurrenciesSheet({
    required this.allCodes,
    required this.currentShown,
    super.key,
  });

  final List<String> allCodes;
  final List<String> currentShown;

  @override
  State<ManageCurrenciesSheet> createState() => _ManageCurrenciesSheetState();
}

class _ManageCurrenciesSheetState extends State<ManageCurrenciesSheet> {
  late Set<String> _selectedCodes;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCodes = Set<String>.from(widget.currentShown.where(_isDisplayableCurrency));
    if (_selectedCodes.isEmpty) {
      for (final code in widget.allCodes) {
        if (_isDisplayableCurrency(code)) {
          _selectedCodes.add(code);
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isDisplayableCurrency(String code) {
    return currencyOptions.containsKey(code) && getCurrencyFlagPath(code) != null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final displayableCodes = widget.allCodes.where(_isDisplayableCurrency).toList();

    final query = _searchQuery.trim().toLowerCase();
    final filteredCodes = displayableCodes.where((code) {
      final name = resolveCurrencyDisplayName(code).toLowerCase();
      final lowerCode = code.toLowerCase();
      return lowerCode.contains(query) || name.contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: colorScheme.mutedForeground,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        size: 18,
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
              hintText: context.l10n.searchCurrencies,
              filled: true,
              fillColor: colorScheme.brightness == Brightness.dark
                  ? colorScheme.muted.withValues(alpha: 0.15)
                  : colorScheme.muted.withValues(alpha: 0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: filteredCodes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: colorScheme.mutedForeground.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.noCurrenciesMatchSearch,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredCodes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final code = filteredCodes[index];
                        final isSelected = _selectedCodes.contains(code);
                        final flagPath = getCurrencyFlagPath(code);
                        final name = resolveCurrencyDisplayName(code);
                        final symbol = resolveCurrencySymbol(code);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (isSelected) {
                                  if (_selectedCodes.length > 1) {
                                    _selectedCodes.remove(code);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('At least one currency must be visible.'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } else {
                                  _selectedCodes.add(code);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colorScheme.outline.withValues(alpha: 0.08),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: flagPath != null
                                          ? Image.asset(
                                              flagPath,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  _buildSymbolFallback(colorScheme, symbol),
                                            )
                                          : _buildSymbolFallback(colorScheme, symbol),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          code,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.foreground,
                                          ),
                                        ),
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: colorScheme.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 150),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check_circle_rounded,
                                            key: const ValueKey('selected'),
                                            color: colorScheme.primary,
                                            size: 24,
                                          )
                                        : Icon(
                                            Icons.radio_button_unchecked_rounded,
                                            key: const ValueKey('unselected'),
                                            color: colorScheme.mutedForeground.withValues(alpha: 0.6),
                                            size: 24,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 16 + bottomPadding),
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop(_selectedCodes.toList());
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                context.l10n.saveVisibleCurrencies,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolFallback(ColorScheme colorScheme, String symbol) {
    return Container(
      color: colorScheme.muted,
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
