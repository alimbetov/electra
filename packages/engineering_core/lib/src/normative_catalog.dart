enum NormativeDocumentKind { standard, guidance, projectPolicy }

enum NormativeCriterion { overcurrentRange, breakingCapacity }

class NormativeDocument {
  NormativeDocument(
      {required this.id,
      required this.standardCode,
      required this.title,
      required this.version,
      required this.jurisdiction,
      required this.publisher,
      required this.source,
      required this.kind,
      Iterable<NormativeCriterion> criteria = const [],
      this.clauseReference = '',
      this.notes = ''})
      : criteria = List.unmodifiable(criteria.toSet().toList()
          ..sort((a, b) => a.name.compareTo(b.name)));
  final String id,
      standardCode,
      title,
      version,
      jurisdiction,
      publisher,
      source,
      clauseReference,
      notes;
  final NormativeDocumentKind kind;
  final List<NormativeCriterion> criteria;
  bool get supportsPlanner =>
      criteria.contains(NormativeCriterion.overcurrentRange) &&
      criteria.contains(NormativeCriterion.breakingCapacity);
  List<String> validate() => [
        if ([id, standardCode, title, version, jurisdiction, publisher, source]
            .any((v) => v.trim().isEmpty))
          'Document identity, edition, jurisdiction, publisher and source are required.',
        if (criteria.isNotEmpty && clauseReference.trim().isEmpty)
          'Executable criteria require a clause or section reference.',
      ];
  Map<String, Object?> toMap() => {
        'id': id,
        'standardCode': standardCode,
        'title': title,
        'version': version,
        'jurisdiction': jurisdiction,
        'publisher': publisher,
        'source': source,
        'kind': kind.name,
        'criteria': criteria.map((c) => c.name).toList(),
        'clauseReference': clauseReference,
        'notes': notes,
      };
  factory NormativeDocument.fromMap(Map<String, dynamic> m) =>
      NormativeDocument(
          id: m['id'] as String,
          standardCode: m['standardCode'] as String,
          title: m['title'] as String,
          version: m['version'] as String,
          jurisdiction: m['jurisdiction'] as String,
          publisher: m['publisher'] as String,
          source: m['source'] as String,
          kind: NormativeDocumentKind.values.byName(m['kind'] as String),
          criteria: (m['criteria'] as List)
              .map((c) => NormativeCriterion.values.byName(c as String)),
          clauseReference: m['clauseReference'] as String,
          notes: m['notes'] as String);
}

final bundledNormativeDocuments = <NormativeDocument>[
  NormativeDocument(
      id: 'iec-60364-4-43-2023',
      standardCode: 'IEC 60364-4-43',
      title: 'Low-voltage installations: protection against overcurrent',
      version: '2023',
      jurisdiction: 'International reference',
      publisher: 'IEC',
      source: 'https://webstore.iec.ch/en/publication/28432',
      kind: NormativeDocumentKind.standard,
      notes:
          'Publisher metadata only. Licensed clause text and national applicability have not been encoded.'),
  NormativeDocument(
      id: 'iec-60364-4-41-2017',
      standardCode: 'IEC 60364-4-41',
      title: 'Low-voltage installations: protection against electric shock',
      version: '2005+AMD1:2017',
      jurisdiction: 'International reference',
      publisher: 'IEC',
      source: 'https://webstore.iec.ch/en/publication/60169',
      kind: NormativeDocumentKind.standard,
      notes:
          'Publisher metadata only. No universal RCD applicability or trip-current value is inferred.'),
  NormativeDocument(
      id: 'schneider-protection-guide-29756',
      standardCode: 'Electrical Installation Guide',
      title: 'Practical values for a protective scheme',
      version: 'source revision 29756',
      jurisdiction: 'General engineering guidance',
      publisher: 'Schneider Electric',
      source:
          'https://www.electrical-installation.org/enw/index.php?title=Practical_values_for_a_protective_scheme&oldid=29756',
      kind: NormativeDocumentKind.guidance,
      criteria: NormativeCriterion.values,
      clauseReference: 'Applications / Protection by circuit-breaker',
      notes:
          'Curated basic criteria: Ib ≤ In ≤ declared Iz; breaking capacity ≥ declared prospective fault current. This guide is distinct from a national standard; full installation verification is outside these criteria.'),
];
