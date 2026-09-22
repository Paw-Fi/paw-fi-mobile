import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:moneko/core/theme/app_theme.dart';
import 'package:moneko/features/home/presentation/constants/category_constants.dart';
import 'package:moneko/shared/widgets/merchant_logo.dart';
import 'package:moneko/shared/widgets/primary_adaptive_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantSelection {
  const MerchantSelection.customText(this.merchant)
      : descriptor = null,
        merchantName = null,
        merchantId = null,
        merchantDomain = null,
        allowsStructuredLearning = false;

  const MerchantSelection.identity({
    required this.descriptor,
    required this.merchantName,
    required this.merchantId,
    required this.merchantDomain,
    required this.allowsStructuredLearning,
  }) : merchant = null;

  final String? merchant;
  final String? descriptor;
  final String? merchantName;
  final String? merchantId;
  final String? merchantDomain;
  final bool allowsStructuredLearning;

  bool get isCustomText => merchant != null;
}

class MerchantSearchCandidate {
  const MerchantSearchCandidate({
    required this.name,
    required this.domain,
    required this.source,
    this.id,
  });

  final String name;
  final String domain;
  final String source;
  final String? id;

  factory MerchantSearchCandidate.fromJson(Map<String, dynamic> json) {
    return MerchantSearchCandidate(
      name: json['name']?.toString().trim() ?? '',
      domain: json['domain']?.toString().trim().toLowerCase() ?? '',
      source: json['source']?.toString() ?? 'logo_dev',
      id: json['id']?.toString(),
    );
  }
}

Future<MerchantSelection?> showMerchantSelectionPage({
  required BuildContext context,
  required String title,
  required String category,
  required String initialQuery,
  List<MerchantSearchCandidate> initialCandidates = const [],
}) {
  return Navigator.of(context).push<MerchantSelection>(
    MaterialPageRoute(
      requestFocus: false,
      builder: (_) => MerchantSelectionPage(
        title: title,
        category: category,
        initialQuery: initialQuery,
        initialCandidates: initialCandidates,
      ),
    ),
  );
}

class MerchantSelectionPage extends StatefulWidget {
  const MerchantSelectionPage({
    super.key,
    required this.title,
    required this.category,
    required this.initialQuery,
    required this.initialCandidates,
  });

  final String title;
  final String category;
  final String initialQuery;
  final List<MerchantSearchCandidate> initialCandidates;

  @override
  State<MerchantSelectionPage> createState() => _MerchantSelectionPageState();
}

class _MerchantSelectionPageState extends State<MerchantSelectionPage> {
  late final TextEditingController _queryController;
  late final FocusNode _queryFocusNode;
  Animation<double>? _routeAnimation;
  bool _hasRequestedInitialFocus = false;
  Timer? _debounce;
  String _lastSearchedQuery = '';
  List<MerchantSearchCandidate> _candidates = const [];
  MerchantSearchCandidate? _selectedCandidate;
  bool _isLoading = false;
  bool _hasCompletedSearch = false;
  bool _isConfirming = false;
  String? _error;
  int _searchVersion = 0;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _queryFocusNode = FocusNode();
    _candidates = widget.initialCandidates;
    _hasCompletedSearch = widget.initialCandidates.isNotEmpty;
    _lastSearchedQuery =
        widget.initialCandidates.isNotEmpty ? widget.initialQuery.trim() : '';
    _queryController.addListener(_onQueryChanged);
    if (_candidates.isEmpty && _queryController.text.trim().isNotEmpty) {
      _search();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (identical(_routeAnimation, routeAnimation)) return;

    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _routeAnimation = routeAnimation;
    if (routeAnimation == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _requestInitialFocus());
      return;
    }

