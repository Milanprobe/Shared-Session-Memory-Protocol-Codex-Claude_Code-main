# Spec-driven Cross-Tool Session Protocol — Architecture (template)

Purpose
-------
This template documents a reusable spec-driven workflow for coordinating bounded sessions, context handoff, and immutable receipts between two agent tools. It is intentionally tool-agnostic and does not prescribe a single runtime.

High-level components
---------------------
- User / Client: initiates a session with one active `spec` and an optional `MODE`.
- Repo: contains `specs/`, `session-memory/`, artifacts, and agent hook examples.
- Agents: Producer A and Producer B alternate sessions and read the latest receipt before selecting work.

```ASCII Diagram — Component Map
  +------+      +-----------+      +----------------------+      +--------+
  |User/ | ---> | Active    | ---> | Session Memory Store | <--- | Hooks  |
  |Client|      | Spec.md   |      | (receipts/, index.json)|     |(hooks)|
  +------+      +-----------+      +----------------------+      +--------+
                     |  ^                                         |
                     |  |                                         |
                     v  |                                         v
                +-----------------+    load latest receipt      +----------+
                | Selector / Slicer| --------------------------> | Agent A  |
                +-----------------+                            +----------+
                       |                                           |
                       | run (MODE)                                | produces
                       v                                           v
                +-----------------+                             +-----------+
                | Execution / E/P | -- artifacts/evidence --->  | NewReceipt|
                +-----------------+                             +-----------+
                       |                                           |
                       v                                           v
                   commit + push  -------------------------------> index.json
```

Sequence Diagram — Session Lifecycle (simplified)

  1. User starts session with one active `spec` and optional `MODE`.
  2. Agent loads the `spec` and reads `session-memory/index.json` for the latest receipt.
  3. If latest receipt exists, agent reads the receipt and any `review_findings`.
  4. Selector chooses the first OPEN acceptance criterion from the `spec` unless an explicit mode overrides.
  5. Agent executes bounded work and emits evidence/artifacts.
  6. Agent writes an immutable `receipt` JSON into `session-memory/receipts/<spec-id>/` and updates `index.json`.
  7. Agent commits the receipt, updated index, and linked artifacts.

ASCII Diagram — Sequence
```
  [User] -> (spec) -> [Agent startup]
  [Agent] -> read -> [session-memory/index.json]
  [Agent] -> read -> [latest receipt (if any)]
  [Agent] -> select -> [acceptance criterion]
  [Agent] -> execute bounded run -> produce artifacts
  [Agent] -> write -> [receipts/<spec-id>/RECEIPT.json]
  [Agent] -> update -> [session-memory/index.json]
  [Agent] -> commit -> git commit (receipt + index + artifacts)
```

Key contracts and invariants
----------------------------
- Single-spec session: every session must start with exactly one active `spec`.
- Immutable receipts: each finished session MUST write exactly one immutable receipt file; receipts are append-only.
- Index is rebuildable: `index.json` is a performance aid and must be derivable from receipts.
- Review-first: when `latest_receipt` contains `review_findings`, the next agent must read and correlate those findings before selecting work.
- Evidence-first safety: blocking evidence (access/challenge) prevents live probes until explicitly resolved.

Receipt structure (high-level)
------------------------------
- `receipt_id`, `spec_id`, `producer`, `created_at`
- `mode`, `objective`, `result`, `commit`, `head`, `branch`
- `artifacts`: array of linked artifact paths (spec, index, screenshots, HTML)
- `evidence`: small indexed statements with refs into repo artifacts
- `acceptance`: list of acceptance criteria and PASS/OPEN statuses
- `open_findings`, `blockers`, `review_findings`
- Optional: `mechanism_matrix` describing per-field mechanism PASS/FAIL/NOT_OBSERVED

Artifact and evidence rules
---------------------------
- Do not copy large evidence into the receipt — link to artifact paths instead.

Template usage
--------------
1. Copy this template folder into a new project root.
2. Populate `specs/` with your project spec(s).
3. Implement session-memory write/read hooks used by your agents.
4. Ensure your agents read the latest receipt before running selectors.

See `REQUIRED_DATA.md` for the concrete data items you must collect/implement.

Implementation notes
--------------------
- Implement session-memory write/read hooks used by your agents.
- Keep runtime hook integration generic and avoid product-specific client folder names.
