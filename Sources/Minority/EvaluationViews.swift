import Combine
import SwiftUI
import MinorityPersistence

struct EvaluationTarget: Identifiable {
    let executionRecordID: UUID
    var id: UUID { executionRecordID }
}

@MainActor
private final class EvaluationFormModel: ObservableObject {
    let executionRecordID: UUID
    private let repository: EvaluationRepository
    @Published private(set) var rubrics: [EvaluationRubricVersion] = []
    @Published private(set) var current: EvaluationVersion?
    @Published private(set) var history: [EvaluationVersion] = []
    @Published var selectedRubricVersionID: UUID?
    @Published var responses: [UUID: String] = [:]
    @Published var error: String?
    @Published var isCreatingRubric = false
    @Published var rubricToRevise: EvaluationRubricVersion?

    init(executionRecordID: UUID, repository: EvaluationRepository) {
        self.executionRecordID = executionRecordID
        self.repository = repository
        load()
    }

    var selectedRubric: EvaluationRubricVersion? {
        rubrics.first { $0.id == selectedRubricVersionID }
    }

    var answeredCount: Int {
        guard let selectedRubric else { return 0 }
        return selectedRubric.criteria.filter { !(responses[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var hasChanges: Bool {
        guard let current else { return true }
        guard selectedRubricVersionID == current.rubric.id else { return true }
        let normalized = responses.reduce(into: [UUID: String]()) { result, pair in
            let value = pair.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { result[pair.key] = value }
        }
        return normalized != current.responses
    }

    func load(selecting rubricID: UUID? = nil) {
        do {
            rubrics = try repository.rubrics()
            history = try repository.evaluationHistory(executionRecordID: executionRecordID)
            current = history.first
            selectedRubricVersionID = rubricID ?? current?.rubric.id ?? rubrics.first?.id
            if selectedRubricVersionID == current?.rubric.id {
                responses = current?.responses ?? [:]
            } else {
                responses = [:]
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func save() throws {
        guard let selectedRubric else { return }
        _ = try repository.saveEvaluation(
            executionRecordID: executionRecordID,
            rubric: selectedRubric,
            responses: responses
        )
        load(selecting: selectedRubric.id)
    }
}

@MainActor
struct EvaluationSheet: View {
    let language: InterfaceLanguage
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: EvaluationFormModel
    private let repository: EvaluationRepository

    init(language: InterfaceLanguage, executionRecordID: UUID, repository: EvaluationRepository, onSaved: @escaping () -> Void) {
        self.language = language
        self.onSaved = onSaved
        self.repository = repository
        _model = StateObject(wrappedValue: EvaluationFormModel(executionRecordID: executionRecordID, repository: repository))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let error = model.error {
                    Section(language.text("Evaluation Could Not Be Loaded", "Evaluasi Tidak Dapat Dimuat")) {
                        Text(error).foregroundStyle(.red)
                        Button(language.text("Try Again", "Coba Lagi")) { model.load() }
                    }
                }

                Section(language.text("Versioned rubric", "Rubrik berversi")) {
                    if model.rubrics.isEmpty {
                        ContentUnavailableView(
                            language.text("No Rubrics Yet", "Belum Ada Rubrik"),
                            systemImage: "checklist",
                            description: Text(language.text("Create a rubric to record a manual evaluation.", "Buat rubrik untuk mencatat evaluasi manual."))
                        )
                    } else {
                        Picker(language.text("Rubric", "Rubrik"), selection: $model.selectedRubricVersionID) {
                            ForEach(model.rubrics) { rubric in
                                Text("\(rubric.title) · \(rubric.classification) · v\(rubric.versionNumber)")
                                    .tag(Optional(rubric.id))
                            }
                        }
                        .onChange(of: model.selectedRubricVersionID) { _, value in model.load(selecting: value) }
                        if let selected = model.selectedRubric {
                            Button(language.text("Create Rubric Version", "Buat Versi Rubrik")) {
                                model.rubricToRevise = selected
                            }
                        }
                    }
                    Button(language.text("New Rubric", "Rubrik Baru")) { model.isCreatingRubric = true }
                }

                if let rubric = model.selectedRubric {
                    Section(language.text("Manual evaluation", "Evaluasi manual")) {
                        Text("\(rubric.classification) · \(rubric.title) v\(rubric.versionNumber)")
                            .font(.headline)
                        ForEach(rubric.criteria) { criterion in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(criterion.title)
                                TextEditor(text: responseBinding(for: criterion.id))
                                    .frame(minHeight: 68)
                                    .accessibilityLabel(criterion.title)
                            }
                        }
                        Text("\(language.text("Answered", "Terjawab")): \(model.answeredCount)/\(rubric.criteria.count). \(language.text("No numeric score or recommendation is generated.", "Tidak ada skor angka atau rekomendasi yang dibuat."))")
                            .font(.caption)
                            .foregroundColor(model.answeredCount == rubric.criteria.count ? .secondary : .orange)
                        if let current = model.current {
                            Text("\(language.text("Saved evaluation version", "Versi evaluasi tersimpan")) v\(current.versionNumber) · \(current.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button(language.text(model.current == nil ? "Save Evaluation" : "Save Correction as New Version", model.current == nil ? "Simpan Evaluasi" : "Simpan Koreksi sebagai Versi Baru")) {
                            do {
                                try model.save()
                                onSaved()
                            } catch {
                                model.error = error.localizedDescription
                            }
                        }
                        .disabled(model.error != nil || !model.hasChanges)
                    }
                }

                if model.history.count > 1 {
                    Section(language.text("Correction history", "Riwayat koreksi")) {
                        ForEach(Array(model.history.dropFirst())) { version in
                            DisclosureGroup("v\(version.versionNumber) · \(version.rubric.title) · \(version.createdAt.formatted(date: .abbreviated, time: .shortened))") {
                                Text("\(version.rubric.classification) · \(version.isComplete ? language.text("Complete", "Lengkap") : language.text("Incomplete", "Belum lengkap"))")
                                    .font(.caption)
                                ForEach(version.rubric.criteria) { criterion in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(criterion.title).font(.caption.bold())
                                        Text(version.responses[criterion.id] ?? language.text("Not answered", "Belum dijawab"))
                                            .font(.caption)
                                    }
                                    .padding(.vertical, 3)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(language.text("Evaluation", "Evaluasi"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("Close", "Tutup")) { dismiss() }
                }
            }
            .sheet(isPresented: $model.isCreatingRubric) {
                EvaluationRubricSheet(language: language, repository: repository, existing: nil) { rubric in
                    model.load(selecting: rubric.id)
                }
            }
            .sheet(item: $model.rubricToRevise) { rubric in
                EvaluationRubricSheet(language: language, repository: repository, existing: rubric) { revised in
                    model.load(selecting: revised.id)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 520)
    }

    private func responseBinding(for criterionID: UUID) -> Binding<String> {
        Binding(
            get: { model.responses[criterionID] ?? "" },
            set: { model.responses[criterionID] = $0 }
        )
    }
}

@MainActor
private final class EvaluationRubricFormModel: ObservableObject {
    let existing: EvaluationRubricVersion?
    @Published var title: String
    @Published var classification: String
    @Published var criteriaText: String
    @Published var error: String?

    init(existing: EvaluationRubricVersion?) {
        self.existing = existing
        title = existing?.title ?? ""
        classification = existing?.classification ?? ""
        criteriaText = existing?.criteria.map(\.title).joined(separator: "\n") ?? ""
    }
}

@MainActor
private struct EvaluationRubricSheet: View {
    let language: InterfaceLanguage
    let repository: EvaluationRepository
    let existing: EvaluationRubricVersion?
    let onSaved: (EvaluationRubricVersion) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var form: EvaluationRubricFormModel

    init(language: InterfaceLanguage, repository: EvaluationRepository, existing: EvaluationRubricVersion?, onSaved: @escaping (EvaluationRubricVersion) -> Void) {
        self.language = language
        self.repository = repository
        self.existing = existing
        self.onSaved = onSaved
        _form = StateObject(wrappedValue: EvaluationRubricFormModel(existing: existing))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(language.text("Rubric name", "Nama rubrik"), text: $form.title)
                TextField(language.text("Classification", "Klasifikasi"), text: $form.classification)
                VStack(alignment: .leading) {
                    Text(language.text("Criteria — one per line", "Kriteria — satu per baris"))
                    TextEditor(text: $form.criteriaText).frame(minHeight: 130)
                }
                Text(language.text("Responses are entered manually. Rubric changes create a new version; prior evaluations keep their original rubric.", "Jawaban diisi manual. Perubahan rubrik membuat versi baru; evaluasi lama tetap memakai rubrik asal."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = form.error { Text(error).foregroundStyle(.red) }
            }
            .padding(.top, 12)
            .navigationTitle(language.text(existing == nil ? "New Rubric" : "New Rubric Version", existing == nil ? "Rubrik Baru" : "Versi Rubrik Baru"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("Cancel", "Batal")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("Save", "Simpan"), action: save).disabled(form.title.trimmed.isEmpty || form.classification.trimmed.isEmpty || form.criteriaText.trimmed.isEmpty)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 380)
    }

    private func save() {
        let criteria = form.criteriaText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        do {
            let rubric: EvaluationRubricVersion
            if let existing = form.existing {
                rubric = try repository.reviseRubric(
                    rubricID: existing.rubricID,
                    title: form.title,
                    classification: form.classification,
                    criteria: criteria
                )
            } else {
                rubric = try repository.createRubric(title: form.title, classification: form.classification, criteria: criteria)
            }
            onSaved(rubric)
            dismiss()
        } catch {
            form.error = error.localizedDescription
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
