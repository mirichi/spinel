# Analyze ↔ Codegen IR

The Spinel compiler runs in three stages, each as a separate binary:

```
.rb  ──[spinel_parse]──▶  .ast  ──[spinel_analyze]──▶  .ir  ──[spinel_codegen]──▶  .c
```

`spinel_analyze` produces `.ir`; `spinel_codegen` consumes it. This file
documents that contract: the file format, every tag, every ivar that
crosses the boundary, and the constraints either side relies on.

The IR is the only artefact the two binaries share. They do not share
heap state, do not share an in-memory `Compiler` instance, and do not
re-derive each other's results. If a piece of analysis state is not in
the IR, codegen does not have it.

## File format

Plain UTF-8 text, line-oriented (`\n`-terminated). The first line is the
literal version stamp:

```
SPINEL-IR v1
```

Every subsequent line is a single record:

```
<tag> <name-or-nid> [<count>] <payload>
```

Fields are space-separated. Payload encoding rules below depend on tag.
A line is one whole record — newlines never appear inside payload values
(they are percent-encoded).

### Tags

| Tag  | Shape                          | Carries                                                                  |
|------|--------------------------------|--------------------------------------------------------------------------|
| `INT`| `INT @ivar <integer>`          | scalar integer ivar (counters, feature-need flags)                       |
| `STR`| `STR @ivar <encoded-string>`   | scalar string ivar (`@cls_meth_live`, `@cls_cmeth_live`)                 |
| `SA` | `SA  @ivar <count> <pipe-strs>`| length-prefixed `Array<String>` (every analysis-derived parallel array)  |
| `IA` | `IA  @ivar <count> <csv-ints>` | length-prefixed `Array<Int>` (body ids, sizes, offsets, flags)           |
| `T`  | `T <nid> <encoded-type>`       | per-AST-node inferred type (the cache that lets codegen skip `infer_type`) |
| `NM` | `NM <nid> <encoded-name>`      | per-AST-node `@nd_name` override (`__sp_ieval_<N>` rewrites)             |
| `NB` | `NB <nid> <int>`               | per-AST-node `@nd_block` override (rewritten ieval call sites)           |
| `SN` | `SN <nid> <pipe-strs>`         | per-scope local-decl names (one entry per scope body)                    |
| `ST` | `ST <nid> <pipe-strs>`         | per-scope local-decl types (paired with SN)                              |

`INT`, `STR`, `SA`, `IA` mirror compiler-instance state by ivar name.
`T`, `NM`, `NB`, `SN`, `ST` are sparse per-node records — they only emit
for nodes whose value differs from the default, so codegen fills the
rest with the default at load time.

### Encoding

Strings (the payload of `STR`, the elements of `SA` / `T` / `NM` / `SN`
/ `ST`) are percent-encoded for the four characters that would
otherwise collide with the line-and-pipe split:

| Char   | Encoded |
|--------|---------|
| space  | `%20`   |
| `\n`   | `%0A`   |
| `\r`   | `%0D`   |
| `\t`   | `%09`   |
| `%`    | `%25`   |
| `\|`   | `%7C`   |

`SA` payloads are `<count> <e1>|<e2>|…|<en>`. The leading `<count>`
distinguishes `[]` (count 0, body empty) from `[""]` (count 1, body
empty after pipe split) — both serialise to identical bodies, so the
loader uses the count to pad with empty strings.

`IA` payloads are `<count> <e1>,<e2>,…,<en>`. Same count guarantee.

## Pipeline contract

### What analyze populates

`Compiler#analyze_phase` (spinel_analyze.rb) runs to fixpoint:

1. `collect_all` — walks the AST, registers classes, methods, modules,
   constants, ivars, FFI declarations.
2. `infer_main_call_types` / `infer_function_body_call_types` /
   `infer_class_body_call_types` / `infer_ieval_body_call_types` —
   per-scope call-site widening.
