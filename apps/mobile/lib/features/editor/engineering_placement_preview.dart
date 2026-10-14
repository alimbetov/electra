import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import '../../application/engineering_profile_palette.dart';
import 'editor_interaction.dart';

Color placementStatusColor(PlacementCompatibilityStatus status) =>
    switch (status) {
      PlacementCompatibilityStatus.compatible => Colors.green.shade800,
      PlacementCompatibilityStatus.warning => Colors.orange.shade900,
      PlacementCompatibilityStatus.forbidden => Colors.red.shade800,
      PlacementCompatibilityStatus.unresolved => Colors.blueGrey.shade700,
    };

class PlacementStatusIndicator extends StatelessWidget {
  const PlacementStatusIndicator({super.key, required this.result});
  final PlacementCompatibilityResult result;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Placement preview ${result.status.name}',
    child: Chip(
      avatar: Icon(switch (result.status) {
        PlacementCompatibilityStatus.compatible => Icons.check_circle_outline,
        PlacementCompatibilityStatus.warning => Icons.warning_amber,
        PlacementCompatibilityStatus.forbidden => Icons.block,
        PlacementCompatibilityStatus.unresolved => Icons.help_outline,
      }, color: placementStatusColor(result.status)),
      label: Text(result.status.name.toUpperCase()),
      side: BorderSide(color: placementStatusColor(result.status)),
    ),
  );
}

class EngineeringPlacementFeedback extends StatelessWidget {
  const EngineeringPlacementFeedback({
    super.key,
    required this.choice,
    required this.result,
    required this.hasCandidate,
    required this.onContext,
    required this.onDetails,
    this.onPlace,
    this.canPlace = false,
    this.isSaving = false,
  });
  final CanonicalProfileChoice choice;
  final PlacementCompatibilityResult? result;
  final bool hasCandidate;
  final VoidCallback onContext, onDetails;
  final VoidCallback? onPlace;
  final bool canPlace, isSaving;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview: ${choice.profile.label} · ${choice.system.code}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (result != null && hasCandidate)
              PlacementStatusIndicator(result: result!)
            else
              const Text('Choose a point on the surface.'),
            TextButton.icon(
              onPressed: hasCandidate ? onContext : null,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Candidate conditions'),
            ),
            IconButton(
              tooltip: 'Preview findings and profile',
              onPressed: onDetails,
              icon: const Icon(Icons.info_outline),
            ),
            if (onPlace != null)
              FilledButton.icon(
                onPressed: canPlace ? onPlace : null,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(isSaving ? 'Saving…' : 'Place profile'),
              ),
          ],
        ),
        const Text(
          'Preview only · no project changes saved.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

class PlacementFindingsView extends StatelessWidget {
  const PlacementFindingsView({super.key, required this.result});
  final PlacementCompatibilityResult result;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PlacementStatusIndicator(result: result),
      Text(
        '${result.profileCode} · ${result.catalogId} / ${result.catalogVersion}',
      ),
      if (result.findings.isEmpty)
        const Text(
          'The declared candidate conditions satisfy the profile checks.',
        ),
      for (final finding in result.findings)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(switch (finding.severity) {
            PlacementFindingSeverity.error => Icons.block,
            PlacementFindingSeverity.warning => Icons.warning_amber,
            PlacementFindingSeverity.unresolved => Icons.help_outline,
          }),
          title: Text(finding.explanation),
          subtitle: Text(
            '${finding.dimension.name} · ${finding.code.name}${finding.expected == null ? '' : '\nExpected: ${finding.expected}'}${finding.actual == null ? '' : '\nActual: ${finding.actual}'}${finding.remediationHint == null ? '' : '\n${finding.remediationHint}'}',
          ),
        ),
    ],
  );
}

class CandidateConditionsDialog extends StatefulWidget {
  const CandidateConditionsDialog({
    super.key,
    required this.initial,
    required this.system,
    this.topologyProfiles = const [],
  });
  final PlacementCandidateContext initial;
  final EngineeringSystem system;
  final List<TopologyProfile> topologyProfiles;
  @override
  State<CandidateConditionsDialog> createState() =>
      _CandidateConditionsDialogState();
}

class _CandidateConditionsDialogState extends State<CandidateConditionsDialog> {
  final form = GlobalKey<FormState>();
  InstallationSurface? surface;
  MountingMethod? method;
  EnvironmentExposure? exposure;
  EnvironmentMoisture? moisture;
  EnvironmentContamination? contamination;
  EnvironmentClimate? climate;
  bool? enclosure;
  TopologyShape? shape;
  TopologyParticipation? role;
  late final TextEditingController temperature, ip, clearance;
  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    surface = c.installationSurface;
    method = c.mountingMethod;
    exposure = c.environmentExposure;
    moisture = c.environmentMoisture;
    contamination = c.environmentContamination;
    climate = c.environmentClimate;
    enclosure = c.hasEnclosure;
    role = c.topologyRole;
    shape =
        widget.system.topologyProfile == null
            ? c.topologyShape
            : resolvePaletteTopology(widget.system, widget.topologyProfiles);
    temperature = TextEditingController(
      text: c.ambientTemperatureC?.toString() ?? '',
    );
    ip = TextEditingController(text: c.actualIpRating?.value ?? '');
    clearance = TextEditingController(
      text: c.availableClearanceMm?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    temperature.dispose();
    ip.dispose();
    clearance.dispose();
    super.dispose();
  }

