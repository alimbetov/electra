from pathlib import Path

path = Path('apps/mobile/lib/application/engineering_reference_adoption_repository.dart')
text = path.read_text()

needle = "const engineeringReferenceAdoptionCompletedStatus = 'ADOPTION_COMPLETED';\n\nfinal class EngineeringReferenceAdoptionCommand {"
replacement = """const engineeringReferenceAdoptionCompletedStatus = 'ADOPTION_COMPLETED';

String _canonicalAdoptionPortCode(String value) => value.trim().toUpperCase();

List<String> _explicitPortMappingValidationErrors(
  Map<String, String> rawMappings,
) {
  final errors = <String>[];
  final sources = <String>{};
  final targets = <String>{};
  for (final entry in rawMappings.entries) {
    final source = _canonicalAdoptionPortCode(entry.key);
    final target = _canonicalAdoptionPortCode(entry.value);
    if (!sources.add(source)) {
      errors.add('Duplicate normalized explicit mapping source code: $source.');
    }
    if (!targets.add(target)) {
      errors.add('Duplicate normalized explicit mapping target code: $target.');
    }
  }
  return errors;
}

final class EngineeringReferenceAdoptionCommand {"""
assert needle in text
text = text.replace(needle, replacement, 1)

needle = """       reviewedTopologyGroupIds = List.unmodifiable(
         reviewedTopologyGroupIds.toSet().toList()..sort(),
       ),
       explicitPortMappings = Map.unmodifiable({
         for (final entry in explicitPortMappings.entries)
           entry.key.trim().toUpperCase(): entry.value.trim().toUpperCase(),
       });"""
replacement = """       reviewedTopologyGroupIds = List.unmodifiable(
         reviewedTopologyGroupIds.toSet().toList()..sort(),
       ),
       _explicitPortMappingErrors = List.unmodifiable(
         _explicitPortMappingValidationErrors(explicitPortMappings),
       ),
       explicitPortMappings = Map.unmodifiable({
         for (final entry in explicitPortMappings.entries)
           _canonicalAdoptionPortCode(entry.key):
               _canonicalAdoptionPortCode(entry.value),
       });"""
assert needle in text
text = text.replace(needle, replacement, 1)

needle = "  final Map<String, String> explicitPortMappings;\n\n  List<String> validate() => ["
replacement = """  final Map<String, String> explicitPortMappings;
  final List<String> _explicitPortMappingErrors;

  List<String> validate() => [
    ..._explicitPortMappingErrors,"""
assert needle in text
text = text.replace(needle, replacement, 1)

path.write_text(text)