3. `detect_poly_locals`.
4. Iterative loop (≤ 4 rounds): `infer_all_returns`,
   `infer_*_call_types`, `infer_ivar_types_from_writers`,
   `infer_param_array_type_from_body`,
   `narrow_param_types_from_body_method_calls`,
   `narrow_param_hash_types_from_body_writes`, `detect_poly_params`.
   Loop terminates when `inference_signature` (a fingerprint over
   return-types, ivar-types, param-types, cmeth-ptypes) is unchanged.
5. `fix_nil_ivar_self_refs`, then re-run inference passes.
6. `refine_all_module_ivar_types` (uses now-stable param types to
   refine module-ivar hash / array specialisation), then re-run.
7. `fix_lambda_return_types`.
8. `pre_detect_bigint`, `detect_features`.
9. `detect_value_types`, `recalc_needs_gc`, `collect_sym_names`,
   `scan_toplevel_ivars`, `compute_live_cls_methods`,
   `compute_live_instance_methods`.
10. Sets `@analysis_frozen = 1`.
11. `precompute_all_scope_decls` — walks every method / cmeth / ieval /
    main scope, runs the full multi-pass local-decl refinement (used
    to be re-derived in `emit_main` and `declare_method_locals`),
    stores the result in `@nd_scope_names[bid]` /
    `@nd_scope_types[bid]` (pipe-joined per body).
12. `annotate_all_node_types` (`walk_and_cache`) — post-order walks
    every reachable AST node, calls `infer_type`, fills
    `@nd_inferred_type[nid]`. Targets non-block-body nodes (block
    iteration scope is iterator-specific and resolved at emit time).

After step 12 the compiler dumps state via `dump_analysis_buf`.

### What codegen consumes

`spinel_codegen.rb`:

1. Parses the AST file (same `read_text_ast` as analyze; fresh
   `Compiler` instance with empty tables).
2. Calls `load_analysis_buf` on the IR to overwrite scalar / array
   ivars and per-node caches.
3. Calls `generate_code`, which assumes the compiler is in the same
   "post-analysis" shape analyze left it in:
   - `@cls_is_value_type`, `@needs_gc`, `@sym_names`,
     `@toplevel_ivar_*`, `@cls_meth_live`, `@cls_cmeth_live` are
     pre-populated. `generate_code` does not re-run
     `detect_value_types`, `compute_live_*`, etc.
   - `@nd_inferred_type[nid]` is the cache `infer_type` consults
     before running the dispatch tree (>99 % hit rate at emit).
   - `@nd_scope_names[bid]` / `@nd_scope_types[bid]` are read by
     `declare_method_locals`, `emit_main`, and the inline-yield body
     emitters in lieu of re-running `scan_locals`.
4. Walks AST, emits C, writes to stdout or `out.c`.

### What stays in codegen by design

Some helpers conceptually belong to analysis but their results are
consumed only at emit time, so they stayed in `spinel_codegen.rb`:

- `infer_array_elem_type`, `infer_hash_val_type`, `unify_call_types` —
  used inside `compile_array_literal_from_ids`, `compile_hash_literal`,
  `body_yield_arg_types`. The values they compute are emit-site-local
  and are not part of any per-program table.
- `cls_meth_is_live`, `cls_cmeth_is_live` — read the pipe-joined
  `@cls_meth_live` / `@cls_cmeth_live` strings analyze produced. The
  membership-test wrappers stay codegen-side because they are pure
  consumers.
- Block-iteration scope: `infer_type` for nodes inside a block body
  does its own dispatch since the iterator-derived block-param types
  (`each` / `map` / `each_with_index` / `each_pair` / `tap` / `scan` /
  `Fiber.new` / etc.) are not pre-cached. `walk_and_cache` skips block
  bodies for exactly this reason; codegen's own `infer_type` does the
  iterator-specific scope push when it traverses into one.
  `proc` / `lambda` / `Proc.new` blocks are also intentionally skipped
  — their param type is determined by the runtime caller and
  `compile_lambda_def` hardcodes `int` for the param.

