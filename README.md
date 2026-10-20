# Minority

Minority is a native macOS personal life management application. It is built as a local-first modular monolith, with offline core functionality and a SwiftUI interface.

## Project status

Foundation A/B/C1, TASK-D-001, TASK-D-002, WF-01, TASK-D-003, and TASK-F-001 have published implementation checkpoints. By DEC-026, all currently planned capabilities D–J and product hardening K are implemented in the single Minority app; the roadmap implementation was published on `main` at `81aaf7f` (full evidence in project progress). Local checks cover build, persistence, import, document/OCR, multilingual semantic search, offline use, and backup/restore; final user acceptance and manual review remain pending. Search quality/resource budgets (OPEN-007) and release/distribution, backup handling, and basic performance gates (OPEN-008) remain open, so implementation completion is not a claim of release readiness. See [project progress](docs/PROGRESS.md) for evidence and current Git status.

## Development guide

- [Masterplan and phased scope](docs/MASTERPLAN.md)
- [Requirements and acceptance criteria](docs/REQUIREMENTS.md)
- [Decisions and architecture](docs/DECISIONS.md)
- [Progress, verification evidence, and commits](docs/PROGRESS.md)
- [Coding-agent rules and completion checks](AGENTS.md)

TASK-D-001 is accepted and published for its Plan-only scope. TASK-D-002 is accepted for Activity creation, Plan linking, and one-time scheduling. Product MVP scope is recorded in [DEC-025](docs/DECISIONS.md); the subsequent authorization to implement every capability currently in the roadmap before final manual review is [DEC-026](docs/DECISIONS.md). Implementation, verification, acceptance, and release readiness remain separate statuses; OPEN-008 release gates still apply. Link work to requirements and acceptance criteria, follow existing code patterns, and keep product decisions, implementation, verification, acceptance, and Git status distinct in the project documents.

Development interaction uses Codex in the ChatGPT Desktop graphical interface against the existing local Minority repository (DEC-017, CONFIRMED). The user is not required to operate Codex CLI. Commands documented below are available for Codex to execute internally when needed; native macOS build verification remains local.

The [release strategy](docs/MASTERPLAN.md#strategi-rilis) distinguishes a planning/scheduling **Technical Alpha**, the **Product MVP** scope approved by the user in DEC-025, and **Extended Releases** selected through the roadmap. Audit conclusions and proposed release classifications are not direct user approval. Product MVP scope approval does not mean the implementation is finished or release-ready. Backup, recovery, and database upgrade safety must be defined and tested before routine use with important personal data.

## Technology

- Swift and SwiftUI
- SQLite through GRDB
- Swift Package Manager
- Apple frameworks: PDFKit for document/PDF handling, Vision for on-device OCR, and NaturalLanguage for local contextual embeddings
- Modular monolith: the app and persistence layer are separate Swift targets in one application
- Local-first storage at `~/Library/Application Support/Minority/minority.sqlite`

The application database is local and requires no network service at runtime. Swift Package Manager may need network access to fetch GRDB when building on a machine where the dependency is not already cached.

## Build and run

Requirements: macOS 15 or later and a Swift 6 toolchain.

Build the package:

```sh
swift build
```

Run the macOS app:

```sh
swift run Minority
```

## Verification

Run the persistence verification executable:

```sh
swift run MinorityPersistenceChecks
```

It checks database initialization, read/write behavior, migration idempotency and upgrade from a populated planning database, preservation of existing data when initialization fails, transaction rollback, SQLite error propagation, and execution-record uniqueness and persistence. This is a standalone executable target; the package does not currently define an XCTest target.

Persistence checks alone do not verify offline UI functionality; that requires exercising the released UI flows without a network connection. Basic UI, startup, and database performance have separate acceptance criteria from semantic search performance. Numerical targets remain open.

The [Quality workflow](.github/workflows/quality.yml) builds the package using resolved dependencies and runs persistence checks on macOS for pull requests to `main`, pushes to `main`, or manual runs. Publication and actual run results are recorded in [progress](docs/PROGRESS.md); a passing result and required merge protection must be verified separately. UI behavior is outside these automated checks.

## Package the macOS app

Create `dist/Minority.app`:

```sh
./scripts/package-app.sh
```

Open the packaged app:

```sh
open dist/Minority.app
```

The packaging script builds the release executable, creates the app bundle, and applies an ad hoc code signature. It does not produce a Developer ID signed or notarized distribution.

## Implemented execution-record slice

For a scheduled occurrence, the user can explicitly record that it was completed and view the record. The record is unique to the occurrence and shows when it was entered; this timestamp is not presented as the actual time the activity happened. No record means the occurrence has not been recorded, not that it failed. This initial slice has no score or correction flow; an incorrect record cannot currently be edited or removed.

## Roadmap functionality

- Daily, monthly, and yearly planning
- Perintah Induk and Perintah Harian
- Execution tracking beyond the initial manual occurrence record
- Multidimensional, classification-based evaluation and rule-based decision support
- Personal document management
- PDFKit and Vision OCR
- Hybrid semantic search and local multilingual embeddings
- Structured JSON planning import
- Objectives shared across Plans

The listed roadmap capabilities are implemented in the canonical Minority app and published. Their final manual acceptance and release readiness remain separate; see `docs/PROGRESS.md` for verification evidence and open gates.

### Planning JSON import format

Import uses the versioned `minority.planning` JSON format. `format` and `version` are required; entity and relationship arrays may be omitted when unused. IDs are UUID strings. Unknown versions, invalid records, missing references, repeated IDs/links, and conflicting existing IDs block the whole import. Exact duplicates are skipped.

```json
{
  "format": "minority.planning",
  "version": 1,
  "plans": [
    {
      "id": "9b3fa6d6-a8d4-4c39-8ee1-3f85f9d2f0aa",
      "title": "Example Plan",
      "startDate": "2026-10-20",
      "endDate": "2026-10-31"
    }
  ]
}
```

## Current limitations

- Activities can be linked to multiple Plans; schedules are explicit one-time occurrences. Recurrence and editing/deleting Plans, Activities, and occurrences remain unsupported.
- Objectives can be shared across Plans, edited as one master record, unlinked per Plan, and deleted only when no Plan links remain.
- The database has the original `foundation` migration plus additive `planning_v1`, `execution_v1`, `objectives_v1`, and locally implemented `commands_v1` migrations. These implementation slices do not constitute acceptance of the complete domain/product design.
- Persistence checks must be run through `MinorityPersistenceChecks`; `swift test` has no test target to run.
- The packaged app is ad hoc signed and is not ready for public distribution or notarization.
