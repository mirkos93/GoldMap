# GoldMap Gathering Plan

## Scope

Add profession farming support for `Herbalism` and `Mining` with:

- map/minimap pins for gather nodes
- tooltip EV details per node
- value-based filtering (same logic style as mob farming)
- speed-oriented farming signal (node density / yield)

## DB Findings (validated on local `wow` MySQL)

- Primary spawn table: `gameobject`
- GO metadata: `gameobject_template`
- GO loot table: `gameobject_loot_template`
- Reference loot expansion: `reference_loot_template`
- Item metadata: `item_template`

Validated counts from the current DB:

- `gameobject_template` type `3` (lootable objects): `770`
- Exported gathering nodes (classic world maps only): `60`
  - `41` herbalism
  - `19` mining
- Exported gathering spawns (maps `0/1`): `17033`
- Unique output items from gathering nodes: `65`

## Classification Strategy

Mining nodes:

- `gameobject_template.name` matches mining patterns:
  - `Vein`, `Deposit`, `Lode`, `Outcrop`, `Mineral`

Herbalism nodes:

- name matches herb names (`item_template.class=7 AND subclass=9`) plus a small curated extras list

False-positive suppression:

- explicit exclusion of container/object names (e.g. chest/crate/strongbox families)

## Export Pipeline

New script:

- `scripts/generate_gathering_data.py`

Generated files:

- `Data/GatherNodes.lua`
- `Data/GatherSpawns.lua`

No hard caps are applied to node count or spawn count.

## Runtime Integration Plan

### Phase 1 - Core Data/Evaluation

- Add `Core/GatherEvaluator.lua`
- Compute:
  - `EV per node`
  - `priced outputs`
  - `yield score` (from expected quantity)
  - `density score` (local node concentration)

### Phase 2 - Map/Minimap Rendering

- Extend map pin providers to include gather nodes
- Keep strict map projection checks to prevent out-of-zone drift
- Add anti-overlap/anti-flicker behavior identical to current mob pin pipeline

### Phase 3 - Tooltip

- Add gather tooltip renderer:
  - node name
  - profession type
  - top outputs with chance/quantity/price/EV contribution
  - EV per node
  - local density/speed indicator

### Phase 4 - Filters/UI

Add filters (English labels):

- `Farm Source`: `Mobs`, `Gathering`, `Both`
- `Profession`: `Herbalism`, `Mining`, `Both`
- `Min output price`
- `Min EV per node`
- `Min node density`
- keep `Match all` / `Match any` behavior for non-technical users

### Phase 5 - Scanner Target Expansion

- Already started: AH tracked item set now includes gathering output items.
- Finish with UI statistics split:
  - priced from mob drops
  - priced from gathering outputs
  - overlap count

### Phase 6 - QA/Perf

- Verify no pin drift at different map zoom levels
- Verify minimap pins remain world-fixed (not attached to player motion)
- Verify all tooltip rows obey active filters
- Add stress tests with dense zones (e.g. Elwynn/Westfall/Stranglethorn routes)