## Per-ivar contract

Every ivar listed below is round-tripped through the IR. Codegen has
no analysis-side derivers for any of them — if analyze does not write
the record, codegen sees the default value (`0`, `""`, `[]`).

### Counters / scalars (`INT`)

| Ivar              | Meaning                                                                 |
|-------------------|-------------------------------------------------------------------------|
| `@nd_count`       | Total AST node count. Codegen sizes its parallel arrays from this.      |
| `@root_id`        | Root ProgramNode id (entry into AST traversal).                         |
| `@analysis_frozen`| Set to `1` after `analyze_phase` finishes (advisory; codegen ignores).  |
| `@ieval_counter`  | Counter used to mint `__sp_ieval_<N>` synthetic method names.           |

### Feature-need flags (`INT`, all default `0`)

`@needs_gc`, `@needs_system`, `@needs_int_array`, `@needs_float_array`,
`@needs_str_array`, `@needs_str_int_hash`, `@needs_str_str_hash`,
`@needs_int_str_hash`, `@needs_sym_int_hash`, `@needs_sym_str_hash`,
`@needs_sym_intern`, `@needs_setjmp`, `@needs_mutable_str`,
`@needs_rb_value`, `@needs_regexp`, `@needs_rand`, `@needs_stringio`,
`@needs_lambda`, `@needs_fiber`, `@needs_bigint`, `@needs_poly_array`,
`@needs_poly_poly_hash`, `@needs_str_poly_hash`, `@needs_sym_poly_hash`,
`@needs_ptr_array`, `@needs_file_io`. Each toggle gates an emit of the
corresponding runtime helper block.

### Live-method tables (`STR`)

| Ivar               | Meaning                                                                   |
|--------------------|---------------------------------------------------------------------------|
| `@cls_meth_live`   | `;`-joined `<ClassName>::<method>` entries for live instance methods.     |
| `@cls_cmeth_live`  | `;`-joined entries for live class methods. Both used by DCE stub emit.    |

### Top-level methods (`SA` / `IA`)

`@meth_names`, `@meth_param_names`, `@meth_param_types`,
`@meth_param_empty`, `@meth_return_types`, `@meth_body_ids` (IA),
`@meth_has_defaults`, `@meth_rest_index` (IA), `@meth_has_yield` (IA).

These are the parallel arrays codegen reads in `emit_toplevel_method`,
`compile_no_recv_call_expr`, the bare-call dispatch paths, etc.

### Class tables (`SA` / `IA`)

`@cls_names`, `@cls_parents`, `@cls_ivar_names`, `@cls_ivar_types`,
`@cls_ivar_init_definite`, `@cls_ivar_observed_types`,
`@cls_meth_names`, `@cls_meth_params`, `@cls_meth_ptypes`,
`@cls_meth_returns`, `@cls_meth_bodies`, `@cls_meth_defaults`,
`@cls_meth_ptypes_empty`, `@cls_attr_readers`, `@cls_attr_writers`,
`@cls_cmeth_names`, `@cls_cmeth_params`, `@cls_cmeth_ptypes`,
`@cls_cmeth_returns`, `@cls_cmeth_bodies`, `@cls_cmeth_defaults`,
`@cls_is_value_type` (IA), `@cls_is_sra` (IA), `@cls_meth_has_yield`,
`@cls_method_adapters`.

The per-class entries inside each `SA` are joined by `;` (between
methods of one class) and `|` (between classes). Joining and splitting
is consistent with the helper API (`cls_meth_pnames_get`,
`cls_meth_ptypes_get`, etc.) on both sides.

### Constants / cvars / gvars (`SA` / `IA`)

`@const_names`, `@const_types`, `@const_expr_ids` (IA),
`@const_scope_names`, `@cvar_names`, `@cvar_types`,
`@cvar_init_values`, `@gvar_names`, `@gvar_types`,
`@multi_const_inits`.

### Modules (`SA` / `IA`)

