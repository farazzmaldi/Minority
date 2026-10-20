import Combine
import Foundation
import NaturalLanguage
import MinorityPersistence
import SwiftUI

struct SearchResults: Sendable {
    let exact: [LocalSearchResult]
    let semantic: [LocalSearchResult]
    let semanticUnavailable: Bool
}

actor LocalSearchEngine {
    private let repository: SearchRepository
    private var embedding: NLContextualEmbedding?

    init(databaseManager: DatabaseManager) {
        repository = SearchRepository(databaseQueue: databaseManager.databaseQueue)
    }

    func supportsLocalEnglishAndIndonesianModel() -> Bool {
        guard let model = NLContextualEmbedding(language: .english) else { return false }
        return model.languages.contains(.english) && model.languages.contains(.indonesian)
    }

    func hasModelAssets() -> Bool {
        NLContextualEmbedding(language: .english)?.hasAvailableAssets ?? false
    }

    func prepareModel() async throws {
        guard let model = NLContextualEmbedding(language: .english),
              model.languages.contains(.english), model.languages.contains(.indonesian) else {
            throw LocalSearchError.multilingualModelUnavailable
        }
        if !model.hasAvailableAssets {
            guard try await model.requestAssets() == .available else {
                throw LocalSearchError.modelAssetsUnavailable
            }
        }
        try model.load()
        embedding = model
    }

    func search(_ query: String, includeSemantic: Bool) throws -> SearchResults {
        try repository.refreshIndex()
        let exact = try repository.textSearch(query)
        guard includeSemantic else {
            return SearchResults(exact: exact, semantic: [], semanticUnavailable: false)
        }
        if embedding == nil,
           let availableModel = NLContextualEmbedding(language: .english),
           availableModel.hasAvailableAssets,
           availableModel.languages.contains(.english),
           availableModel.languages.contains(.indonesian) {
            try availableModel.load()
            embedding = availableModel
        }
        guard let model = embedding, model.hasAvailableAssets else {
            return SearchResults(exact: exact, semantic: [], semanticUnavailable: true)
        }

        let indexedVectors = try repository.semanticVectors(
            modelIdentifier: model.modelIdentifier,
            revision: model.revision
        )
        let indexedIDs = Set(indexedVectors.map { $0.record.id })
        for record in try repository.semanticIndexRecords() where !indexedIDs.contains(record.id) {
            let vectors = try Self.embeddingVectors(for: "\(record.title)\n\(record.body)", using: model)
            try repository.replaceSemanticVectors(
                for: record,
                modelIdentifier: model.modelIdentifier,
                revision: model.revision,
                vectors: vectors
            )
        }

        let queryVectors = try Self.embeddingVectors(for: query, using: model)
        guard let queryVector = queryVectors.first else {
            return SearchResults(exact: exact, semantic: [], semanticUnavailable: false)
        }
        let semantic = try repository.semanticSearch(
            queryVector: queryVector,
            modelIdentifier: model.modelIdentifier,
            revision: model.revision
        )
        return SearchResults(exact: exact, semantic: semantic, semanticUnavailable: false)
    }

    private static func embeddingVectors(for text: String, using model: NLContextualEmbedding) throws -> [[Float]] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let chunks = stride(from: 0, to: max(words.count, 1), by: 80).map { start in
            words.dropFirst(start).prefix(80).joined(separator: " ")
        }
        return try chunks.compactMap { chunk in
            guard !chunk.isEmpty else { return nil }
            let result = try model.embeddingResult(for: chunk, language: nil)
            var sum = Array(repeating: Double.zero, count: model.dimension)
            var count = 0
            result.enumerateTokenVectors(in: result.string.startIndex..<result.string.endIndex) { vector, _ in
                guard vector.count == sum.count else { return true }
                for index in vector.indices { sum[index] += vector[index] }
                count += 1
                return true
            }
            guard count > 0 else { return nil }
            let magnitude = sqrt(sum.reduce(0) { $0 + ($1 * $1) })
            guard magnitude.isFinite, magnitude > 0 else { return nil }
            return sum.map { Float($0 / magnitude) }
        }
    }
}

enum LocalSearchError: Error, LocalizedError {
    case multilingualModelUnavailable
    case modelAssetsUnavailable

    var errorDescription: String? {
        switch self {
        case .multilingualModelUnavailable:
            "The local system embedding model does not support both English and Bahasa Indonesia."
        case .modelAssetsUnavailable:
            "The local language model is unavailable. Connect to the internet once to download the on-device model, then search works offline."
        }
    }
}

@MainActor
final class SearchViewModel: ObservableObject {
    private let engine: LocalSearchEngine
    @Published var query = ""
    @Published private(set) var results: SearchResults?
    @Published private(set) var isSearching = false
    @Published private(set) var isPreparingModel = false
    @Published private(set) var modelAvailable = false
    @Published private(set) var modelAssetsAvailable = false
    @Published var error: String?

    init(databaseManager: DatabaseManager) {
        engine = LocalSearchEngine(databaseManager: databaseManager)
    }

