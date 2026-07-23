# Security Policy: Shared-Session-Memory-Protocol-Codex-Claude_Code

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.0   | :python_projects:  |

## Reporting a Vulnerability

We take the security of our AI orchestration protocol seriously.
If you find a security flaw or a way to bypass the Safety Gates defined in the protocol, please do not open a public issue.

Instead, report it through the following channel:
- **Email:** zivanoovic.milan@gmail.com
- **Response Time:** You can expect an initial response within 48 hours.

## Scope

This policy applies to the Session Memory Protocol framework, including:
- Receipt and Index schemas
- System hooks (PowerShell/JSON) for AI agent integration
- Standard Design Specs and Priority Selectors

## Core Security Principles

The protocol is built on the principle of Automated Safety to prevent AI agents from performing unauthorized or dangerous actions.
Implementers should adhere to the following:

### Audit and Integrity

Security through transparency is achieved via Immutable Receipts
- Every session must produce a signed, immutable receipt capturing exactly what was done and what evidence was found.

## Secret Management

The protocol templates do not store credentials.
- Implementers are responsible for securing their own environment variables and API keys (e.g., LLM server endpoints, proxy credentials).
- System hooks are designed to be repo versionized but must not include sensitive private data
