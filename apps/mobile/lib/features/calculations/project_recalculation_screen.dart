import 'dart:convert';

import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../application/dependency_recalculation_repository.dart';

class ProjectRecalculationScreen extends ConsumerWidget {
  const ProjectRecalculationScreen({super.key, required this.projectId});
  final String projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Dependency recalculation')),
    body: ref
        .watch(projectRecalculationProvider(projectId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Unable to load calculations: $error')),
          data: (snapshot) {
            if (snapshot.project == null)
              return const Center(child: Text('Project is unavailable.'));
            final repository = ref.read(
              dependencyRecalculationRepositoryProvider,
            );
            return RecalculationWorkspace(
              snapshot: snapshot,
              onRecalculate: () => repository.recalculate(projectId),
              onManualDecision: (key, value, reason) =>
                  repository.saveManualDecision(
                    projectId: projectId,
                    key: key,
                    value: value,
                    reason: reason,
                  ),
              onReviewManual: (key) =>
                  repository.reviewManualDecision(projectId, key),
              onClearManual: (key) =>
                  repository.clearManualDecision(projectId, key),
            );
          },
        ),
  );
}

class RecalculationWorkspace extends StatefulWidget {
  const RecalculationWorkspace({
    super.key,
    required this.snapshot,
    required this.onRecalculate,
    required this.onManualDecision,
    required this.onReviewManual,
    required this.onClearManual,
  });
  final ProjectRecalculationSnapshot snapshot;
  final Future<Set<String>> Function() onRecalculate;
  final Future<void> Function(String key, String value, String reason)
  onManualDecision;
  final Future<void> Function(String key) onReviewManual, onClearManual;
  @override
  State<RecalculationWorkspace> createState() => _RecalculationWorkspaceState();
}

