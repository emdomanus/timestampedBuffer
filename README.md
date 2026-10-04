# TimestampedBuffer

A bounded timestamped ring buffer for shared Roblox use. No runtime dependencies,
services, clock, interpolation, or payload copying.

```luau
local TimestampedBuffer = require(game.ReplicatedStorage.packages.timestampedBuffer)
local newNumberBuffer = TimestampedBuffer.new :: (number) -> TimestampedBuffer.TimestampedBuffer<number>
local history = newNumberBuffer(32)
history:push(10, 1)
history:push(30, 3)
local a, ta, b, tb = history:bracket(2) -- 10, 1, 30, 3
```

## API

The root exports `new<T>(capacity: number): TimestampedBuffer<T>` and the matching type.
Entries return as payload/time pairs. Methods use colon calls.

| Method | Returns | Behavior |
| --- | --- | --- |
| `push(value, time)` | `T?, number?` | Append; return overwritten oldest entry, otherwise nil/nil. |
| `popOldest()` | `T?, number?` | Remove and return oldest, or nil/nil when empty. |
| `evictBefore(cutoff)` | `number` | Remove times strictly below cutoff; return removed count. |
| `oldest()` / `newest()` | `T?, number?` | Endpoints, or nil/nil when empty. |
| `at(index)` | `T?, number?` | One-based chronological access; nil/nil beyond count. |
| `count()` | `number` | Retained count. |
| `latestAtOrBefore(time)` | `T?, number?` | Newest inserted entry <= query, or nil/nil. |
| `bracket(time)` | `T?, number?, T?, number?` | Older value/time, newer value/time; four nils outside coverage. |
| `clear()` | `()` | Release entries and reset ordering, reusing storage. |

Capacity and indices must be positive finite integers. Times/cutoffs must be finite;
negative times are valid. Payloads must be non-nil (`false` works). Invalid inputs raise
errors; rejected insertions never partially mutate storage.

Equal times retain insertion order. Both lookups select the newest exact match; exact
brackets return it on both sides. A single entry brackets only its exact time, while
latest-at-or-before also returns it for later queries. Empty lookups are unavailable.
Timestamps cannot decrease relative to the newest retained entry. Emptying or clearing
allows a new origin; use `clear()` on clock discontinuities. Indices change on eviction.

## Ownership

Callers own sampling, cutoff policy and a consistent clock domain. Capacity may evict
history inside the desired duration; check oldest/newest for actual coverage. To keep
a predecessor below cutoff, pop while `at(2)` is strictly below cutoff instead of using
strict eviction. This cannot restore samples already lost to capacity.

Tables are stored by reference. Do not mutate a payload retained by any entry or reader.
Repeatedly inserting the same table does not create snapshots. Removal/clear release
references. `evictBefore` and `clear` discard payloads; use `popOldest` to recycle each.
For a full buffer, prefill once and keep a spare absent from all entries/readers:

```luau
spare.position = nextPosition
local evicted = history:push(spare, nextTime)
assert(evicted ~= nil, "expected full history")
spare = evicted -- reuse only after other readers release it
```

Construction allocates one instance and two preallocated arrays. Shared methods create
no tables or closures on successful operations. Append/access/pop are O(1), lookups
O(log n), eviction O(k), clear O(capacity). Caller allocations and runtime internals
are separate; no allocator-instrumented zero-allocation claim is made.

The buffer implementation uses file-level `--!native` for its numeric indexing/search
and ring-buffer operations, including their supporting constructor and accessors.
The package entrypoint and type leaf are not native candidates. This is a compilation
request, not a measured speedup; Studio native profiling remains unverified.

`tests/lune/examples.luau` demonstrates value interpolation, recycling, predecessor
retention and rejecting interpolation across hurtbox lifetimes. Identity, geometry and
eligibility stay with the owner. Atlas adoption must replace private slot access and
preserve aligned kinematics, interpolation/derivatives, capped extrapolation and rebase
behavior externally. Its malformed-order fallback is intentionally absent here. These
examples do not prove consumer integration; no consumer code was changed.

## Verification

The pinned tooling explicitly enables `LuauSolverV2=true` in CLI and editor.
The package passes new-solver analysis after the owner's constructor correction;
see [the review receipt](MIGRATION-REVIEW.md). The new solver requires explicit specialization of this
capacity-only generic factory, as shown above; the payload type is absent from
the constructor arguments. This does not change storage or payload ownership.

Run `rokit install`, then the scripts under `scripts/verify`: `tests.ps1`, `analyze.ps1`,
`selene.ps1`, `stylua.ps1`, `bench.ps1`, `package.ps1`. PowerShell 7 is required; tools
resolve from `~/.rokit/bin`. Formatting is check-only. Lune/typing use generated copies
with only imports adapted; runtime modules retain script-relative requires and mirrored
public/Impl contracts under `src/types`. Rojo checks the authored tree.

Lune is pinned to 0.10.5. The implementation now uses a file-level native directive;
the earlier per-function annotations required upgrading from 0.8.9.
2026-09-11: 10 test groups passed, including 18,000 reference-model operations and 72,000
lookup pairs. Luau-LSP 1.66.0: zero diagnostics; Selene 0.31.0: zero errors/warnings;
StyLua 2.1.0: clean. Rojo build and Pesde 0.7.4 dry-run archive verification passed.
No Studio integration or ServiceDev full-tree checks were run.

Baseline before annotations: Lune 0.8.9, Windows 10.0.19045, Ryzen 5 5600X; one `os.clock` run,
200,000 iterations per cell, setup excluded. No native annotations or memory measurement.

| Capacity | Append (s) | Latest (s) | Bracket (s) | Mixed (s) | Recycled append (s) |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | .014421 | .014055 | .016125 | .026784 | .014312 |
| 32 | .014523 | .025677 | .030955 | .046334 | .013269 |
| 128 | .014910 | .030953 | .036292 | .053231 | .013466 |
| 1024 | .014539 | .039008 | .043611 | .060223 | .013414 |

Numeric sampling repeats irregular 0-.018-second increments, including duplicates.
Mixed loops add 200,000 lookups, 6,451 cutoff calls and 18,181 pops to their pushes.
Recycled append uses capacity + one records and integer times. Total: 4 million timed
iterations; checksum `379762915017`. Host timings do not guarantee Studio throughput.

## Publication

Provisional: `emdomanus/timestamped_buffer` version `0.1.0`, Roblox, `src/init.luau`.
Confirm name/scope, version, authors and repository URL. Choose a license and include
its file; none was inferred. Nothing was committed, pushed or published.
