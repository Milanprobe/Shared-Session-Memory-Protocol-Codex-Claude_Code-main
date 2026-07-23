# Session memory protocol

This folder documents a reusable, tool-agnostic session-memory protocol for a repository that coordinates bounded work between two agent tools.

The protocol is intentionally generic and does not rely on any specific project paths, project details, or client configuration. It describes the canonical contract for active specs, receipts, indexes, and evidence in a cross-tool handoff workflow.

## Model

- `spec` = stable session entrypoint and ordered acceptance criteria.
- `receipt` = immutable facts produced by one completed session.
- `index.json` = rebuildable catalog of receipts, not the source of truth.
- shared project memory = active spec + receipts + index + explicitly linked evidence.
- Git + declared artifacts = reproducible evidence.

## 1. Authority order

If sources disagree, prefer:

1. live code/runtime protocol and repository-owned agent hooks.
2. active spec and its priority selector.
3. individual immutable receipt files.
4. `index.json` as a lookup optimization.
5. archived notes or historical documents only as audit history.

Agent transcripts, private client memory, chat logs, or notebook drafts are not evidence until they are reproduced against live code, specs, receipts, or linked artifacts.

## 2. Shared memory contract

Shared memory is not a global mutable file that both clients copy and edit.

Instead, the shared repo-owned protocol is:

- one active spec defines the current work scope;
- receipts are append-only facts from completed sessions;
- the index is rebuildable from receipts;
- evidence artifacts are linked explicitly, not copied into prompts;
- hooks inject only pointers and context metadata, not full session transcripts.

This bounded design keeps token usage low and prevents stale or private client state from overriding the repo contract.

## 3. Single-spec session entry

When a session starts with exactly one active spec:

1. read the spec, the protocol, and the shared session-memory README.
2. load `session-memory/index.json` and the latest receipt for the active `spec_id`.
3. verify that the receipt exists, that its `spec_id` matches, and that the index is consistent.
4. load only receipts explicitly referenced by the latest receipt via `related_receipts` or `supersedes`.
5. select the first `OPEN` or `FAIL` acceptance criterion according to the spec's priority selector.
6. do not choose work from session history or backlog unless the selector arrives there.

This is a bounded context load. Do not read all historical receipts by default.

## 4. Tool alternation and review

For a cross-tool workflow, the canonical handoff is:

- one session by one tool produces a receipt;
- the next session by the alternate tool reads that latest receipt before choosing work.

If the latest receipt contains `review_findings`, the next session must interpret those findings before selecting the next acceptance criterion.

If the same producer appears twice in a row, the hooks should warn that alternation is expected but may allow an explicit user override.

## 5. MODE semantics

The protocol supports explicit modes such as `AUTO`, `P`, `E`, `FIX`, and `REVIEW`.

- `AUTO` means the tool chooses the next bounded slice based on the active spec and receipt state.
- `P` is a design or plan-oriented session.
- `E` is an execution/implementation session.
- `FIX` is a corrective session for a known issue.
- `REVIEW` is an evidence or claim review session.

A prompt that ships new external findings or asks for verification of a claim should normally be treated as `MODE=REVIEW`, not as a plain `AUTO` implementation session.

## 6. Receipt closeout contract

Every completed session must write exactly one new receipt for the active spec.

- receipts must follow `session-memory/receipt.schema.json`.
- receipt filenames should be stable and unique, such as `receipts/<spec-id>/<PREFIX>-NNNN-<slug>.json`.
- `receipt_id` should not be reused.
- receipts must record producer, mode, objective, result, artifacts, evidence, acceptance status, open findings, and blockers.
- existing receipts must never be modified; corrections use a new receipt with `supersedes`.
- closeout includes updating `index.json` and committing the receipt plus linked artifacts.

The index is authoritative only as a derived lookup; receipts remain the source of truth.

## 7. Index contract

`index.json` should contain:

- spec id → spec path mapping;
- latest receipt id and receipt count per spec;
- a rebuild rule describing that the index can be recomputed from receipts.

It should not contain session decisions or remaining work scope. Those are always derived from the active spec and latest receipt state.

## 8. Prompt guidance

A minimal session prompt should name one active spec and one mode.

Example:

```text
Continue from specs/<spec-file>.md. MODE=AUTO.
```

A prompt should not attempt to copy the full protocol or all receipts into the spec text.

## 9. Hook integration

Project hooks are examples for bootstrapping client context. They should inject:

- the active spec id or spec path;
- latest receipt id, producer, and mode;
- review finding summaries when present.

Hooks must not rewrite specs, receipts, indexes, or evidence. They are context pointers only.

## 10. Audit snapshot guidance

If the repository includes a schema snapshot or audit artifact, treat it as evidence of a specific client surface at a point in time, not as a live protocol contract. The audit snapshot can help explain integration decisions, but the runtime contract is defined by the active spec, receipts, index, and current hook implementation.
