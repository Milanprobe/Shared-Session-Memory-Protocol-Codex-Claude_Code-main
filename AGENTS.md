# AGENTS.md

This file provides repository-level guidance for implementing a reusable spec-driven session protocol between two agent tools.

It is a decision-time contract for the repository. Implementation details, tool-specific runtime rules, and slice-level behavior belong in nested `AGENTS.md` files inside the relevant source subtrees.

## Purpose

This template repository defines a generic cross-tool session protocol. It is not tied to any single product, project, or runtime. The goal is to document how a new repository should structure:

- one active spec as the session entrypoint,
- append-only immutable receipts,
- a rebuildable session index,
- explicit evidence artifacts,
- bounded handoff between agent tools.

## Template contract

- One active spec file is enough to start a session.
- Each completed session must write exactly one new immutable receipt for that spec.
- `session-memory/index.json` is derived from receipts and is a lookup optimization, not the source of truth.
- Receipts must remain immutable once written; corrections are represented by new receipts with `supersedes` or `related_receipts`.
- Hooks are integration helpers and should inject context pointers only. They are not an authoritative runtime contract.

## Session entry rules

When a session begins with a single active spec:

1. Read the active spec and the shared session-memory protocol documentation.
2. Load `session-memory/index.json` and the latest receipt for the active `spec_id`.
3. Verify the receipt exists and that its `spec_id` matches the active spec.
4. Load only receipts explicitly referenced by the latest receipt through `related_receipts` or `supersedes`.
5. Select the first open acceptance criterion according to the spec's priority selector.
6. Do not choose work from session history, backlog, or other specs unless the active selector directs it.

This is a bounded context load. Historical receipts are not read by default.

## Cross-tool handoff

This template supports two agent producers, such as Producer A and Producer B. The canonical flow is:

- one tool produces a receipt,
- the next tool reads the latest receipt before selecting work,
- alternation is recommended unless the user explicitly waives it.

If the latest receipt contains `review_findings`, the next session must interpret those findings before choosing the next acceptance criterion.

## Hooks and integration

Example hooks are provided as templates, but actual integration may differ by project.

Hooks should:

- expose the active spec id or spec path,
- expose the latest receipt id, producer, and mode,
- expose review-finding summaries when present.

Hooks should not:

- rewrite specs, receipts, or index files,
- embed full session transcripts into prompts,
- make implementation decisions on behalf of the agent.

## Review and external findings

External findings should be handled with `MODE=REVIEW`. Review sessions should:

- record a REVIEW receipt even when no code changes are made,
- include evidence and verdict metadata,
- preserve outcomes such as `CONFIRMED`, `FALSE_POSITIVE`, `STALE`, or `NOT_REPRODUCED` in receipt fields.

A finding stored only in private client memory or chat is not considered a completed handoff until it is recorded in an immutable receipt.

## Root vs slice rules

Root-level policies in this file are cross-cutting and generic. Detailed runtime or implementation rules belong in nested `AGENTS.md` files next to the code they govern.

Example slice files may include:

- `src/x.../AGENTS.md`
- `src/y.../AGENTS.md`
- `src/z.../AGENTS.md`
- `tests/AGENTS.md`

The root file should never duplicate slice-specific rules. New cross-cutting decisions belong here; feature-specific behavior belongs in the owner subtree.

## What this template is not

- It is not a full runtime implementation.
- It is not tied to a particular project domain, site, or dataset.
- It does not prescribe client-specific folder names or environment values.
- It does not replace project-specific documentation in a new implementation.

## Notes for implementers

- Keep the session protocol generic and project-agnostic.
- Make receipt and index semantics explicit in `session-memory/README.md`.
- Keep `templates/` examples minimal and illustrative.
- Use this file for repository-level mandate, not for runtime detail.