`@module_names`, `@module_body_ids` (IA), `@module_acc_keys`,
`@module_acc_consts`.

### FFI (`SA` / `IA`)

`@ffi_modules`, `@ffi_module_libs`, `@ffi_module_cflags`,
`@ffi_func_modules`, `@ffi_func_names`, `@ffi_func_arg_types`,
`@ffi_func_ret_types`, `@ffi_func_arg_specs`, `@ffi_func_ret_specs`,
`@ffi_buf_modules`, `@ffi_buf_names`, `@ffi_buf_sizes` (IA),
`@ffi_reader_modules`, `@ffi_reader_names`, `@ffi_reader_kinds`,
`@ffi_reader_offsets` (IA).

### Regexp / dyn-regex / local-regex (`SA` / `IA`)

`@regexp_patterns`, `@regexp_flags`, `@dyn_regex_node_ids` (IA),
`@dyn_regex_flags`, `@local_regex_names`, `@local_regex_idx` (IA).

### Misc (`SA` / `IA`)

`@open_class_names`, `@method_ref_vars`, `@method_ref_names`,
`@galias_new`, `@galias_old`, `@undef_class_idx` (IA), `@undef_method`,
`@sym_names`, `@tuple_types`, `@poly_funcs`, `@poly_param_types`,
`@ieval_class_idxs` (IA), `@ieval_body_ids` (IA),
`@pre_execution_blocks` (IA), `@post_execution_blocks` (IA),
`@toplevel_ivar_names`, `@toplevel_ivar_types`,
`@lambda_var_ret_names`, `@lambda_var_ret_types`.

## Per-AST-node records

These records are sparse — a record is emitted only when the value
differs from the default, so the count is bounded by the size of the
analysis result, not by `@nd_count`.

### `T <nid> <type>` — inferred-type cache

Filled by `annotate_all_node_types` for every reachable node outside
block bodies. Codegen's `infer_type(nid)` checks `@nd_inferred_type[nid]`
first; non-empty cache hit returns immediately, otherwise it runs the
dispatch tree (still kept in codegen for block-body expressions and
the `SuperNode` / `ForwardingSuperNode` arms that need
`@current_class_idx` context).

### `NM <nid> <name>` — `@nd_name` override

Emitted only for `rewrite_instance_eval_calls` rewrites that re-stamp
a CallNode's name to `__sp_ieval_<N>`. The matching `NB` record below
clears the call's block. Codegen does not re-run the rewrite; the IR
ports the result.

### `NB <nid> <int>` — `@nd_block` override

Emitted alongside `NM` when an ieval call's block was lifted into
`@ieval_body_ids` and the AST callsite's block is now `-1`.

### `SN <nid> <pipe-names>` and `ST <nid> <pipe-types>` — scope locals

One pair per scope body whose local declarations are non-empty. The
ids are body-node ids (top-level main, top-level method bodies,
instance method bodies, class method bodies, ieval bodies). Codegen
calls `declare_method_locals(bid, pnames)` which short-circuits on
`@nd_scope_names[bid]` instead of re-running the multi-pass
`scan_locals` refinement.

The pairing is positional — `SN` element `i` declares the local whose
type is `ST` element `i`. Both arrays have the same length.

## Loading order

`load_analysis_buf` processes records in the order they appear in the
file. Order matters in two places:

1. `INT @nd_count` must precede any per-node record (`T`, `NM`, `NB`,
   `SN`, `ST`). The loader bound-checks `nid < @nd_count` and silently
   drops records out of range; with `@nd_count` not yet set, every
   per-node record would be dropped. `dump_analysis_buf` emits
   `@nd_count` as the first scalar after the version stamp for this
   reason.
2. Class / method tables (`SA`) load before any `T` record that names
   a class or method type (`obj_<C>`, `class`, etc.) — codegen does
   not re-validate types at load, so a downstream consumer that calls
   `find_class_idx` against an unloaded `@cls_names` would miss. In
   practice the dump order keeps the parallel-array tables ahead of
   per-node records, so this is not a problem with the current
   serialiser, but reordering the SA / IA emit block requires
   matching loader awareness.

