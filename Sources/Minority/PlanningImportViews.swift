import SwiftUI
import MinorityPersistence

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
    let onImport: () -> Void
    let onCancel: () -> Void

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
                        "The file is checked again when you confirm. Records are imported together; a failure leaves the database unchanged.",
                        "Berkas akan diperiksa ulang saat Anda mengonfirmasi. Semua data diimpor sebagai satu kesatuan; jika gagal, database tidak berubah."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(language.text("Review Import", "Tinjau Impor"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text(summary.totalToAdd == 0 && summary.canImport ? "Done" : "Cancel", summary.totalToAdd == 0 && summary.canImport ? "Selesai" : "Batal"), action: onCancel)
                }
                if summary.totalToAdd > 0 {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(language.text("Import", "Impor"), action: onImport).disabled(!summary.canImport)
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 420)
    }

    private func countRow(_ english: String, _ indonesian: String, _ count: Int) -> some View {
        LabeledContent(language.text(english, indonesian), value: String(count))
    }
}