class _RecalculationWorkspaceState extends State<RecalculationWorkspace> {
  bool busy = false, affectedOnly = true, showSources = false;
  String? error;
  int? recalculated;
  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> manual(String key, RecalculationCache entry) => showDialog<void>(
    context: context,
    builder: (_) => _ManualDecisionDialog(
      value: entry.manualValue ?? '',
      reason: entry.manualReason ?? '',
      onSave: (value, reason) => widget.onManualDecision(key, value, reason),
    ),
  );
  String value(Object? value) => value == null
      ? '—'
      : value is String
      ? value
      : jsonEncode(value);
  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot,
        session = snapshot.session,
        affected = session.affectedKeys;
    final keys = session.order
        .where(
          (key) =>
              (showSources ||
                  [
                    'circuit:',
                    'cable:',
                    'route:',
                    'protection:',
                    'panel:',
                  ].any(key.startsWith)) &&
              (!affectedOnly ||
                  affected.contains(key) ||
                  session.state(key) ==
                      EngineeringDerivedState.reviewRequired ||
                  session.state(key) == EngineeringDerivedState.error),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          snapshot.project?.name ?? 'Project',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${affected.length} affected nodes · ${session.removedKeys.length} removed records',
        ),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => run(() async {
                  final changed = await widget.onRecalculate();
                  if (mounted) setState(() => recalculated = changed.length);
                }),
          icon: const Icon(Icons.calculate),
          label: Text(busy ? 'Recalculating…' : 'Recalculate affected'),
        ),
        if (recalculated != null)
          Text(
            'Recalculated $recalculated nodes. Independent records were preserved.',
          ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        SwitchListTile(
          title: const Text('Affected or review required only'),
          value: affectedOnly,
          onChanged: (value) => setState(() => affectedOnly = value),
        ),
        SwitchListTile(
          title: const Text('Show source inputs'),
          value: showSources,
          onChanged: (value) => setState(() => showSources = value),
        ),
        const Text(
          'Calculated proposals use canonical inputs. Manual decisions are recorded separately and never replace automatic values or confirm a circuit.',
        ),
        if (keys.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No affected proposals.'),
          ),
        for (final key in keys) _record(key, session),
        for (final key in session.removedKeys)
          ListTile(
            title: Text(key),
            subtitle: const Text(
              'Removed from the active graph; previous output will be archived on recalculation.',
            ),
          ),
        if (snapshot.retired.isNotEmpty)
          ExpansionTile(
            title: const Text('Archived results'),
            children: [
              for (final entry in snapshot.retired)
                ListTile(
                  title: Text(entry.key),
                  subtitle: Text(value(entry.proposal.values)),
                ),
            ],
          ),
      ],
    );
  }

  Widget _record(String key, RecalculationSession session) {
    final node = session.nodes[key]!,
        entry = session.cache[key],
        state = session.state(key);
    final stale = entry?.fingerprint != session.fingerprints[key];
    final changes = stale
        ? session.changes(key)
        : entry == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(entry.changesJson) as List).cast<Map<String, dynamic>>();
    return Card(
      child: ExpansionTile(
        key: ValueKey(key),
        title: Text(node.label),
        subtitle: Text('${key.split(":").first} · ${state.name}'),
        childrenPadding: const EdgeInsets.all(12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stale
                ? 'Previous snapshot · recalculation required'
                : 'Calculated proposal',
          ),
          if (entry == null)
            const Text('No saved result yet.')
          else ...[
            for (final result in entry.proposal.values.entries)
              Text('${result.key}: ${value(result.value)}'),
            for (final issue in entry.proposal.issues)
              Text(issue, style: const TextStyle(color: Colors.red)),
            if (entry.previousResultJson != null)
              Text(
                'Before: ${value((jsonDecode(entry.previousResultJson!) as Map)["values"])}',
              ),
          ],
          const Divider(),
          const Text(
            'What changed?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (changes.isEmpty) const Text('No semantic input changes.'),
          for (final change in changes)
            Text(
              '${session.nodes[change["source"]]?.label ?? change["source"]} · ${change["field"]}: ${value(change["before"])} → ${value(change["after"])}',
            ),
          if (node.dependencies.isNotEmpty)
            Text(
              'Depends on: ${node.dependencies.map((id) => session.nodes[id]?.label ?? id).join(", ")}',
            ),
          Text('Calculation version: ${node.version}'),
          if (entry?.manualValue != null) ...[
            Text('Manual decision: ${entry!.manualValue}'),
            Text('Reason: ${entry.manualReason}'),
            Text(
              entry.manualReviewedFingerprint == session.fingerprints[key]
                  ? 'Manual decision reviewed for these inputs.'
                  : 'Inputs changed. Manual decision requires explicit review.',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: busy || stale
                      ? null
                      : () => run(() => widget.onReviewManual(key)),
                  child: const Text('Review manual decision'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => run(() => widget.onClearManual(key)),
                  child: const Text('Clear manual decision'),
                ),
              ],
            ),
          ],
          if (entry != null &&
              [
                'circuit:',
                'cable:',
                'protection:',
                'panel:',
              ].any(key.startsWith))
            TextButton(
              onPressed: busy || stale || state == EngineeringDerivedState.error
                  ? null
                  : () => manual(key, entry),
              child: const Text('Record manual decision'),
            ),
        ],
      ),
    );
  }
}

class _ManualDecisionDialog extends StatefulWidget {
  const _ManualDecisionDialog({
    required this.value,
    required this.reason,
    required this.onSave,
  });
  final String value, reason;
  final Future<void> Function(String, String) onSave;
  @override
  State<_ManualDecisionDialog> createState() => _ManualDecisionDialogState();
}

class _ManualDecisionDialogState extends State<_ManualDecisionDialog> {
  late final TextEditingController value, reason;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    value = TextEditingController(text: widget.value);
    reason = TextEditingController(text: widget.reason);
  }

  @override
  void dispose() {
    value.dispose();
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (value.text.trim().isEmpty || reason.text.trim().isEmpty) {
      setState(() => error = 'Enter a decision and its reason.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSave(value.text.trim(), reason.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Manual engineering decision'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: value,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Decision'),
          ),
          TextField(
            controller: reason,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: const Text('Save decision'),
      ),
    ],
  );
}
