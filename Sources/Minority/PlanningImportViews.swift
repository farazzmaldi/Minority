import SwiftUI
import Combine
import MinorityPersistence
import AppKit

@MainActor
struct PlanningImportPromptSheet: View {
    let language: InterfaceLanguage
    @Binding var didCopyPrompt: Bool
    @Environment(\.dismiss) private var dismiss

    private var prompt: String {
        """
        Buat teks JSON yang bisa langsung ditempel ke aplikasi Minority. Ikuti aturan ini:
        - Keluarkan hanya JSON valid, tanpa markdown atau penjelasan.
        - Gunakan format "minority.planning" versi 1.
        - Isi hanya informasi yang benar-benar ada di bahan. Jangan mengarang tanggal, jam, kegiatan, tujuan, atau jadwal.
        - Buat UUID baru yang valid untuk setiap id dan jangan memakai satu id untuk dua data. Semua tanggal memakai format YYYY-MM-DD.
        - Jadwal hanya satu kali. Sertakan startTime dan endTime bersama-sama hanya jika keduanya disebutkan; jangan isi priority.
        - Hubungkan data hanya jika hubungannya jelas dari bahan. Array yang tidak dipakai boleh kosong.
        - Jangan buat Perintah, pelaksanaan, evaluasi, atau data lain di luar format ini.

        Bentuk JSON:
        {
          "format": "minority.planning",
          "version": 1,
          "plans": [],
          "activities": [],
          "planActivities": [],
          "objectives": [],
          "planObjectives": [],
          "scheduleOccurrences": []
        }

        Isi objek dengan field berikut: Plan memerlukan id, title, startDate, endDate; Activity memerlukan id dan title, details opsional; planActivities memerlukan planID dan activityID; Objective memerlukan id dan title, details opsional; planObjectives memerlukan planID dan objectiveID; scheduleOccurrences memerlukan id, activityID, scheduledDate, serta startTime dan endTime yang opsional tetapi harus berpasangan. Jangan sertakan priority.

        Sebelum menjawab, periksa bahwa JSON valid, semua UUID unik, setiap tanggal valid, rentang Plan tidak terbalik, dan semua relasi menunjuk id yang ada.

        BAHAN RENCANA:
        [Ganti bagian ini dengan deskripsi rencana yang ingin diimpor]
        """
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(language.text("Copy this prompt into GPT", "Salin prompt ini ke GPT")) {
                    Text(language.text(
                        "Replace the final placeholder with your plan description. Ask GPT for JSON, copy its response, then paste it directly into Minority. No file is needed.",
                        "Ganti penanda paling bawah dengan deskripsi rencanamu. Minta GPT membuat JSON, salin jawabannya, lalu tempel langsung ke Minority. Tidak perlu menyimpan berkas."
                    ))
                    .font(.callout)

                    TextEditor(text: .constant(prompt))
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 300)
                        .textSelection(.enabled)
                        .accessibilityLabel(language.text("Prompt for GPT", "Prompt untuk GPT"))

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(prompt, forType: .string)
                        didCopyPrompt = true
                    } label: {
                        Label(
                            didCopyPrompt ? language.text("Prompt Copied", "Prompt Tersalin") : language.text("Copy Prompt", "Salin Prompt"),
                            systemImage: didCopyPrompt ? "checkmark" : "doc.on.doc"
                        )
                    }
                }
            }
            .navigationTitle(language.text("Prepare GPT Import", "Siapkan Impor GPT"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("Done", "Selesai")) { dismiss() }
                }
            }
        }
        .frame(minWidth: 620, minHeight: 520)
    }
}

@MainActor
private final class PlanningJSONPasteModel: ObservableObject {
    @Published var jsonText = ""
    @Published var feedback: String?
    @Published var operationError: String?
    @Published var review: PlanningImportReview?
    let makeReview: (String) throws -> PlanningImportReview
    let onAdd: (Data) throws -> Void

    init(makeReview: @escaping (String) throws -> PlanningImportReview, onAdd: @escaping (Data) throws -> Void) {
        self.makeReview = makeReview
        self.onAdd = onAdd
    }
}

@MainActor
struct PlanningJSONPasteSheet: View {
    let language: InterfaceLanguage
    @StateObject private var model: PlanningJSONPasteModel
    @Environment(\.dismiss) private var dismiss

    init(language: InterfaceLanguage, makeReview: @escaping (String) throws -> PlanningImportReview, onAdd: @escaping (Data) throws -> Void) {
        self.language = language
        _model = StateObject(wrappedValue: PlanningJSONPasteModel(makeReview: makeReview, onAdd: onAdd))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(language.text("Paste GPT's JSON response", "Tempel jawaban JSON dari GPT")) {
                    Text(language.text(
                        "Copy the JSON response from GPT and paste it here with ⌘V, or use Paste from Clipboard. Then review the records before adding them.",
                        "Salin jawaban JSON dari GPT lalu tempel di sini dengan ⌘V, atau gunakan Tempel dari Clipboard. Periksa datanya sebelum menambahkannya."
                    ))
                    .font(.callout)

                    TextEditor(text: $model.jsonText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 300)
                        .accessibilityLabel(language.text("Planning JSON", "JSON perencanaan"))

                    Button {
                        guard let text = NSPasteboard.general.string(forType: .string),
                              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            model.feedback = language.text("The clipboard has no text to paste.", "Clipboard tidak berisi teks untuk ditempel.")
                            return
                        }
                        model.jsonText = text
                        model.feedback = nil
                    } label: {
                        Label(language.text("Paste from Clipboard", "Tempel dari Clipboard"), systemImage: "doc.on.clipboard")
                    }
                }

