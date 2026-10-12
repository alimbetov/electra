from pathlib import Path

path = Path('apps/mobile/lib/features/editor/room_editor_screen.dart')
text = path.read_text()

wrong = '''    for (final component in components) {
      final center = mapPoint(component.localPosition);
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
      canvas.drawCircle(center, 8, paint);
      canvas.drawLine(
        center + const Offset(-6, 0),
        center + const Offset(6, 0),
        paint,
      );
      canvas.drawLine(
        center + const Offset(0, -6),
        center + const Offset(0, 6),
        paint,
      );
    }

'''
if text.count(wrong) != 1:
    raise SystemExit(f'Expected one misplaced component painter block, got {text.count(wrong)}')
text = text.replace(wrong, '', 1)

anchor = '''    for (final feature in features) {
      final selected =
          selection?.kind == EditorSelectionKind.spatialFeature &&
          selection?.id == feature.id;
      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 3 : 1;
      canvas.drawPath(polygonPath(feature.footprint), paint);
    }

'''
if text.count(anchor) != 1:
    raise SystemExit(f'Expected one painter feature anchor, got {text.count(anchor)}')
text = text.replace(anchor, anchor + wrong, 1)
path.write_text(text)
