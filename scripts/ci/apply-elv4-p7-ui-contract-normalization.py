from pathlib import Path

path = Path('apps/mobile/lib/features/editor/power_workspace_panel.dart')
text = path.read_text()

scenario_old = """                  value: scenario,
                  hint: const Text('Scenario'),
"""
scenario_new = """                  value: scenario,
                  isExpanded: true,
                  hint: const Text('Scenario'),
"""
overlay_old = """                  value: state.overlayMode,
                  items: [
"""
overlay_new = """                  value: state.overlayMode,
                  isExpanded: true,
                  items: [
"""

if scenario_old in text:
    text = text.replace(scenario_old, scenario_new, 1)
elif 'value: scenario,\n                  isExpanded: true,' not in text:
    raise SystemExit('scenario DropdownButton normalization anchor missing')

if overlay_old in text:
    text = text.replace(overlay_old, overlay_new, 1)
elif 'value: state.overlayMode,\n                  isExpanded: true,' not in text:
    raise SystemExit('overlay DropdownButton normalization anchor missing')

path.write_text(text)
