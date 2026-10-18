# ELV5 — calculation reference-oracle errata v1

Status: NORMATIVE SPECIFICATION CORRECTION / RUNTIME NOT STARTED  
Branch: `feat/flutter-elv5-power-topology-design`

This document records arithmetic corrections discovered while cross-checking the fourth-pass process vectors. It has higher authority than the affected illustrative/reference-vector sentence in older `process-contracts.md` and the corresponding process dossier until those source paragraphs are mechanically synchronized. It does not alter the algorithm, physical model, process inventory or public API.

## ERRATA-001 — ACS-03 positive terminal-voltage oracle

Affected process: `ACS-03 — Lock electrical demand and terminal-voltage transient basis`.

Older reference wording used:

```text
shared trunk currents = 0.3 A + 0.5 A
source voltage = 24 V
trunk resistance = 0.5 ohm
lock branch current = 0.3 A
lock branch resistance = 0.3 ohm
reported lock terminal voltage = 23.45 V
```

The reported terminal voltage is arithmetically inconsistent with those inputs.

Normative calculation:

```text
I_trunk = 0.3 A + 0.5 A
        = 0.8 A

DeltaV_trunk = I_trunk * R_trunk
             = 0.8 A * 0.5 ohm
             = 0.4 V

V_branch_origin = 24 V - 0.4 V
                = 23.6 V

DeltaV_lock_branch = I_lock * R_lock_branch
                   = 0.3 A * 0.3 ohm
                   = 0.09 V

V_lock_terminal = 23.6 V - 0.09 V
                = 23.51 V
```

Therefore the canonical positive reference vector is:

```text
Shared trunk 0.3 A + 0.5 A = 0.8 A,
24 V source,
0.5 ohm shared trunk,
0.3 A lock branch,
0.3 ohm lock branch
=> lock terminal voltage = 23.51 V.
```

If the selected technical minimum is `22.00 V`, the corresponding terminal-voltage headroom is:

```text
23.51 V - 22.00 V = +1.51 V
```

not `+1.45 V`.

## Runtime acceptance impact

The production ACS-03 kernel SHOULD normally consume the exact ELV4 PWR-03 result rather than recompute this path locally. This vector exists to cross-check the accepted physical evidence and to catch a reduced-closure or arithmetic regression.

P5/P8 acceptance MUST include an executable fixture whose exact expected terminal voltage is `23.51 V` for the inputs above. A fixture expecting `23.45 V` from the same inputs is invalid.

This correction does not authorize ELV5 to duplicate PWR-03 physical solving. The ownership rule remains:

```text
ELV4 owns physical voltage-drop/current solution.
ELV5 ACS-03 binds the exact shared evidence to lock operating/transient cases and technical requirements.
```

## Change-control rule

Future reference-oracle corrections must state:

- affected process/vector ID;
- old inputs/output;
- exact corrected arithmetic;
- whether algorithm semantics change;
- affected executable test IDs;
- authority/manifest fingerprint impact.

An arithmetic oracle correction changes the ELV5 authority fingerprint and requires affected design/runtime evidence to be regenerated at the new exact source SHA.