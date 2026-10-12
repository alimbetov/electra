# Industrial equipment support

Electra must support production and industrial equipment as first-class `EquipmentItem` instances rather than forcing them into a generic custom object.

## Initial equipment categories

```text
MOTOR
PUMP
FAN
COMPRESSOR
MACHINE_TOOL
CNC_MACHINE
CONVEYOR
WELDING_EQUIPMENT
HEATER
BOILER
REFRIGERATION
HVAC_EQUIPMENT
PROCESS_EQUIPMENT
VARIABLE_FREQUENCY_DRIVE
SOFT_STARTER
CONTROL_PANEL
PLC_PANEL
SENSOR
ACTUATOR
INSTRUMENTATION
NETWORK_EQUIPMENT
SAFETY_EQUIPMENT
CUSTOM
```

The code enum may use Dart lowerCamelCase while serialized domain/API codes remain stable English uppercase values later.

## Multi-discipline ports

Industrial devices commonly participate in several networks simultaneously.

Example:

```text
CNC machine
  -> POWER
  -> CONTROL
  -> ETHERNET / FIELDBUS
  -> COMPRESSED_AIR
  -> COOLING_WATER
  -> DRAIN
```

A device therefore exposes typed `EquipmentPort` instances rather than one generic connection field.

Representative port types include:

```text
POWER
CONTROL
DIGITAL_INPUT
DIGITAL_OUTPUT
ANALOG_INPUT
ANALOG_OUTPUT
ETHERNET
ETHERNET_POE
FIELDBUS
COMPRESSED_AIR
COLD_WATER
HOT_WATER
DRAIN
GAS
SUPPLY
RETURN
REFRIGERANT_IN
REFRIGERANT_OUT
EXHAUST
CUSTOM
```

## Device definition metadata

A future `DeviceDefinition` for industrial equipment may provide:

- manufacturer/model metadata;
- nominal power;
- voltage and phase;
- rated current;
- start current / starting method;
- power factor / efficiency;
- duty mode;
- dimensions and clearance envelope;
- weight;
- default mounting type;
- required ports;
- protection/control recommendations;
- icon/symbol metadata;
- maintenance/document references.

These fields are catalog metadata and defaults. A placed `EquipmentItem` may override project-specific values.

## UI ergonomics

The equipment palette should use searchable categories and presets rather than one very long flat list.

Suggested groups:

```text
Electrical
Lighting
Distribution
Motors & Drives
Pumps & Fans
Machines & CNC
Process Equipment
Automation & Control
Instrumentation
Network
Safety
Custom
```

Frequently used items and project-local presets should appear first.

Industrial support does not change the editor interaction model: the engineer selects a device/preset, places it on the active surface or free spatial position, and then connects its ports to engineering networks.
