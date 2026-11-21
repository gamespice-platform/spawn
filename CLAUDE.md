# GameSpice Spawn

Where anything enters the world, and why that place: sites as values, conditions that veto or score them, a deterministic pick with a loud fallback, respawn timing, and spawn protection as a ledger.

Read the family [CLAUDE.md](../../CLAUDE.md) first.

**The distributable is `addons/gs_spawn/`.** It requires [GameSpice Core](../gs-core) and nothing else (`ln -s ../../gs-core/addons/gs_core addons/gs_core`, gitignored).

Also requires **GameSpice Profile** (`GSProfileSet`, `GSProfile`, `GSProfileRuntime`, split from GameSpice Core): link `addons/gs_profile` next to `addons/gs_core`.

## Read before

| Read | Before |
| --- | --- |
| [docs/design.md](docs/design.md) | changing anything: sites as values, vetoes vs opinions, `MetaMatchesRequest`, the fallback, one generator per request, node traps, protection, what it does not do |
| [docs/map-data-tools.md](docs/map-data-tools.md) | the planned mover watch and cull, strategies and spread, authored points, the map data store and bundle, admin tools: which addon owns each |

## Layout

| Path | What |
| --- | --- |
| `core/gs_spawn_site.gd` | `GSSpawnSite`: one candidate place, as a value (`extents` are half-extents, `last_used_tick`) |
| `core/gs_spawn_request.gd` | `GSSpawnRequest`: who is spawning, on which side, as what, when; `make(..., extra)` |
| `core/gs_spawn_choice.gd` | `GSSpawnChoice`: the answer, `fell_back`, `protected_until` |
| `core/gs_spawn_rules.gd` | `GSSpawnRules`: every policy, layered `GSConfig` |
| `core/gs_spawn_condition.gd` | `GSSpawnCondition`: the extension point, `allows()` (veto) and `bonus()` (opinion) |
| `core/gs_spawn_conditions.gd` | `MinimumEnemyDistance`, `OutOfSight`, `NotOccupied`, `MetaEquals`, `MetaMatchesRequest` |
| `core/gs_spawn_point_def.gd`, `gs_spawn_point_set.gd` | `GSSpawnPointDef` (one authored point, every setting, `to_site()`, versioned `to_dict`/`from_dict`, `schema()`), `GSSpawnPointSet` (`apply_to` overrides map sites by id without editing them); enforced by `MaxAlive`, `PhaseIs`, `KindIs`, `DistanceBand`, `SightRule`, `WeightBonus` in `GSSpawnConditions` |
| `core/gs_spawn_flags.gd` | `GSSpawnFlags`: flag stands among the sites (kind `flag`, `team` as a number, any number of teams), `bases(sites, team_count)` with a cluster fallback for a map without flags; a `KindIs` veto keeps players off a stand |
| `core/gs_spawn_protection.gd` | `GSSpawnProtection`: who is briefly un-killable, `blocks`, `advance`, `ended` |
| `core/gs_spawn_watch.gd`, `gs_spawn_cull.gd`, `gs_spawn_cull_rules.gd` | `GSSpawnWatch` (stuck, off nav, fell out, unreachable, far verdicts, time-sliced), `GSSpawnCull` (one `GSSpawnDecision` per mover: nudge, teleport, despawn, kill), `GSSpawnCullRules` (`GS_SPAWN_CULL_*`, `--cull-*`, off by default); the host applies decisions through callables |
| `nodes/` | `GSSpawnMarker3D`, `GSSpawnMarker2D`, `GSSpawnArea3D` (optionally a safe zone), `GSSpawnArea2D`; each has `to_site()` |
| `runtime/gs_spawn_director.gd` | `GSSpawnDirector`: `refresh`, `choose`, `choose_from`, `choose_batch` (`spread` keeps a batch apart, `grouped` keeps a team together), `reset_groups` (also run by `refresh` and a map change), `ensure_generated` (`generate_fn`, cached per map id, version, `generate_count` and `generate_clearance`), respawn timing, `can_see_fn` |
| `runtime/gs_entity_spawner.gd` | `GSEntitySpawner`: factory-driven spawner for any entity from a `spawner` profile ([docs/entity-spawner.md](docs/entity-spawner.md)) |
| `examples/spawn_selftest.tscn`, `entity_spawner_selftest.tscn` | the suites: no level loaded |

Paths except `examples/` are in `addons/gs_spawn/`.

## Running and testing

The family's two steps ([family CLAUDE.md](../../CLAUDE.md#validating-anything)), then `timeout 120 godot --headless --path . res://examples/spawn_selftest.tscn`.

## Rules that bite

- Decide on `GSSpawnSite` values only; the tree is touched in `refresh`, which collects anything with `to_site()`. [design](docs/design.md#everything-that-decides-works-on-dotspawnsite-values)
- `refresh()` keeps each site's `last_used_tick`. [design](docs/design.md#everything-that-decides-works-on-dotspawnsite-values)
- A veto is `allows()`, never a large negative `bonus()`; a condition with no information has no opinion. [design](docs/design.md#vetoes-and-opinions-are-different-things)
- A request without the field `MetaMatchesRequest` reads matches every site; `make` duplicates `extra`. [design](docs/design.md#metamatchesrequest-a-site-against-the-request)
- The fallback is reported three ways; `validate()` refuses a distance floor with no fallback. [design](docs/design.md#the-fallback-is-not-optional)
- One generator per request from seed, tick and key; never a member stream. [design](docs/design.md#one-generator-per-request)
- Nodes use `site_priority` (areas own `priority`); `measured_extents` halves a box size. [design](docs/design.md#node-traps)
- Protection never touches health and never blocks self damage; call `advance()` or `ended` never fires. [design](docs/design.md#protection-is-a-ledger-not-a-behaviour)
- Protection is granted only inside `GSSpawnDirector.choose`: a game that places spawns itself has none. [design](docs/design.md#protection-is-a-ledger-not-a-behaviour)

Deliberately not here: moving, raycasting, health, replacing gs-match's simple spawn selector. [design](docs/design.md#what-it-deliberately-does-not-do)
