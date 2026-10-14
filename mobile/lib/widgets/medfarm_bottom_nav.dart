import 'package:flutter/material.dart';

class MedFarmNavItem {
  const MedFarmNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Dark bottom navigation bar. The item at [raisedIndex] is drawn as a raised
/// circular button that sticks out above the bar.
class MedFarmBottomNav extends StatelessWidget {
  const MedFarmBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.raisedIndex,
  });

  final List<MedFarmNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int? raisedIndex;

  static const barColor = Color(0xFF1C1F1E);
  static const activeColor = Color(0xFF5BD38A);
  static const inactiveColor = Color(0xFFB4B9B6);
  static const raisedColor = Color(0xFF006239);

  static const _barHeight = 64.0;
  static const _overhang =
      22.0; // how far the raised button rises above the bar
  static const _raisedSize = 56.0;
  static const _labelBottomPadding = 10.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // The bar has a fixed height, so cap large system font sizes.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: SizedBox(
        height: _overhang + _barHeight + bottomInset,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _barHeight + bottomInset,
              child: const ColoredBox(color: barColor),
            ),
            Positioned.fill(
              bottom: bottomInset,
              child: Material(
                type: MaterialType.transparency,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: i == raisedIndex
                            ? _RaisedButton(
                                item: items[i],
                                selected: i == currentIndex,
                                onTap: () => onTap(i),
                              )
                            : _NavButton(
                                item: items[i],
                                selected: i == currentIndex,
                                onTap: () => onTap(i),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final MedFarmNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? MedFarmBottomNav.activeColor
        : MedFarmBottomNav.inactiveColor;

    return Padding(
      // Only the bar itself is tappable, not the space beside the raised button.
      padding: const EdgeInsets.only(top: MedFarmBottomNav._overhang),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: MedFarmBottomNav._labelBottomPadding,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  selected ? item.activeIcon : item.icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(height: 4),
                _NavLabel(item.label, color: color, selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RaisedButton extends StatelessWidget {
  const _RaisedButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final MedFarmNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      // The label under the circle is tappable too.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: MedFarmBottomNav._labelBottomPadding,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Material(
                color: MedFarmBottomNav.raisedColor,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: SizedBox.square(
                    dimension: MedFarmBottomNav._raisedSize,
                    child: Icon(item.icon, color: Colors.white, size: 26),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              _NavLabel(
                item.label,
                color: selected
                    ? MedFarmBottomNav.activeColor
                    : MedFarmBottomNav.inactiveColor,
                selected: selected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLabel extends StatelessWidget {
  const _NavLabel(this.text, {required this.color, required this.selected});

  final String text;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 12,
        height: 1.2,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}
