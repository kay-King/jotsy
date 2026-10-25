import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/app_effects.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';

/// 桌面页的白卡：与探索页卡片同一套面（圆角 24、白底、浅边框、微投影），
/// 点按时整张卡有墨水高亮。
class DesktopCard extends StatelessWidget {
  const DesktopCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppEffects.restingCardShadow(colorScheme),
      ),
      child: Card.filled(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: ExpressiveSurfaces.cardBorderSide(colorScheme),
        ),
        color: ExpressiveSurfaces.cardColor(colorScheme),
        clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
        child: onTap == null
            ? Padding(padding: const EdgeInsets.all(18), child: child)
            : InkWell(
                onTap: onTap,
                child: Padding(padding: const EdgeInsets.all(18), child: child),
              ),
      ),
    );
  }
}