## Statistics

For the bootstrap input `spinel_codegen.rb` (~28.9 K Ruby lines, ~123 K
AST nodes):

| Category   | Count   | Notes                                                            |
|------------|---------|------------------------------------------------------------------|
| `T`        | ~101 K  | Per-node inferred-type cache, ~99 % hit rate at emit             |
| `SN` / `ST`| ~370 each | Scope-body local-decl pairs                                    |
| `SA`       | ~73     | Analysis-derived parallel arrays                                 |
| `INT`      | ~30     | Counters + feature-need flags                                    |
| `IA`       | ~16     | Body-id arrays, flag arrays                                      |
| `STR`      | ~2      | Live-method tables                                               |
| File size  | ~1.5 MB | Round-trip fixpoint stable (`gen2.ir == gen3.ir`)                |

## Gotchas

- **Length-prefixed split** is non-negotiable for `SA` / `IA`. The
  empty array and the single-empty-element array serialise to the
  same body; only the `<count>` distinguishes them. `ir_split_strs_n`
  / `ir_split_ints_n` pad up to the recorded count when the body
  parses to fewer elements.
- **Percent-encoding** must round-trip — the encoder escapes ` `, `\n`,
  `\r`, `\t`, `%`, `|`, but downstream consumers may rely on other
  characters surviving. Adding new escape rules requires updating both
  `ir_escape` (analyze) and `ir_unescape` (codegen).
- **Two-string `O(N²)` trap**: the original `dump_analysis_buf`
  appended T-records with `buf = buf + line` in a loop; for the ~150 K
  T-records in spinel_codegen.rb's self-host, that quadratic
  reallocation pattern blew the heap to 60 GB on the spinel-compiled
  analyze binary. The current implementation accumulates record
  strings into a `StrArray` and joins once at the end. Any new
  per-node record loop should follow the same pattern.
- **Block-body type cache is empty by design**. Codegen's
  `infer_type` is the authoritative path for block-body expressions
  because the iterator-derived block-param types are not pre-cached
  by `walk_and_cache`. Adding `T` records for block-body nids is not
  a no-op — it would override the iterator-specific scope codegen
  pushes during traversal.
- **Bootstrap fixpoint is 4-way**, not 2-way. `make bootstrap`
  verifies both `analyze.rb` and `codegen.rb` round-trip through the
  pipeline in both the IR (`analyze.rb: IR fixpoint OK`) and C
  (`codegen.rb: C fixpoint OK`) dimensions. A change that affects
  either side's deterministic output (record order, string
  formatting, default-value handling) breaks the fixpoint and the
  bootstrap fails.

## Format version

`SPINEL-IR v1` is the only version recognised. The loader treats the
literal version line as a comment — any other text on the first
non-empty line is silently ignored, so a future v2 format that
extends the tag set must change the version stamp and matching loader
logic together.

## Adding a new ivar

1. Decide tag: scalar int → `INT`, scalar string → `STR`, array of
   strings → `SA`, array of ints → `IA`, per-node attribute → `T` /
   `NM` / `NB` / `SN` / `ST`.
2. Add the emit line in `dump_analysis_buf`
   (spinel_analyze.rb#dump_analysis_buf).
3. Add the matching loader arm in `ir_set_int_ivar` /
   `ir_set_str_ivar` / `ir_set_sa_ivar` / `ir_set_ia_ivar`
   (spinel_codegen.rb).
4. Initialise the ivar to its default value in
   `Compiler#initialize` on **both** sides — codegen relies on the
   ivar existing as a struct field for self-host typing.
5. Run `make bootstrap` and verify all four fixpoints
   (`analyze.rb: IR fixpoint OK`, `analyze.rb: C fixpoint OK`,
   `codegen.rb: IR fixpoint OK`, `codegen.rb: C fixpoint OK`).
