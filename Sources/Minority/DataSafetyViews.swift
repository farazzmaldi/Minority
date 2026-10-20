import AppKit
import Combine
import MinorityPersistence
import SwiftUI

@MainActor
final class DataSafetyViewModel: ObservableObject {
    private let backupManager: DatabaseBackupManager
    private let onRestore: () -> Void
    @Published private(set) var isWorking = false
    @Published var error: String?
    @Published var status: String?
    @Published var pendingRestoreURL: URL?

    init(databaseManager: DatabaseManager, onRestore: @escaping () -> Void) {
        backupManager = DatabaseBackupManager(databaseManager: databaseManager)
        self.onRestore = onRestore
    }

    func createBackup(in parent: URL) {
        isWorking = true
        error = nil
        status = nil
        let backupManager = backupManager
        Task {
            do {
                let backupURL = try await Task.detached(priority: .userInitiated) {
                    try backupManager.createBackup(in: parent)
                }.value
                status = backupURL.path
            } catch {
                self.error = error.localizedDescription
            }
            isWorking = false
        }
    }

    func restore(from backupURL: URL) {
        isWorking = true
        error = nil
        status = nil
        let backupManager = backupManager
        Task {
            do {
                let recoveryURL = try await Task.detached(priority: .userInitiated) {
                    try backupManager.restore(from: backupURL)
                }.value
                status = "Restored. A recovery backup was saved at \(recoveryURL.path). Quit and reopen Minority to refresh every window."
                onRestore()
            } catch {
                self.error = error.localizedDescription
            }
            pendingRestoreURL = nil
            isWorking = false
        }
    }
}

@MainActor
struct DataSafetyView: View {
    let language: InterfaceLanguage
    @StateObject private var model: DataSafetyViewModel

    init(language: InterfaceLanguage, databaseManager: DatabaseManager, onRestore: @escaping () -> Void) {
        self.language = language
        _model = StateObject(wrappedValue: DataSafetyViewModel(databaseManager: databaseManager, onRestore: onRestore))
    }

    var body: some View {
        Form {
            Section(language.text("Backup", "Cadangan")) {
                Text(language.text(
                    "A backup contains the SQLite database and every managed document copy, including items in Trash. It is not encrypted by Minority. Choose a folder you trust; a removable drive is preferable for recovery from device loss.",
                    "Cadangan berisi database SQLite dan semua salinan dokumen yang dikelola, termasuk item di Sampah. Minority tidak mengenkripsi cadangan. Pilih folder tepercaya; drive eksternal lebih baik untuk pemulihan jika perangkat hilang."
                ))
                .font(.callout)
                Button(language.text("Create Backup…", "Buat Cadangan…")) {
                    chooseBackupFolder()
                }
                .disabled(model.isWorking)
            }

            Section(language.text("Restore", "Pulihkan")) {
                Text(language.text(
                    "Restore replaces the current database and managed document copies. Minority first creates a recovery backup of the current data.",
                    "Pemulihan mengganti database dan salinan dokumen saat ini. Minority lebih dulu membuat cadangan pemulihan dari data sekarang."
                ))
                .font(.callout)
                Button(language.text("Choose Backup to Restore…", "Pilih Cadangan untuk Dipulihkan…"), role: .destructive) {
                    chooseRestoreFolder()
                }
                .disabled(model.isWorking)
            }

            if model.isWorking {
                ProgressView(language.text("Working…", "Sedang bekerja…"))
            }
            if let status = model.status {
                Section(language.text("Result", "Hasil")) {
                    Text(status).textSelection(.enabled)
                }
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 420)
        .navigationTitle(language.text("Backup and Restore", "Cadangan dan Pemulihan"))
        .alert(language.text("Data Safety Error", "Kesalahan Keamanan Data"), isPresented: Binding(
            get: { model.error != nil }, set: { if !$0 { model.error = nil } }
        )) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .confirmationDialog(
            language.text("Replace current Minority data?", "Ganti data Minority saat ini?"),
            isPresented: Binding(get: { model.pendingRestoreURL != nil }, set: { if !$0 { model.pendingRestoreURL = nil } }),
            titleVisibility: .visible
        ) {
            Button(language.text("Restore and Replace Data", "Pulihkan dan Ganti Data"), role: .destructive) {
                if let backupURL = model.pendingRestoreURL { model.restore(from: backupURL) }
            }
            Button(language.text("Cancel", "Batal"), role: .cancel) { model.pendingRestoreURL = nil }
        } message: {
            Text(language.text(
                "This replaces the active database and documents. An automatic recovery backup will be created before the change.",
                "Tindakan ini mengganti database dan dokumen aktif. Cadangan pemulihan otomatis akan dibuat sebelum perubahan."
            ))
        }
    }

    private func chooseBackupFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = language.text("Save Backup Here", "Simpan Cadangan di Sini")
        if panel.runModal() == .OK, let url = panel.url {
            model.createBackup(in: url)
        }
    }

    private func chooseRestoreFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = language.text("Choose Backup", "Pilih Cadangan")
        if panel.runModal() == .OK {
            model.pendingRestoreURL = panel.url
        }
    }
}