    func load() {
        Task {
            modelAvailable = await engine.supportsLocalEnglishAndIndonesianModel()
            modelAssetsAvailable = await engine.hasModelAssets()
        }
    }

    func enableSemanticSearch() {
        isPreparingModel = true
        error = nil
        Task {
            do {
                try await engine.prepareModel()
                modelAssetsAvailable = true
                await search(includeSemantic: true)
            } catch {
                self.error = error.localizedDescription
            }
            isPreparingModel = false
        }
    }

    func search(includeSemantic: Bool = false) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = nil
            return
        }
        isSearching = true
        error = nil
        defer { isSearching = false }
        do {
            results = try await engine.search(query, includeSemantic: includeSemantic)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

@MainActor
struct LocalSearchView: View {
    let language: InterfaceLanguage
    @StateObject private var model: SearchViewModel

    init(language: InterfaceLanguage, databaseManager: DatabaseManager) {
        self.language = language
        _model = StateObject(wrappedValue: SearchViewModel(databaseManager: databaseManager))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField(language.text("Search local plans, commands, evaluations, and documents", "Cari rencana, perintah, evaluasi, dan dokumen lokal"), text: $model.query)
                    .onSubmit { Task { await model.search(includeSemantic: model.modelAssetsAvailable) } }
                Button(language.text("Search", "Cari")) {
                    Task { await model.search(includeSemantic: model.modelAssetsAvailable) }
                }
                .disabled(model.isSearching || model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)

            if !model.modelAvailable {
                ContentUnavailableView(language.text("Multilingual semantic model unavailable", "Model semantik multibahasa tidak tersedia"), systemImage: "text.magnifyingglass")
            } else if model.modelAssetsAvailable {
                Label(language.text("English and Bahasa Indonesia semantic search is available on this Mac.", "Pencarian semantik English dan Bahasa Indonesia tersedia di Mac ini."), systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Button {
                    model.enableSemanticSearch()
                } label: {
                    if model.isPreparingModel {
                        ProgressView(language.text("Preparing local language model…", "Menyiapkan model bahasa lokal…"))
                    } else {
                        Label(language.text("Download local semantic model", "Unduh model semantik lokal"), systemImage: "arrow.down.circle")
                    }
                }
                .disabled(model.isPreparingModel)
            }

            if model.isSearching {
                ProgressView(language.text("Searching local data…", "Mencari data lokal…"))
            }

            if let results = model.results {
                List {
                    Section(language.text("Text matches", "Kecocokan teks")) {
                        if results.exact.isEmpty {
                            Text(language.text("No text matches.", "Tidak ada kecocokan teks.")).foregroundStyle(.secondary)
                        } else {
                            ForEach(results.exact) { result in
                                NavigationLink {
                                    SearchResultDetail(language: language, result: result)
                                } label: {
                                    resultRow(result, label: language.text("Text", "Teks"))
                                }
                            }
                        }
                    }
                    if model.modelAssetsAvailable {
                        Section(language.text("Similar meaning", "Makna serupa")) {
                            if results.semantic.isEmpty {
                                Text(language.text("No semantic matches.", "Tidak ada kecocokan semantik.")).foregroundStyle(.secondary)
                            } else {
                                ForEach(results.semantic) { result in
                                    NavigationLink {
                                        SearchResultDetail(language: language, result: result)
                                    } label: {
                                        resultRow(result, label: language.text("Meaning", "Makna"))
                                    }
                                }
                            }
                        }
                    }
                    if results.semanticUnavailable {
                        Text(language.text("Text search works now. Download the local model once to enable semantic results.", "Pencarian teks sudah berfungsi. Unduh model lokal sekali untuk mengaktifkan hasil semantik."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else if !model.isSearching {
                ContentUnavailableView(language.text("Search your Minority data", "Cari data Minority"), systemImage: "magnifyingglass",
                                       description: Text(language.text("Text search works locally. Semantic search uses an on-device multilingual model.", "Pencarian teks bekerja lokal. Pencarian semantik memakai model multibahasa di perangkat.")))
            }
        }
        .navigationTitle(language.text("Search", "Pencarian"))
        .task { model.load() }
        .alert(language.text("Search Error", "Kesalahan Pencarian"), isPresented: Binding(
            get: { model.error != nil }, set: { if !$0 { model.error = nil } }
        )) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    private func resultRow(_ result: LocalSearchResult, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title).font(.headline)
            Text("\(label) · \(result.kind.capitalized)").font(.caption).foregroundStyle(.secondary)
            if !result.snippet.isEmpty { Text(result.snippet).lineLimit(3) }
        }
        .padding(.vertical, 3)
    }
}

@MainActor
private struct SearchResultDetail: View {
    let language: InterfaceLanguage
    let result: LocalSearchResult
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(result.title).font(.title2.bold())
                Text(result.kind.capitalized).foregroundStyle(.secondary)
                Text(result.snippet.isEmpty ? language.text("No additional text is stored for this result.", "Tidak ada teks tambahan yang tersimpan untuk hasil ini.") : result.snippet)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(language.text("Search Result", "Hasil Pencarian"))
    }
}
