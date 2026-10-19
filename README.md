# Minority

Minority is a native macOS personal life management application. It is built as a local-first modular monolith, with offline core functionality and a SwiftUI interface.

## Project status

Foundation A (native macOS bootstrap) and Foundation B (SQLite persistence with GRDB) are complete. The app initializes its local database and displays either its initialized state or a database initialization error. No planning or life-management domain features are implemented yet.

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
- The database migration is an empty foundation migration. No domain tables or records are defined.
- Persistence checks must be run through `MinorityPersistenceChecks`; `swift test` has no test target to run.
- The packaged app is ad hoc signed and is not ready for public distribution or notarization.
