# Required Data & Artifacts for Implementing the Protocol

This checklist lists the concrete data items and artifacts an implementation must produce or collect to operate the reusable spec-driven session protocol.

- Specs
  - `specs/<spec-file>.md` — stable spec with a `Spec ID`, priority selector, and ordered acceptance criteria.

- Session memory
  - `session-memory/index.json` — rebuildable index mapping `spec_id` → latest receipt and receipt counts.
  - `session-memory/receipts/<spec-id>/` — append-only immutable receipts.
  - `session-memory/receipt.schema.json` — canonical receipt schema for validating receipts.

- Receipts must include
  - `receipt_id`, `spec_id`, `producer`, `created_at`, `mode`, `result`.
  - `head`, `branch`, `commit` — Git context for reproducibility.
  - `artifacts` — linked evidence artifacts (spec, index, screenshots, logs).
  - `evidence` array with small indexed statements and repo refs.
  - `acceptance` array of criteria with PASS/OPEN/FAIL statuses.
  - `open_findings` and `review_findings` when relevant.
  - Optional `mechanism_matrix` for per-field mechanism coverage.

- Evidence artifacts
  - Small trace files for mechanism runs and evidence chains.
  - Linked test harness outputs, focused unit/fixture results, or audit reports.

- Hooks & local integration
  - Example repo hooks that inject the active `spec_id` and latest receipt metadata into agent startup.
  - Scripts to inject session-memory context into an agent runtime (PowerShell/Bash wrappers, or equivalent).

- Operational metadata
  - Agent `producer` identity, session `mode`, and `objective` text.
  - Timestamps and run identifiers for traceability.

- Optional useful telemetry
  - Coverage metadata for mechanism or project health.
  - Regression anchor references for reproducibility checks.

These items support cross-tool handoff, auditability, and reproducible protocol implementation in new repositories.
