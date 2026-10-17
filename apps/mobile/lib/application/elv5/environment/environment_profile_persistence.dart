import 'package:engineering_core/engineering_core_elv5.dart';

final class Elv5EnvironmentProfileSnapshot {
  const Elv5EnvironmentProfileSnapshot({
    required this.bindingId,
    required this.bindingRevision,
    required this.scopeKind,
    required this.scopeId,
    required this.evidenceRef,
    required this.contentHash,
    required this.profile,
  });

  final String bindingId;
  final int bindingRevision;
  final String scopeKind;
  final String scopeId;
  final String evidenceRef;
  final String contentHash;
  final Elv5EnvironmentProfile profile;
}

abstract interface class Elv5EnvironmentProfileSource {
  Future<Elv5EnvironmentProfileSnapshot?> loadActiveForScope({
    required String projectId,
    required String designRevisionId,
    required String scopeKind,
    required String scopeId,
  });
}

final class ReplaceElv5EnvironmentProfileCommand {
  ReplaceElv5EnvironmentProfileCommand({
    required this.projectId,
    required this.designRevisionId,
    required this.expectedDesignRevision,
    required this.bindingId,
    required this.expectedBindingRevision,
    required String scopeKind,
    required String scopeId,
    required this.profile,
  })  : scopeKind = _scopeKind(scopeKind),
        scopeId = _text(scopeId, 'scopeId') {
    if (projectId.trim().isEmpty ||
        designRevisionId.trim().isEmpty ||
        bindingId.trim().isEmpty) {
      throw ArgumentError('Environment profile command identity is required.');
    }
    if (expectedDesignRevision < 1) {
      throw ArgumentError('expectedDesignRevision must be >= 1.');
    }
    if (expectedBindingRevision != null && expectedBindingRevision! < 1) {
      throw ArgumentError('expectedBindingRevision must be >= 1 when supplied.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final String scopeKind;
  final String scopeId;
  final Elv5EnvironmentProfile profile;
}

abstract interface class Elv5EnvironmentProfileWriter {
  Future<void> replace(ReplaceElv5EnvironmentProfileCommand command);
}

String _scopeKind(String value) {
  final normalized = _text(value, 'scopeKind').toUpperCase();
  if (!const <String>{'ROOM', 'ROUTE_SECTION'}.contains(normalized)) {
    throw ArgumentError.value(value, 'scopeKind', 'Expected ROOM or ROUTE_SECTION.');
  }
  return normalized;
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}
