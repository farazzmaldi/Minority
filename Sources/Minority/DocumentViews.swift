import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import Vision
import MinorityPersistence

@MainActor
final class DocumentLibraryModel: ObservableObject {
    private let repository: DocumentRepository
    @Published private(set) var documents: [LocalDocument] = []
    @Published private(set) var trash: [LocalDocument] = []
    @Published var isImporting = false
    @Published private(set) var isProcessingImport = false
    @Published var error: String?
    @Published var showingTrash = false

    init(databaseManager: DatabaseManager) {
        repository = DocumentRepository(
            databaseQueue: databaseManager.databaseQueue,
            applicationSupportDirectory: databaseManager.applicationSupportDirectory
        )
    }

    func load() {
        do {
            documents = try repository.documents()
            trash = try repository.documents(includeTrash: true).filter { $0.trashedAt != nil }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func importDocument(from result: Result<URL, Error>) {
        do {
            let url = try result.get()
            isProcessingImport = true
            Task {
                await self.importDocument(from: url)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func importDocument(from url: URL) async {
        defer { isProcessingImport = false }
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        let extraction = await Task.detached(priority: .userInitiated) {
            Result { try DocumentTextExtractor.extract(from: url) }
        }.value
        let text: String
        let extractionError: String?
        switch extraction {
        case let .success(value): text = value; extractionError = nil
        case let .failure(failure): text = ""; extractionError = failure.localizedDescription
        }
        do {
            let mediaType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            _ = try repository.add(from: url, mediaType: mediaType, extractedText: text, extractionError: extractionError)
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func moveToTrash(_ document: LocalDocument) {
        do { try repository.moveToTrash(id: document.id); load() }
        catch { self.error = error.localizedDescription }
    }

    func restore(_ document: LocalDocument) {
        do { try repository.restore(id: document.id); load() }
        catch { self.error = error.localizedDescription }
    }

    func fileURL(for document: LocalDocument) -> URL { repository.fileURL(for: document) }
}

private enum DocumentTextExtractor {
    static func extract(from url: URL) throws -> String {
        if let pdf = PDFDocument(url: url) {
            let nativeText = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
            if !nativeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nativeText }
            return try (0..<pdf.pageCount).compactMap { index -> String? in
                guard let page = pdf.page(at: index) else { return nil }
                let thumbnail = page.thumbnail(of: CGSize(width: 1400, height: 1800), for: .mediaBox)
                guard let image = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
                return try recognize(image)
            }.joined(separator: "\n")
        }

        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw DocumentImportError.unsupportedFile
        }
        return try recognize(cgImage)
    }

    private static func recognize(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let available = try request.supportedRecognitionLanguages()
        let preferred = ["en-US", "id-ID"]
        request.recognitionLanguages = preferred.filter(available.contains)
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}

private enum DocumentImportError: Error, LocalizedError {
    case unsupportedFile
    var errorDescription: String? { "This file could not be read as a PDF or image." }
}

@MainActor
struct DocumentLibraryView: View {
    let language: InterfaceLanguage
    @StateObject private var model: DocumentLibraryModel

    init(language: InterfaceLanguage, model: DocumentLibraryModel) {
        self.language = language
        _model = StateObject(wrappedValue: model)
    }

    private var items: [LocalDocument] { model.showingTrash ? model.trash : model.documents }

    var body: some View {
        List {
            if model.isProcessingImport {
                ProgressView(language.text("Copying document and extracting text…", "Menyalin dokumen dan mengekstrak teks…"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let error = model.error {
                ContentUnavailableView(language.text("Documents unavailable", "Dokumen tidak tersedia"), systemImage: "exclamationmark.triangle", description: Text(error))
            } else if items.isEmpty && !model.isProcessingImport {
                ContentUnavailableView(
                    model.showingTrash ? language.text("Trash is empty", "Sampah kosong") : language.text("No Documents Yet", "Belum Ada Dokumen"),
                    systemImage: model.showingTrash ? "trash" : "doc.text",
                    description: Text(language.text("Import a PDF or image to keep a local copy and searchable text.", "Impor PDF atau gambar untuk menyimpan salinan lokal dan teks yang dapat dicari."))
                )
            } else {
                ForEach(items) { document in
                    NavigationLink {
                        DocumentDetailView(language: language, document: document, fileURL: model.fileURL(for: document)) {
                        model.showingTrash ? model.restore(document) : model.moveToTrash(document)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.filename).font(.headline)
                            Text("\(ByteCountFormatter.string(fromByteCount: document.byteSize, countStyle: .file)) · \(document.extractionError == nil ? language.text("Text ready", "Teks tersedia") : language.text("Text extraction needs attention", "Ekstraksi teks perlu diperiksa"))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(model.showingTrash ? language.text("Document Trash", "Sampah Dokumen") : language.text("Documents", "Dokumen"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if !model.showingTrash {
                        Button { model.isImporting = true } label: {
                            Label(language.text("Import PDF or Image…", "Impor PDF atau Gambar…"), systemImage: "plus")
                        }
                    }
                    Button { model.showingTrash.toggle(); model.load() } label: {
                        Label(model.showingTrash ? language.text("Documents", "Dokumen") : language.text("Trash", "Sampah"), systemImage: model.showingTrash ? "doc.text" : "trash")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .fileImporter(isPresented: $model.isImporting, allowedContentTypes: [.pdf, .image]) { model.importDocument(from: $0) }
        .task { model.load() }
        .alert(language.text("Document Error", "Kesalahan Dokumen"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
}

@MainActor
private struct DocumentDetailView: View {
    let language: InterfaceLanguage
    let document: LocalDocument
    let fileURL: URL
    let onToggleTrash: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(document.filename).font(.title2.bold())
                Text("\(document.mediaType) · \(ByteCountFormatter.string(fromByteCount: document.byteSize, countStyle: .file))")
                    .foregroundStyle(.secondary)
                if document.mediaType == "application/pdf" {
                    PDFDocumentPreview(url: fileURL).frame(minHeight: 440)
                } else if let image = NSImage(contentsOf: fileURL) {
                    Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 440)
                }
                if let extractionError = document.extractionError {
                    Label("\(language.text("Text extraction failed", "Ekstraksi teks gagal")): \(extractionError)", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                Group {
                    Text(language.text("Extracted text", "Teks hasil ekstraksi")).font(.headline)
                    if document.extractedText.isEmpty {
                        Text(language.text("No readable text was found.", "Tidak ditemukan teks yang dapat dibaca.")).foregroundStyle(.secondary)
                    } else {
                        Text(document.extractedText).textSelection(.enabled)
                    }
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onToggleTrash) {
                    Label(document.trashedAt == nil ? language.text("Move to Trash", "Pindahkan ke Sampah") : language.text("Restore", "Pulihkan"), systemImage: document.trashedAt == nil ? "trash" : "arrow.uturn.backward")
                }
            }
        }
    }
}

private struct PDFDocumentPreview: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }
    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url { view.document = PDFDocument(url: url) }
    }
}