    routeAnimation.addStatusListener(_handleRouteAnimationStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (routeAnimation.status == AnimationStatus.completed) {
        _handleRouteAnimationStatus(AnimationStatus.completed);
      }
    });
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _requestInitialFocus();
  }

  void _requestInitialFocus() {
    if (!mounted || _hasRequestedInitialFocus) return;
    _hasRequestedInitialFocus = true;
    _queryFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _queryFocusNode.dispose();
    _queryController
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _selectedCandidate = null;
        _candidates = const [];
        _error = null;
        _isLoading = false;
        _hasCompletedSearch = false;
        _lastSearchedQuery = '';
      });
      return;
    }

    if (query == _lastSearchedQuery) return;

    setState(() {
      _selectedCandidate = null;
      _error = null;
      _isLoading = true;
      _hasCompletedSearch = false;
      _candidates = const [];
    });

    _debounce = Timer(const Duration(milliseconds: 500), _search);
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasCompletedSearch = false;
        _candidates = const [];
      });
      return;
    }

    _lastSearchedQuery = query;
    final version = ++_searchVersion;
    setState(() {
      _isLoading = true;
      _hasCompletedSearch = false;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'merchant-user-search',
        body: {'action': 'search', 'query': query},
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      if (!mounted || version != _searchVersion) return;
      if (data['success'] != true) throw StateError('Merchant search failed');
      final candidates = (data['candidates'] as List? ?? const [])
          .whereType<Map>()
          .map((item) =>
              MerchantSearchCandidate.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.name.isNotEmpty && item.domain.isNotEmpty)
          .toList(growable: false);
      setState(() => _candidates = candidates);
    } catch (_) {
      if (mounted && version == _searchVersion) {
        setState(() => _error = 'Unable to search merchants. Try again.');
      }
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() {
          _isLoading = false;
          _hasCompletedSearch = true;
        });
      }
    }
  }

  Future<void> _confirm() async {
    final selected = _selectedCandidate;
    final query = _queryController.text.trim();
    if (selected == null || query.isEmpty || _isConfirming) return;
    if (selected.source == 'custom') {
      Navigator.of(context).pop(MerchantSelection.customText(query));
      return;
    }
    setState(() {
      _isConfirming = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'merchant-user-search',
        body: {
          'action': 'resolve',
          'query': query,
          'selectedName': selected.name,
          'selectedDomain': selected.domain,
          'selectedSource': selected.source,
          'selectedMerchantId': selected.id,
        },
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : const <String, dynamic>{};
      final merchant = data['merchant'] is Map
          ? Map<String, dynamic>.from(data['merchant'] as Map)
          : null;
      final merchantId = merchant?['id']?.toString();
      final merchantDomain = merchant?['domain']?.toString();
      if (data['success'] != true ||
          merchantId == null ||
          merchantDomain == null) {
        throw StateError('Merchant selection failed');
      }
      if (mounted) {
        Navigator.of(context).pop(MerchantSelection.identity(
          descriptor: query,
          merchantName: merchant?['canonical_name']?.toString(),
          merchantId: merchantId,
          merchantDomain: merchantDomain,
          allowsStructuredLearning: data['allowStructuredLearning'] == true,
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to save this merchant. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _clearQuery() {
    _debounce?.cancel();
    _queryController.clear();
    setState(() {
      _selectedCandidate = null;
      _candidates = const [];
      _error = null;
      _isLoading = false;
      _hasCompletedSearch = false;
      _lastSearchedQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final query = _queryController.text.trim();

    final categoryColor = AppTheme.adaptCategoryColorForTheme(
      getCategoryColor(widget.category, context),
      colorScheme,
    );
    final fallback = _CategoryFallbackIcon(
      icon: getCategoryIcon(widget.category),
      color: categoryColor,
    );

    final customCandidate = MerchantSearchCandidate(
      name: query,
      domain: '',
      source: 'custom',
    );
    final showCustomOption =
        _hasCompletedSearch && !_isLoading && query.isNotEmpty;
    final candidates = [
      ..._candidates,
      if (showCustomOption) customCandidate,
    ];

    return AdaptiveScaffold(
      body: Material(
        color: colorScheme.appBackground,
        child: SafeArea(
          child: Column(
            children: [
              _MerchantSelectionHeader(
                title: widget.title,
                canConfirm: _selectedCandidate != null,
                isConfirming: _isConfirming,
                onClose: () => Navigator.of(context).pop(),
                onConfirm: _confirm,
              ),
              _MerchantSearchBar(
                controller: _queryController,
                focusNode: _queryFocusNode,
                isLoading: _isLoading,
                onSubmitted: (_) => _search(),
                onClear: _clearQuery,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.errorSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colorScheme.errorBorder,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: colorScheme.errorAccent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: colorScheme.destructive,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: query.isEmpty
                    ? _MerchantEmptyState(
                        categoryIcon: getCategoryIcon(widget.category),
                        categoryColor: categoryColor,
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          if (_isLoading && _candidates.isEmpty)
                            _MerchantLoadingSkeleton(isDark: isDark)
                          else if (candidates.isNotEmpty) ...[
                            const _SectionHeader(title: 'Results'),
                            _GroupedCard(
                              isDark: isDark,
                              colorScheme: colorScheme,
                              children: [
                                for (var i = 0; i < candidates.length; i++) ...[
                                  _MerchantCandidateTile(
                                    candidate: candidates[i],
                                    isSelected: candidates[i].source == 'custom'
                                        ? _selectedCandidate?.source == 'custom'
                                        : identical(
                                            candidates[i],
                                            _selectedCandidate,
                                          ),
                                    fallback: fallback,
                                    onTap: () => setState(
                                      () => _selectedCandidate = candidates[i],
                                    ),
                                  ),
                                  if (i < candidates.length - 1)
                                    const _HairlineSeparator(indent: 68),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
              ),
              if (_selectedCandidate != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: BoxDecoration(
                    color: colorScheme.appBackground,
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.surfaceBorder,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: PrimaryAdaptiveButton(
                    onPressed: _isConfirming ? null : _confirm,
                    isExpanded: true,
                    child: _isConfirming
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _selectedCandidate!.source == 'custom'
                                ? 'Use Custom Name'
                                : 'Select ${_selectedCandidate!.name}',
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MerchantSelectionHeader extends StatelessWidget {
  const _MerchantSelectionHeader({
    required this.title,
    required this.canConfirm,
    required this.isConfirming,
    required this.onClose,
    required this.onConfirm,
  });

  final String title;
  final bool canConfirm;
  final bool isConfirming;
  final VoidCallback onClose;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        minHeight: 56,
        maxHeight: MediaQuery.textScalerOf(context).scale(16) > 20
            ? double.infinity
            : 56,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: 'Close',
              padding: EdgeInsets.zero,
              onPressed: isConfirming ? null : onClose,
              icon: Icon(
                Icons.close_rounded,
                size: 22,
                color: colorScheme.foreground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.foreground,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: canConfirm ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: isConfirming
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: canConfirm ? onConfirm : null,
                        child: Text(
                          'Done',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantSearchBar extends StatelessWidget {
  const _MerchantSearchBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: BorderRadius.circular(10),
          border: isDark
              ? Border.all(color: colorScheme.surfaceBorder, width: 0.5)
              : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: onSubmitted,
          style: TextStyle(
            color: colorScheme.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: 'Search by name or domain',
            hintStyle: TextStyle(
              color: colorScheme.mutedForeground,
              fontSize: 15,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: colorScheme.mutedForeground,
            ),
            suffixIcon: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                : controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.cancel_rounded,
                          size: 18,
                          color: colorScheme.mutedForeground
                              .withValues(alpha: 0.7),
                        ),
                        onPressed: onClear,
                      )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colorScheme.mutedForeground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _GroupedCard extends StatelessWidget {
  const _GroupedCard({
    required this.isDark,
    required this.colorScheme,
    required this.children,
  });

  final bool isDark;
  final ColorScheme colorScheme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(10),
        border: isDark
            ? Border.all(color: colorScheme.surfaceBorder, width: 0.5)
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _HairlineSeparator extends StatelessWidget {
  const _HairlineSeparator({required this.indent});

  final double indent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: colorScheme.outlineVariant.withValues(alpha: 0.25),
      ),
    );
  }
}

class _MerchantCandidateTile extends StatelessWidget {
  const _MerchantCandidateTile({
    required this.candidate,
    required this.isSelected,
    required this.fallback,
    required this.onTap,
  });

  final MerchantSearchCandidate candidate;
  final bool isSelected;
  final Widget fallback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCustom = candidate.source == 'custom';

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCustom
                      ? colorScheme.surface.withValues(alpha: 0.0)
                      : colorScheme.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: isCustom
                      ? null
                      : Border.all(
                          color: colorScheme.surfaceBorder,
                          width: 0.5,
                        ),
                ),
                clipBehavior: Clip.antiAlias,
                child: isCustom
                    ? fallback
                    : MerchantCandidateLogo(
                        domain: candidate.domain,
                        fallback: fallback,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      style: TextStyle(
                        color: colorScheme.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (!isCustom) ...[
                          Icon(
                            Icons.verified_rounded,
                            size: 13,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            isCustom
                                ? 'Keep query as custom text entry'
                                : candidate.domain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.mutedForeground,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surface.withValues(alpha: 0.0),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.controlBorder,
                    width: isSelected ? 0 : 1.5,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: colorScheme.primaryForeground,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFallbackIcon extends StatelessWidget {
  const _CategoryFallbackIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _MerchantEmptyState extends StatelessWidget {
  const _MerchantEmptyState({
    required this.categoryIcon,
    required this.categoryColor,
  });

  final IconData categoryIcon;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.surfaceBorder,
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.storefront_outlined,
                  size: 32,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Search Merchant Identity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Type a merchant name or domain to automatically match official logos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.mutedForeground,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchantLoadingSkeleton extends StatelessWidget {
  const _MerchantLoadingSkeleton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shimmerColor = colorScheme.onSurface.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.card,
        borderRadius: BorderRadius.circular(10),
        border: isDark
            ? Border.all(color: colorScheme.surfaceBorder, width: 0.5)
            : null,
      ),
      child: Column(
        children: List.generate(
          3,
          (index) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 14,
                            decoration: BoxDecoration(
                              color: shimmerColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 80,
                            height: 11,
                            decoration: BoxDecoration(
                              color: shimmerColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (index < 2)
                Padding(
                  padding: const EdgeInsets.only(left: 68),
                  child: Divider(
                    height: 1,
                    thickness: 0.5,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