  Widget select<T extends Enum>(
    String label,
    T? value,
    List<T> values,
    ValueChanged<T?> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<T>(
      key: ValueKey('candidate-$label'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<T>(value: null, child: const Text('Unknown')),
        for (final v in values) DropdownMenuItem(value: v, child: Text(v.name)),
      ],
      onChanged: (v) => setState(() => changed(v)),
    ),
  );
  Widget number(
    String label,
    TextEditingController controller, {
    bool nonnegative = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      key: ValueKey('candidate-$label'),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: label, hintText: 'Unknown'),
      validator: (raw) {
        if (raw == null || raw.trim().isEmpty) return null;
        final n = double.tryParse(raw.trim());
        return n == null || !n.isFinite || nonnegative && n < 0
            ? 'Enter a finite ${nonnegative ? 'nonnegative ' : ''}number or leave unknown.'
            : null;
      },
    ),
  );
  double? numeric(TextEditingController c) =>
      c.text.trim().isEmpty ? null : double.parse(c.text.trim());
  void apply() {
    if (!form.currentState!.validate()) return;
    final c = widget.initial;
    Navigator.pop(
      context,
      PlacementCandidateContext(
        projectId: c.projectId,
        roomId: c.roomId,
        surfaceId: c.surfaceId,
        installationSurface: surface,
        mountingMethod: method,
        environmentExposure: exposure,
        environmentMoisture: moisture,
        environmentContamination: contamination,
        environmentClimate: climate,
        ambientTemperatureC: numeric(temperature),
        actualIpRating:
            ip.text.trim().isEmpty ? null : IpProtectionClass.parse(ip.text),
        hasEnclosure: enclosure,
        availableClearanceMm: numeric(clearance),
        topologyShape: shape,
        topologyRole: role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Candidate conditions'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Surface: ${widget.initial.surfaceId}'),
              const Text(
                'Enter known facts for this candidate. Blank values remain unknown. These conditions are kept only in this preview.',
              ),
              const SizedBox(height: 12),
              select(
                'Installation surface',
                surface,
                InstallationSurface.values,
                (v) => surface = v,
              ),
              select(
                'Mounting method',
                method,
                MountingMethod.values,
                (v) => method = v,
              ),
              DropdownButtonFormField<bool>(
                initialValue: enclosure,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Enclosure present',
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Unknown')),
                  DropdownMenuItem(value: true, child: Text('Yes')),
                  DropdownMenuItem(value: false, child: Text('No')),
                ],
                onChanged: (v) => setState(() => enclosure = v),
              ),
              number('Available clearance (mm)', clearance, nonnegative: true),
              select(
                'Exposure',
                exposure,
                EnvironmentExposure.values,
                (v) => exposure = v,
              ),
              select(
                'Moisture',
                moisture,
                EnvironmentMoisture.values,
                (v) => moisture = v,
              ),
              select(
                'Contamination',
                contamination,
                EnvironmentContamination.values,
                (v) => contamination = v,
              ),
              select(
                'Climate',
                climate,
                EnvironmentClimate.values,
                (v) => climate = v,
              ),
              number('Ambient temperature (°C)', temperature),
              TextFormField(
                key: const ValueKey('candidate-IP'),
                controller: ip,
                decoration: const InputDecoration(
                  labelText: 'Actual IP protection',
                  hintText: 'Unknown',
                ),
                validator: (raw) {
                  if (raw == null || raw.trim().isEmpty) return null;
                  try {
                    IpProtectionClass.parse(raw);
                    return null;
                  } on FormatException {
                    return 'Enter an IP protection class such as IP54 or leave unknown.';
                  }
                },
              ),
              const SizedBox(height: 10),
              if (widget.system.topologyProfile != null)
                Text(
                  'Pinned topology: ${widget.system.topologyProfile!.id} / ${widget.system.topologyProfile!.version}\nShape: ${shape?.name ?? 'unresolved edition'}',
                )
              else
                select(
                  'Intended topology shape',
                  shape,
                  TopologyShape.values,
                  (v) => shape = v,
                ),
              select(
                'Intended topology role',
                role,
                TopologyParticipation.values,
                (v) => role = v,
              ),
              const Text(
                'Shape and role describe pre-placement intent. Graph closure and branching are checked separately.',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: apply, child: const Text('Apply to preview')),
    ],
  );
}

class EngineeringCandidatePainter extends CustomPainter {
  const EngineeringCandidatePainter({
    required this.patch,
    required this.point,
    required this.status,
  });
  final SurfacePatch patch;
  final Point2Mm point;
  final PlacementCompatibilityStatus status;
  @override
  void paint(Canvas canvas, Size size) {
    final transform = SurfaceViewportTransform(
      boundary: patch.boundary,
      viewportWidth: size.width,
      viewportHeight: size.height,
    );
    final mapped = transform.localToViewport(point);
    final center = Offset(mapped.x, mapped.y);
    final paint =
        Paint()
          ..color = placementStatusColor(status)
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 11, paint);
    canvas.drawLine(
      center - const Offset(16, 0),
      center + const Offset(16, 0),
      paint,
    );
    canvas.drawLine(
      center - const Offset(0, 16),
      center + const Offset(0, 16),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant EngineeringCandidatePainter oldDelegate) =>
      oldDelegate.patch != patch ||
      oldDelegate.point != point ||
      oldDelegate.status != status;
}