                if let feedback = model.feedback {
                    Section {
                        Text(feedback)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(language.text("Paste Planning JSON", "Tempel JSON Perencanaan"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("Cancel", "Batal")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("Review", "Tinjau"), action: preview)
                        .disabled(model.jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 520)
        .sheet(item: $model.review) { item in
            PlanningImportReviewSheet(language: language, summary: item.summary, operationError: $model.operationError) {
                try model.onAdd(item.data)
                model.review = nil
                dismiss()
            } onCancel: {
                model.review = nil
            }
        }
    }

    private func preview() {
        do {
            model.review = try model.makeReview(model.jsonText)
            model.feedback = nil
        } catch {
            model.feedback = error.localizedDescription
        }
    }
}

struct PlanningImportReview: Identifiable {
    let id = UUID()
    let data: Data
    let summary: PlanningImportSummary

    init(data: Data, summary: PlanningImportSummary) {
        self.data = data
        self.summary = summary
    }
}

@MainActor
struct PlanningImportReviewSheet: View {
    let language: InterfaceLanguage
    let summary: PlanningImportSummary
    @Binding var operationError: String?
    let onImport: () throws -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(language.text("Records to add", "Data yang akan ditambahkan")) {
                    countRow("Plans", "Rencana", summary.plansToAdd)
                    countRow("Activities", "Kegiatan", summary.activitiesToAdd)
                    countRow("Plan–Activity links", "Tautan Rencana–Kegiatan", summary.linksToAdd)
                    countRow("Objectives", "Tujuan", summary.objectivesToAdd)
                    countRow("Plan–Objective links", "Tautan Rencana–Tujuan", summary.objectiveLinksToAdd)
                    countRow("Scheduled occurrences", "Jadwal kegiatan", summary.occurrencesToAdd)
                    DisclosureGroup(language.text("Review names and dates", "Tinjau nama dan tanggal")) {
                        ForEach(Array(summary.planTitles.enumerated()), id: \.offset) { _, title in
                            Text("\(language.text("Plan", "Rencana")): \(title)")
                        }
                        ForEach(Array(summary.activityTitles.enumerated()), id: \.offset) { _, title in
                            Text("\(language.text("Activity", "Kegiatan")): \(title)")
                        }
                        ForEach(Array(summary.objectiveTitles.enumerated()), id: \.offset) { _, title in
                            Text("\(language.text("Objective", "Tujuan")): \(title)")
                        }
                        ForEach(Array(summary.occurrenceDates.enumerated()), id: \.offset) { _, date in
                            Text("\(language.text("Occurrence", "Jadwal")): \(date)")
                        }
                    }
                }

                if summary.alreadyPresent > 0 {
                    Section(language.text("Already present", "Sudah ada")) {
                        Text("\(summary.alreadyPresent) \(language.text("identical record(s) will be skipped.", "data yang identik akan dilewati."))")
                    }
                }

                if !summary.issues.isEmpty {
                    Section(language.text("Conflicts to resolve", "Konflik yang perlu diselesaikan")) {
                        ForEach(Array(summary.issues.enumerated()), id: \.offset) { _, issue in
                            Label(issue, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                        Text(language.text("Nothing will be imported while conflicts remain.", "Tidak ada data yang diimpor selama konflik belum diselesaikan."))
                            .font(.caption)
                    }
                }

                Section {
                    Text(language.text(
                        "The JSON is checked again when you confirm. All records are added together; a failure leaves the database unchanged.",
                        "JSON diperiksa ulang saat kamu mengonfirmasi. Semua data ditambahkan sekaligus; jika gagal, database tidak berubah."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(language.text("Review additions", "Tinjau penambahan"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text(summary.totalToAdd == 0 && summary.canImport ? "Done" : "Cancel", summary.totalToAdd == 0 && summary.canImport ? "Selesai" : "Batal"), action: onCancel)
                }
                if summary.totalToAdd > 0 {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(language.text("Add to Minority", "Tambahkan ke Minority"), action: add).disabled(!summary.canImport)
                    }
                }
            }
            .alert(
                language.text("Could not add the planning data", "Data perencanaan tidak dapat ditambahkan"),
                isPresented: Binding(
                    get: { operationError != nil },
                    set: { if !$0 { operationError = nil } }
                )
            ) {
                Button(language.text("OK", "OK"), role: .cancel) { operationError = nil }
            } message: {
                Text(operationError ?? "")
            }
        }
        .frame(minWidth: 500, minHeight: 420)
    }

    private func countRow(_ english: String, _ indonesian: String, _ count: Int) -> some View {
        LabeledContent(language.text(english, indonesian), value: String(count))
    }

    private func add() {
        do {
            try onImport()
            dismiss()
        } catch {
            operationError = error.localizedDescription
        }
    }
}
