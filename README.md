# Minority

Minority is a native macOS personal life management application. It is built as a local-first modular monolith, with offline core functionality and a SwiftUI interface.

## Project status

Foundation A (native macOS bootstrap), Foundation B (SQLite persistence with GRDB), and Foundation C1 (core planning persistence) are published. TASK-D-001 and TASK-D-002 were accepted for their limited scopes. Technical Alpha WF-01 adds reuse of an existing Activity across Plans without copying the Activity record; the complete flow passed isolated UI/offline verification and was accepted for that scope (DEC-023). The user approved the Product MVP scope in DEC-025: WF-01 plus one manual execution record per scheduled occurrence and a history view. The execution-record slice passed build, persistence, isolated UI/relaunch/save-error checks, temporary bundle validation, and a new offline UI check (EV-BLD-008 through EV-UI-009). Code is published as `334bf5761b48f30c5df4bbbb75e489d39b67a230`; Quality run 39368235871 completed successfully. Product MVP implementation acceptance and release readiness remain pending; OPEN-008 release gates still apply.

## Development guide

- [Masterplan and phased scope](docs/MASTERPLAN.md)
- [Requirements and acceptance criteria](docs/REQUIREMENTS.md)
- [Decisions and architecture](docs/DECISIONS.md)
- [Progress, verification evidence, and commits](docs/PROGRESS.md)
- [Coding-agent rules and completion checks](AGENTS.md)

TASK-D-001 is accepted and published for its Plan-only scope. TASK-D-002 is accepted for Activity creation, Plan linking, and one-time scheduling. The user-approved Product MVP scope is recorded in [DEC-025](docs/DECISIONS.md); implementation, verification, acceptance, and release readiness are tracked separately. Technical Alpha and Product MVP release readiness remain subject to OPEN-008. Link work to requirements and acceptance criteria, follow existing code patterns, and keep product decisions, implementation, verification, acceptance, and Git status distinct in the project documents.

Development interaction uses Codex in the ChatGPT Desktop graphical interface against the existing local Minority repository (DEC-017, CONFIRMED). The user is not required to operate Codex CLI. Commands documented below are available for Codex to execute internally when needed; native macOS build verification remains local.

The [release strategy](docs/MASTERPLAN.md#strategi-rilis) distinguishes a planning/scheduling **Technical Alpha**, the **Product MVP** scope approved by the user in DEC-025, and **Extended Releases** selected through the roadmap. Audit conclusions and proposed release classifications are not direct user approval. Product MVP scope approval does not mean the implementation is finished or release-ready. Backup, recovery, and database upgrade safety must be defined and tested before routine use with important personal data.

## Technology

- Swift and SwiftUI
- SQLite through GRDB
- Swift Package Manager
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

## Planned functionality

- Daily, monthly, and yearly planning
- Perintah Induk and Perintah Harian
- Execution tracking beyond the initial manual occurrence record
- Multidimensional, classification-based evaluation and rule-based decision support
- Personal document management
- PDFKit and Vision OCR
- Hybrid semantic search and local multilingual embeddings
- Structured JSON planning import

These broader capabilities are planned and are not part of the approved Technical Alpha WF-01 scope. Activity creation, Plan linking, and explicit one-time scheduling are implemented under TASK-D-002 and accepted for that scope.

## Current limitations

- TASK-D-002 supports creating Activities within an existing Plan and adding one-time occurrences; the current WF-01 flow also lets users link an existing Activity to another Plan. Recurring schedules and editing or deleting records remain unsupported.
- The database has the original `foundation` migration plus additive `planning_v1` and `execution_v1` migrations. The C1 persistence checkpoint predates the Plan and Activity UI added by later tasks; implementation of these slices does not constitute acceptance of the complete domain/product design.
- Persistence checks must be run through `MinorityPersistenceChecks`; `swift test` has no test target to run.
- The packaged app is ad hoc signed and is not ready for public distribution or notarization.
