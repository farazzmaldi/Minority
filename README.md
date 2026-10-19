# Minority

Minority is a native macOS personal life management application. It is built as a local-first modular monolith, with offline core functionality and a SwiftUI interface.

## Project status

Foundation A (native macOS bootstrap), Foundation B (SQLite persistence with GRDB), and Foundation C1 (core planning persistence) are committed. C1 was published to `origin/main` as `7e268be9b3230675fccc34ff06e038f6651c149f`, with the remote SHA verified on 19 October 2026. TASK-D-001 adds local Plan creation and listing plus a manual English/Bahasa Indonesia interface-language setting. The user accepted its Plan-scoped implementation on 20 October 2026; it was published in commit `2b6b762f828833193fced97c60c81d87bd212a6f`. Activity, schedule, and other planning workflows remain unimplemented. This task acceptance does not approve Technical Alpha or Product MVP.

## Development guide

- [Masterplan and phased scope](docs/MASTERPLAN.md)
- [Requirements and acceptance criteria](docs/REQUIREMENTS.md)
- [Decisions and architecture](docs/DECISIONS.md)
- [Progress, verification evidence, and commits](docs/PROGRESS.md)
- [Coding-agent rules and completion checks](AGENTS.md)

TASK-D-001 is accepted and published for its Plan-only scope. Before implementing another feature, obtain explicit user approval for the next scope; Technical Alpha remains PROPOSED, and Product MVP scope remains OPEN. Link work to requirements and acceptance criteria, follow the existing code patterns, and review the diff before moving on. Roadmap items do not authorize implementation. Keep product decisions, implementation, verification, acceptance, and Git status distinct in the project documents.

Development interaction uses Codex in the ChatGPT Desktop graphical interface against the existing local Minority repository (DEC-017, CONFIRMED). The user is not required to operate Codex CLI. Commands documented below are available for Codex to execute internally when needed; native macOS build verification remains local.

The [release strategy](docs/MASTERPLAN.md#strategi-rilis) uses the assistant's proposed distinction between a planning/scheduling **Technical Alpha**, a **Product MVP** requiring explicit user approval of its still-open scope, and **Extended Releases** selected through the roadmap. Audit conclusions and proposed release classifications are not direct user approval. Publication of the C1 and G0 checkpoints is authorized separately; Product MVP approval remains pending. Backup, recovery, and database upgrade safety must be defined and tested before routine use with important personal data.

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

It checks database initialization, read/write behavior, migration idempotency, preservation of existing data when initialization fails, transaction rollback, and SQLite error propagation. This is a standalone executable target; the package does not currently define an XCTest target.

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

## Planned functionality

- Daily, monthly, and yearly planning
- Perintah Induk and Perintah Harian
- Activity execution tracking
- Multidimensional, classification-based evaluation and rule-based decision support
- Personal document management
- PDFKit and Vision OCR
- Hybrid semantic search and local multilingual embeddings
- Structured JSON planning import

These capabilities are planned and are not part of the current application.

## Current limitations

- The app is still a bootstrap screen; it has no planning or activity workflows.
- The database has the original `foundation` migration plus the additive `planning_v1` migration. The committed C1 persistence checkpoint does not provide planning UI or constitute acceptance of the complete domain/product design.
- Persistence checks must be run through `MinorityPersistenceChecks`; `swift test` has no test target to run.
- The packaged app is ad hoc signed and is not ready for public distribution or notarization.
