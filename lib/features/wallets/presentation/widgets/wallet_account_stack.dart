import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/l10n/l10n.dart';
import 'package:moneko/core/ui/notifications/app_toast.dart';
import 'package:moneko/features/wallets/domain/entities/wallet.dart';
import 'package:moneko/features/wallets/presentation/providers/wallet_order_provider.dart';

typedef WalletStackCardBuilder = Widget Function(
  WalletEntity wallet,
  bool isExpanded,
);

/// Overlapping wallets with a permanently expanded final card.
class WalletAccountStack extends HookConsumerWidget {
  const WalletAccountStack({
    super.key,
    required this.wallets,
    required this.scope,
    required this.cardBuilder,
    required this.onOpenWallet,
  });

  final List<WalletEntity> wallets;
  final WalletOrderScope scope;
  final WalletStackCardBuilder cardBuilder;
  final ValueChanged<WalletEntity> onOpenWallet;

  static const tightSpacing = 70.0;
  static const expandedHeight = 240.0;
  static const collapsedHeight = 115.0;
  static const expandedGap = 20.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedIds = ref.watch(walletOrderProvider(scope));
    final selectedId = useState<String?>(null);
    final dragIds = useState<List<String>?>(null);
    final draggedId = useState<String?>(null);
    final dragAnchor = useRef(Offset.zero);
    final dragPosition = useRef<Offset?>(null);
    final stackKey = useMemoized(GlobalKey.new);
    final ordered = applyWalletOrder(
      wallets,
      dragIds.value ?? savedIds,
      (wallet) => wallet.id,
    );
    final isDragging = draggedId.value != null;
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);

    final expandedIndex = isDragging
        ? -1
        : ordered.indexWhere((wallet) => wallet.id == selectedId.value);
    final hasExtraExpanded =
        expandedIndex >= 0 && expandedIndex < ordered.length - 1;
    final tops = <double>[];
    var height = 0.0;
    for (var index = 0; index < ordered.length; index++) {
      tops.add(height);
      height += index == ordered.length - 1
          ? expandedHeight
          : hasExtraExpanded && index == expandedIndex
              ? expandedHeight + expandedGap
              : tightSpacing;
    }

    void updateDragOrder() {
      final position = dragPosition.value;
      final box = stackKey.currentContext?.findRenderObject();
      if (!context.mounted ||
          position == null ||
          box is! RenderBox ||
          ordered.isEmpty) {
        return;
      }
      final top = box.globalToLocal(position).dy - dragAnchor.value.dy;
      final target = (top / tightSpacing).round().clamp(0, ordered.length - 1);
      final ids = [...dragIds.value ?? ordered.map((wallet) => wallet.id)];
      final current = ids.indexOf(draggedId.value ?? '');
      if (current < 0 || current == target) return;
      final id = ids.removeAt(current);
      ids.insert(target, id);
      dragIds.value = ids;
    }

    final latestDragUpdate = useRef<VoidCallback>(() {});
    final scrollable = Scrollable.maybeOf(context);
    final autoScroller = useMemoized(
      () => scrollable == null
          ? null
          : EdgeDraggingAutoScroller(
              scrollable,
              velocityScalar: 12,
              onScrollViewScrolled: () => latestDragUpdate.value(),
            ),
      [scrollable, scope],
    );
    latestDragUpdate.value = () {
      if (!context.mounted) return;
      updateDragOrder();
      final position = dragPosition.value;
      if (position != null) {
        autoScroller?.startAutoScrollIfNecessary(
          Rect.fromCenter(center: position, width: 1, height: 80),
        );
      }
    };
    useEffect(() => () => autoScroller?.stopAutoScroll(), [autoScroller]);

    Future<void> saveOrder(List<String> ids) async {
      try {
        await ref.read(walletOrderProvider(scope).notifier).reorder(ids);
      } catch (_) {
        if (context.mounted) {
          AppToast.error(context, context.l10n.walletOrderSaveFailed);
        }
      }
    }

    void finishDrag() {
      autoScroller?.stopAutoScroll();
      final ids = dragIds.value;
      draggedId.value = null;
      dragIds.value = null;
      dragPosition.value = null;
      if (ids != null) unawaited(saveOrder(ids));
    }

    void moveWallet(int index, int target) {
      final ids = ordered.map((wallet) => wallet.id).toList();
      ids.insert(target, ids.removeAt(index));
      unawaited(saveOrder(ids));
    }

    return LayoutBuilder(builder: (context, constraints) {
      return AnimatedContainer(
        key: stackKey,
        height: height,
        duration: animationDuration,
        curve: Curves.easeInOutCubic,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < ordered.length; index++)
              AnimatedPositioned(
                key: ValueKey(ordered[index].id),
                top: tops[index],
                left: 0,
                right: 0,
                height: index == ordered.length - 1 ||
                        (hasExtraExpanded && index == expandedIndex)
                    ? expandedHeight
                    : collapsedHeight,
                duration: animationDuration,
                curve: Curves.easeInOutCubic,
                child: Builder(builder: (context) {
                  final wallet = ordered[index];
                  final expanded = index == ordered.length - 1 ||
                      (hasExtraExpanded && index == expandedIndex);
                  final card = cardBuilder(wallet, expanded);
                  return Semantics(
                    customSemanticsActions: {
                      if (index > 0)
                        CustomSemanticsAction(
                          label: WidgetsLocalizations.of(context).reorderItemUp,
                        ): () => moveWallet(index, index - 1),
                      if (index < ordered.length - 1)
                        CustomSemanticsAction(
                          label:
                              WidgetsLocalizations.of(context).reorderItemDown,
                        ): () => moveWallet(index, index + 1),
                    },
                    child: LongPressDraggable<String>(
                      data: wallet.id,
                      axis: Axis.vertical,
                      maxSimultaneousDrags: ordered.length > 1 &&
                              (!isDragging || draggedId.value == wallet.id)
                          ? 1
                          : 0,
                      dragAnchorStrategy: (draggable, context, position) {
                        final box = context.findRenderObject()! as RenderBox;
                        dragAnchor.value = box.globalToLocal(position);
                        return dragAnchor.value;
                      },
                      onDragStarted: () {
                        selectedId.value = null;
                        dragIds.value =
                            ordered.map((wallet) => wallet.id).toList();
                        draggedId.value = wallet.id;
                      },
                      onDragUpdate: (details) {
                        dragPosition.value = details.globalPosition;
                        latestDragUpdate.value();
                      },
                      onDragEnd: (_) => finishDrag(),
                      feedback: SizedBox(
                        width: constraints.maxWidth,
                        height: collapsedHeight,
                        child: Material(
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0),
                          child: cardBuilder(wallet, false),
                        ),
                      ),
                      childWhenDragging: Opacity(opacity: 0.3, child: card),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (expanded) {
                            onOpenWallet(wallet);
                          } else {
                            selectedId.value = wallet.id;
                          }
                        },
                        child: card,
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      );
    });
  }
}
