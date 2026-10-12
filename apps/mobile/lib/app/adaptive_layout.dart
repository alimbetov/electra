import 'package:flutter/widgets.dart';

enum ElectraSizeClass {
  compact,
  medium,
  expanded,
}

class ElectraBreakpoints {
  const ElectraBreakpoints._();

  static const double compactMaxExclusive = 700;
  static const double mediumMaxExclusive = 1100;

  static ElectraSizeClass fromWidth(double width) {
    if (width < compactMaxExclusive) {
      return ElectraSizeClass.compact;
    }
    if (width < mediumMaxExclusive) {
      return ElectraSizeClass.medium;
    }
    return ElectraSizeClass.expanded;
  }
}

class ElectraLayoutInfo {
  const ElectraLayoutInfo({
    required this.sizeClass,
    required this.availableWidth,
    required this.availableHeight,
  });

  final ElectraSizeClass sizeClass;
  final double availableWidth;
  final double availableHeight;

  bool get isCompact => sizeClass == ElectraSizeClass.compact;
  bool get isMedium => sizeClass == ElectraSizeClass.medium;
  bool get isExpanded => sizeClass == ElectraSizeClass.expanded;

  bool get showsPersistentContextPanel => !isCompact;
  bool get allowsProjectNavigator => isExpanded;
}

class ElectraAdaptiveBuilder extends StatelessWidget {
  const ElectraAdaptiveBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, ElectraLayoutInfo layout) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return builder(
          context,
          ElectraLayoutInfo(
            sizeClass: ElectraBreakpoints.fromWidth(width),
            availableWidth: width,
            availableHeight: height,
          ),
        );
      },
    );
  }
}
