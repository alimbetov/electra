# P3 — CCTV calculation implementation

Status: DESIGN DRAFT / RUNTIME NOT STARTED
Depends on: P1/P2 and relevant ELV3/ELV4 kernels.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md).

Inherited implementation and mandatory new extensions: [baseline contract P3](implemented-baseline.md#p3); [pinned evidence](baseline.json). This contract supersedes the original design-only parent assumptions.

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P3-001 | Implement CCTV-01 explicit rectilinear plane coverage with coordinate/model applicability and numeric bounds | P3-T01 |
| ELV5-P3-002 | Implement CCTV-02 stream/flow identity, expected/peak and exact per-edge copy accounting | P3-T02 |
| ELV5-P3-003 | Implement CCTV-03 unique recording horizon integration and usable/raw requirement distinction | P3-T03 |
| ELV5-P3-004 | Implement CCTV-04 contextual PoE over complete shared physical source evidence | P3-T04 |
| ELV5-P3-005 | Implement CCTV-05 independent channels/ingress/codec/usable-storage constraints | P3-T05 |
| ELV5-P3-006 | Implement CCTV-06 realized link/power applicability without duplicate path/resource claims | P3-T06 |
| ELV5-P3-007 | Emit structured step/provenance and exact incremental dependencies for all CCTV outputs | P3-T07 |
| ELV5-P3-008 | Qualify positive/negative, restart/history and shared LAN/PSE cases through public commands | P3-T08 |

## Concrete contract

Geometry uses captured frame/intrinsics; ray-plane denominator/behind-camera/horizon cases are explicit. First positive pinhole case is exact normal incidence with a 3x2m footprint. General rotations require declared matrix/frame applicability and bounded ray intersections; FOV angle output uses a pinned bounded transcendental backend. Unsupported occlusion/fisheye/distortion yields a model-limit finding, not visible coverage.

Streams, network replicas and recordings have separate IDs. Schedule intervals use one explicit UTC horizon; recurrence expansion records timezone/rule version before union. Peak bitrate sizes links/ingress; expected recording bitrate integrates storage under the selected explicit policy. Retention/reserve/redundancy never multiply twice. Recorder usable space is a declared technical capability; product/RAID selection remains downstream.

## Exit

P3 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.

## Audit refinements

CCTV-03 sums exact rational bytes per unique (stream,pool,copyRole) horizon before a single pool-level reserve/ceil to usable byte; raw estimate ceilings once after declared redundancy. Explicit EXPECTED_ESTIMATE versus GUARANTEED_UPPER_BOUND controls retention claims. CCTV-05 channel basis DEVICE/ENCODED_STREAM/LICENSE_CHANNEL is required independently of ingress/storage. Two streams of one camera are one channel only if the exact profile declares DEVICE accounting.

CCTV-01 additionally requires horizontal/vertical FOV interval dimensions through pinhole-angle-bounds.v1; missing angle backend cannot be waived as an optional display. Its bounded algorithm and termination are specified in process-contracts.md; footprint-only remains a partial result.
