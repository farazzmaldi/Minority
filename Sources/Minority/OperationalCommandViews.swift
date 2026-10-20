import AppKit
import CoreText
import MinorityPersistence
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class OperationalCommandCenterModel: ObservableObject {
    private let commandRepository: OperationalCommandRepository
    private let planningRepository: PlanningRepository
    @Published private(set) var parentCommands: [OperationalCommand] = []
    @Published private(set) var dailyCommands: [OperationalCommand] = []
    @Published private(set) var plans: [Plan] = []
    @Published private(set) var activities: [Activity] = []
    @Published private(set) var objectives: [Objective] = []
    @Published private(set) var occurrences: [ScheduleOccurrence] = []
    @Published private(set) var parentVersions: [OperationalCommandVersion] = []
    @Published private(set) var latestVersionsByCommandID: [UUID: OperationalCommandVersion] = [:]
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?
    @Published var selectedKind: OperationalCommandKind = .parent
    @Published var isCreatingParent = false
    @Published var isCreatingDaily = false

    init(databaseManager: DatabaseManager) {
        commandRepository = OperationalCommandRepository(databaseQueue: databaseManager.databaseQueue)
        planningRepository = PlanningRepository(databaseQueue: databaseManager.databaseQueue)
    }

    func load() {
        isLoading = true
        loadError = nil
        do {
            parentCommands = try commandRepository.commands(kind: .parent)
            dailyCommands = try commandRepository.commands(kind: .daily)
            plans = try planningRepository.plans()
            activities = try planningRepository.activities()
            objectives = try planningRepository.objectives()
            occurrences = try activities.flatMap {
                try planningRepository.scheduleOccurrences(forActivityID: $0.id)
            }.sorted {
                ($0.scheduledDate, $0.startTime ?? "", $0.id.uuidString)
                    < ($1.scheduledDate, $1.startTime ?? "", $1.id.uuidString)
            }
            parentVersions = try parentCommands.flatMap {
                try commandRepository.versions(forCommandID: $0.id)
                    .filter { $0.state != .draft }
            }.sorted {
                ($0.number, $0.versionNumber) < ($1.number, $1.versionNumber)
            }
            let allCommands = parentCommands + dailyCommands
            latestVersionsByCommandID = try Dictionary(uniqueKeysWithValues: allCommands.compactMap { command in
                guard let version = try commandRepository.versions(forCommandID: command.id).first else { return nil }
                return (command.id, version)
            })
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func occurrences(on date: String) -> [ScheduleOccurrence] {
        occurrences.filter { $0.scheduledDate == date }
    }

    func activity(id: UUID) -> Activity? {
        activities.first { $0.id == id }
    }

    func createParentDraft(_ content: OperationalCommandDraftContent) throws -> OperationalCommandVersion {
        let version = try commandRepository.createParentDraft(content: content)
        load()
        return version
    }

    func createDailyDraft(date: String, content: OperationalCommandDraftContent) throws -> OperationalCommandVersion {
        let version = try commandRepository.createDailyDraft(date: date, content: content)
        load()
        return version
    }

    func updateDraft(
        id: UUID,
        content: OperationalCommandDraftContent,
        dailyDate: String? = nil
    ) throws -> OperationalCommandVersion {
        let version = try commandRepository.updateDraft(versionID: id, content: content, dailyDate: dailyDate)
        load()
        return version
    }

    func detailModel(commandID: UUID) -> OperationalCommandDetailModel {
        OperationalCommandDetailModel(commandID: commandID, centerModel: self)
    }

    fileprivate var repository: OperationalCommandRepository { commandRepository }
}

@MainActor
struct OperationalCommandCenterView: View {
    @AppStorage("minority.interface-language") private var languageRawValue = InterfaceLanguage.english.rawValue
    @ObservedObject var model: OperationalCommandCenterModel

    private var language: InterfaceLanguage {
        InterfaceLanguage(rawValue: languageRawValue) ?? .english
    }

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView(language.text("Loading commands…", "Memuat perintah…"))
            } else if let error = model.loadError {
                ContentUnavailableView(
                    language.text("Commands Could Not Be Loaded", "Perintah Tidak Dapat Dimuat"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                .overlay(alignment: .bottom) {
                    Button(language.text("Try Again", "Coba Lagi")) { model.load() }
                        .padding(.bottom, 18)
                }
            } else {
                List {
                    Section {
                        Picker(language.text("Command type", "Jenis perintah"), selection: $model.selectedKind) {
                            Text(language.text("Parent Commands", "Perintah Induk")).tag(OperationalCommandKind.parent)
                            Text(language.text("Daily Commands", "Perintah Harian")).tag(OperationalCommandKind.daily)
                        }
                        .pickerStyle(.segmented)
                    }

                    let commands = model.selectedKind == .parent ? model.parentCommands : model.dailyCommands
                    if commands.isEmpty {
                        ContentUnavailableView(
                            model.selectedKind == .parent
                                ? language.text("No Parent Commands", "Belum Ada Perintah Induk")
                                : language.text("No Daily Commands", "Belum Ada Perintah Harian"),
                            systemImage: "doc.text",
                            description: Text(language.text(
                                "Create a draft when you need a command. Nothing is published automatically.",
                                "Buat draf saat Anda memerlukan perintah. Tidak ada yang diterbitkan otomatis."
                            ))
                        )
                    } else {
                        ForEach(commands) { command in
                            NavigationLink {
                                OperationalCommandDetailView(
                                    model: model.detailModel(commandID: command.id),
                                    centerModel: model
                                )
                            } label: {
                                commandRow(command)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(language.text("Operational Commands", "Perintah Operasional"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        model.isCreatingParent = true
                    } label: {
                        Label(language.text("New Parent Command", "Perintah Induk Baru"), systemImage: "doc.badge.plus")
                    }
                    Button {
                        model.isCreatingDaily = true
                    } label: {
                        Label(language.text("New Daily Command", "Perintah Harian Baru"), systemImage: "calendar.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(model.isLoading || model.loadError != nil)
            }
        }
        .task { model.load() }
        .sheet(isPresented: $model.isCreatingParent) {
            ParentCommandDraftSheet(model: model)
        }
        .sheet(isPresented: $model.isCreatingDaily) {
            DailyCommandDraftSheet(model: model)
        }
        .environment(\.locale, language.locale)
    }

    @ViewBuilder
    private func commandRow(_ command: OperationalCommand) -> some View {
        let latestVersion = model.latestVersionsByCommandID[command.id]
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(command.number).font(.headline)
                Spacer()
                Text(latestVersion?.state.localizedName(language) ?? language.text("Draft", "Draf"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(latestVersion?.snapshot?.title ?? latestVersion?.content.title ?? language.text("Untitled command", "Perintah tanpa judul"))
            if let date = command.date {
                Text(date).font(.caption).foregroundStyle(.secondary)
            } else {
                Text(language.text("Version \(command.latestVersionNumber)", "Versi \(command.latestVersionNumber)"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
final class OperationalCommandDetailModel: ObservableObject {
    private let commandID: UUID
    private weak var centerModel: OperationalCommandCenterModel?
    private let repository: OperationalCommandRepository
    @Published private(set) var command: OperationalCommand?
    @Published private(set) var versions: [OperationalCommandVersion] = []
    @Published var selectedVersionID: UUID?
    @Published private(set) var error: String?
    @Published var isEditingDraft = false
    @Published var operationError: String?
    @Published private(set) var previewDocument: PDFDocument?
    private var previewKey: String?

    init(commandID: UUID, centerModel: OperationalCommandCenterModel) {
        self.commandID = commandID
        self.centerModel = centerModel
        repository = centerModel.repository
        load()
    }

    var selectedVersion: OperationalCommandVersion? {
        versions.first { $0.id == selectedVersionID } ?? versions.first
    }

    func load() {
        error = nil
        do {
            let allCommands = (centerModel?.parentCommands ?? []) + (centerModel?.dailyCommands ?? [])
            command = allCommands.first { $0.id == commandID }
            versions = try repository.versions(forCommandID: commandID)
            if selectedVersionID == nil { selectedVersionID = versions.first?.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func publishDraft() throws {
        guard let selectedVersionID else { return }
        _ = try repository.publish(versionID: selectedVersionID)
        refreshAll(selecting: selectedVersionID)
    }

    func reviseCurrent() throws {
        guard let selectedVersionID else { return }
        let draft = try repository.createRevision(of: selectedVersionID)
        refreshAll(selecting: draft.id)
    }

    func withdrawCurrent() throws {
        guard let selectedVersionID else { return }
        try repository.withdraw(versionID: selectedVersionID)
        refreshAll(selecting: selectedVersionID)
    }

    func saveDraft(_ content: OperationalCommandDraftContent, dailyDate: String? = nil) throws {
        guard let selectedVersionID else { return }
        _ = try repository.updateDraft(versionID: selectedVersionID, content: content, dailyDate: dailyDate)
        refreshAll(selecting: selectedVersionID)
    }

    func preparePreview(versionID: UUID, snapshot: OperationalCommandSnapshot, language: InterfaceLanguage) {
        let key = "\(versionID.uuidString):\(language.rawValue)"
        guard previewKey != key else { return }
        previewKey = key
        previewDocument = nil
        do {
            guard let document = PDFDocument(data: try OperationalCommandDocumentRenderer.makePDF(snapshot, language: language)) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            previewDocument = document
        } catch {
            operationError = "\(language.text("Document preview failed:", "Pratinjau dokumen gagal:")) \(error.localizedDescription)"
        }
    }

    private func refreshAll(selecting id: UUID?) {
        centerModel?.load()
        selectedVersionID = id
        load()
    }
}

@MainActor
private struct OperationalCommandDetailView: View {
    @AppStorage("minority.interface-language") private var languageRawValue = InterfaceLanguage.english.rawValue
    @ObservedObject var model: OperationalCommandDetailModel
    @ObservedObject var centerModel: OperationalCommandCenterModel

    private var language: InterfaceLanguage {
        InterfaceLanguage(rawValue: languageRawValue) ?? .english
    }

    var body: some View {
        Group {
            if let error = model.error {
                ContentUnavailableView(language.text("Command Could Not Be Loaded", "Perintah Tidak Dapat Dimuat"), systemImage: "exclamationmark.triangle", description: Text(error))
            } else if let version = model.selectedVersion {
                List {
                    Section(language.text("Versions", "Versi")) {
                        ForEach(model.versions) { item in
                            Button {
                                model.selectedVersionID = item.id
                            } label: {
                                HStack {
                                    Text("v\(item.versionNumber)")
                                    Text(item.snapshot?.title ?? item.content.title)
                                    Spacer()
                                    Text(item.state.localizedName(language)).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let snapshot = version.snapshot {
                        Section(language.text("Published Document", "Dokumen Terbit")) {
                            if let document = model.previewDocument {
                                OperationalCommandPDFPreview(document: document)
                                    .frame(minHeight: 500)
                            } else {
                                ProgressView(language.text("Preparing document…", "Menyiapkan dokumen…"))
                            }
                            HStack {
                                Button {
                                    exportPDF(snapshot)
                                } label: {
                                    Label(language.text("Export PDF", "Ekspor PDF"), systemImage: "square.and.arrow.down")
                                }
                                Button {
                                    printDocument(snapshot)
                                } label: {
                                    Label(language.text("Print", "Cetak"), systemImage: "printer")
                                }
                            }
                        }
                        .task(id: "\(version.id.uuidString)-\(languageRawValue)") {
                            model.preparePreview(versionID: version.id, snapshot: snapshot, language: language)
                        }
                    } else {
                        Section(language.text("Draft", "Draf")) {
                            Text(version.content.title).font(.headline)
                            if let details = version.content.details { Text(details) }
                            if let classification = version.content.classification {
                                LabeledContent(language.text("Classification", "Klasifikasi"), value: classification)
                            }
                            if let priority = version.content.priority {
                                LabeledContent(language.text("Priority", "Prioritas"), value: String(priority))
                            }
                            if let date = version.content.effectiveDate ?? model.command?.date {
                                LabeledContent(language.text("Date", "Tanggal"), value: date)
                            }
                            if !version.content.items.isEmpty {
                                Section(language.text("Selected schedule items", "Jadwal yang dipilih")) {
                                    ForEach(Array(version.content.items.enumerated()), id: \.element.id) { index, item in
                                        let occurrence = centerModel.occurrences.first { $0.id == item.occurrenceID }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("\(index + 1). \(occurrence.flatMap { centerModel.activity(id: $0.activityID)?.title } ?? language.text("Missing activity", "Kegiatan tidak ditemukan"))")
                                            if let occurrence {
                                                Text("\(occurrence.scheduledDate) · \(occurrence.startTime ?? "—")–\(occurrence.endTime ?? "—")")
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                            if let parentID = item.parentVersionID,
                                               let parent = centerModel.parentVersions.first(where: { $0.id == parentID }) {
                                                Text("\(parent.number) v\(parent.versionNumber) · \(parent.snapshot?.title ?? parent.content.title)")
                                                    .font(.caption).foregroundStyle(.secondary)
                                            } else {
                                                Text(language.text("No parent command", "Tanpa Perintah Induk"))
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if let operationError = model.operationError {
                        Section {
                            Text(operationError).foregroundStyle(.red).textSelection(.enabled)
                        }
                    }

                    Section {
                        if version.state == .draft {
                            Button(language.text("Edit Draft", "Edit Draf")) { model.isEditingDraft = true }
                            Button(language.text("Publish Version", "Terbitkan Versi")) {
                                perform { try model.publishDraft() }
                            }
                        } else if version.state == .published,
                                  model.command?.currentPublishedVersionID == version.id {
                            Button(language.text("Create Revision", "Buat Revisi")) {
                                perform { try model.reviseCurrent() }
                            }
                            Button(language.text("Withdraw Version", "Tarik Versi"), role: .destructive) {
                                perform { try model.withdrawCurrent() }
                            }
                        }
                    }
                }
                .toolbar {
                    if let command = model.command {
                        ToolbarItem(placement: .principal) {
                            Text(command.number).font(.headline)
                        }
                    }
                }
            } else {
                ContentUnavailableView(language.text("No Command Versions", "Tidak Ada Versi Perintah"), systemImage: "doc.text")
            }
        }
        .navigationTitle(language.text("Command Details", "Rincian Perintah"))
        .task { model.load() }
        .sheet(isPresented: $model.isEditingDraft) {
            if let version = model.selectedVersion, version.state == .draft {
                if model.command?.kind == .parent {
                    ParentCommandDraftSheet(model: centerModel, existingDraft: version) { content in
                        try model.saveDraft(content)
                    }
                } else {
                    DailyCommandDraftSheet(model: centerModel, existingDraft: version) { content, date in
                        try model.saveDraft(content, dailyDate: date)
                    }
                }
            }
        }
        .environment(\.locale, language.locale)
    }

    private func perform(_ operation: () throws -> Void) {
        model.operationError = nil
        do { try operation() }
        catch { model.operationError = error.localizedDescription }
    }

    private func exportPDF(_ snapshot: OperationalCommandSnapshot) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(snapshot.number)-v\(snapshot.versionNumber).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try OperationalCommandDocumentRenderer.makePDF(snapshot, language: language).write(to: url, options: .atomic)
        } catch {
            model.operationError = "\(language.text("PDF export failed:", "Ekspor PDF gagal:")) \(error.localizedDescription)"
        }
    }

    private func printDocument(_ snapshot: OperationalCommandSnapshot) {
        do {
            guard let document = PDFDocument(data: try OperationalCommandDocumentRenderer.makePDF(snapshot, language: language)),
                  let operation = document.printOperation(
                    for: NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo(),
                    scalingMode: .pageScaleDownToFit,
                    autoRotate: true
                  ) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            operation.jobTitle = "\(snapshot.number) v\(snapshot.versionNumber)"
            guard operation.run() else { return }
        } catch {
            model.operationError = "\(language.text("Print failed:", "Cetak gagal:")) \(error.localizedDescription)"
        }
    }
}

@MainActor
private final class ParentCommandDraftFormModel: ObservableObject {
    @Published var title: String
    @Published var details: String
    @Published var classification: String
    @Published var priority: String
    @Published var effectiveDate: Date
    @Published var includesDate: Bool
    @Published var planIDs: Set<UUID>
    @Published var activityIDs: Set<UUID>
    @Published var objectiveIDs: Set<UUID>
    @Published var error: String?

    init(content: OperationalCommandDraftContent?) {
        title = content?.title ?? ""
        details = content?.details ?? ""
        classification = content?.classification ?? ""
        priority = content?.priority.map(String.init) ?? ""
        effectiveDate = Self.date(from: content?.effectiveDate) ?? .now
        includesDate = content?.effectiveDate != nil
        planIDs = Set(content?.targets.filter { $0.kind == .plan }.map(\.targetID) ?? [])
        activityIDs = Set(content?.targets.filter { $0.kind == .activity }.map(\.targetID) ?? [])
        objectiveIDs = Set(content?.targets.filter { $0.kind == .objective }.map(\.targetID) ?? [])
    }

    private static func date(from value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

@MainActor
private struct ParentCommandDraftSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: OperationalCommandCenterModel
    var existingDraft: OperationalCommandVersion?
    var onSave: ((OperationalCommandDraftContent) throws -> Void)?
    @StateObject private var form: ParentCommandDraftFormModel

    init(
        model: OperationalCommandCenterModel,
        existingDraft: OperationalCommandVersion? = nil,
        onSave: ((OperationalCommandDraftContent) throws -> Void)? = nil
    ) {
        self.model = model
        self.existingDraft = existingDraft
        self.onSave = onSave
        _form = StateObject(wrappedValue: ParentCommandDraftFormModel(content: existingDraft?.content))
    }

    private var language: InterfaceLanguage {
        InterfaceLanguage(rawValue: UserDefaults.standard.string(forKey: "minority.interface-language") ?? "english") ?? .english
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.text(existingDraft == nil ? "New Parent Command" : "Edit Parent Command Draft", existingDraft == nil ? "Perintah Induk Baru" : "Edit Draf Perintah Induk"))
                .font(.title2).bold()
            Form {
                TextField(language.text("Title", "Judul"), text: $form.title)
                TextField(language.text("Details", "Rincian"), text: $form.details, axis: .vertical)
                TextField(language.text("Classification", "Klasifikasi"), text: $form.classification)
                TextField(language.text("Priority (optional, no scale is defined)", "Prioritas (opsional, skala belum ditetapkan)"), text: $form.priority)
                Toggle(language.text("Set an effective date", "Atur tanggal berlaku"), isOn: $form.includesDate)
                if form.includesDate {
                    DatePicker(language.text("Effective date", "Tanggal berlaku"), selection: $form.effectiveDate, displayedComponents: .date)
                }
                Section(language.text("Plan targets", "Target rencana")) {
                    if model.plans.isEmpty { Text(language.text("No plans available", "Tidak ada rencana")).foregroundStyle(.secondary) }
                    ForEach(model.plans) { plan in
                        Toggle(plan.title, isOn: binding(for: plan.id, in: $form.planIDs))
                    }
                }
                Section(language.text("Activity targets", "Target kegiatan")) {
                    if model.activities.isEmpty { Text(language.text("No activities available", "Tidak ada kegiatan")).foregroundStyle(.secondary) }
                    ForEach(model.activities) { activity in
                        Toggle(activity.title, isOn: binding(for: activity.id, in: $form.activityIDs))
                    }
                }
                Section(language.text("Objective targets", "Target tujuan")) {
                    if model.objectives.isEmpty { Text(language.text("No objectives available", "Tidak ada tujuan")).foregroundStyle(.secondary) }
                    ForEach(model.objectives) { objective in
                        Toggle(objective.title, isOn: binding(for: objective.id, in: $form.objectiveIDs))
                    }
                }
                if let error = form.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            }
            HStack {
                Spacer()
                Button(language.text("Cancel", "Batal")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(language.text("Save Draft", "Simpan Draf")) { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 620)
        .environment(\.locale, language.locale)
    }

    private func save() {
        do {
            let parsedPriority = Int(form.priority)
            guard form.priority.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || parsedPriority != nil else {
                throw OperationalCommandValidationError.invalidPriority
            }
            let value = try OperationalCommandDraftContent(
                title: form.title,
                details: form.details,
                classification: form.classification,
                priority: parsedPriority,
                effectiveDate: form.includesDate ? Self.isoDate(form.effectiveDate) : nil,
                targets: model.plans.filter { form.planIDs.contains($0.id) }.map {
                    OperationalCommandTarget(kind: .plan, targetID: $0.id)
                } + model.activities.filter { form.activityIDs.contains($0.id) }.map {
                    OperationalCommandTarget(kind: .activity, targetID: $0.id)
                } + model.objectives.filter { form.objectiveIDs.contains($0.id) }.map {
                    OperationalCommandTarget(kind: .objective, targetID: $0.id)
                }
            )
            if let onSave { try onSave(value) }
            else { _ = try model.createParentDraft(value) }
            dismiss()
        } catch {
            form.error = error.localizedDescription
        }
    }

    private func binding(for id: UUID, in selection: Binding<Set<UUID>>) -> Binding<Bool> {
        Binding(
            get: { selection.wrappedValue.contains(id) },
            set: { selected in
                var values = selection.wrappedValue
                if selected { values.insert(id) }
                else { values.remove(id) }
                selection.wrappedValue = values
            }
        )
    }

    private static func isoDate(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

@MainActor
private final class DailyCommandDraftFormModel: ObservableObject {
    @Published var title: String
    @Published var details: String
    @Published var date: Date
    @Published var orderedOccurrenceIDs: [UUID]
    @Published var parentVersionIDs: [UUID: String]
    @Published var error: String?

    init(content: OperationalCommandDraftContent?, commandDate: String?) {
        title = content?.title ?? ""
        details = content?.details ?? ""
        date = Self.date(from: commandDate ?? ISO8601DateFormatter().string(from: .now).prefix(10).description) ?? .now
        orderedOccurrenceIDs = content?.items.map(\.occurrenceID) ?? []
        parentVersionIDs = Dictionary(uniqueKeysWithValues: content?.items.map {
            ($0.occurrenceID, $0.parentVersionID?.uuidString ?? "")
        } ?? [])
    }

    private static func date(from value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

@MainActor
private struct DailyCommandDraftSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: OperationalCommandCenterModel
    var existingDraft: OperationalCommandVersion?
    var onSave: ((OperationalCommandDraftContent, String) throws -> Void)?
    @StateObject private var form: DailyCommandDraftFormModel

    init(
        model: OperationalCommandCenterModel,
        existingDraft: OperationalCommandVersion? = nil,
        onSave: ((OperationalCommandDraftContent, String) throws -> Void)? = nil
    ) {
        self.model = model
        self.existingDraft = existingDraft
        self.onSave = onSave
        let commandDate = existingDraft.flatMap { draft in
            (model.parentCommands + model.dailyCommands).first { $0.id == draft.commandID }?.date
        }
        _form = StateObject(wrappedValue: DailyCommandDraftFormModel(content: existingDraft?.content, commandDate: commandDate))
    }

    private var language: InterfaceLanguage {
        InterfaceLanguage(rawValue: UserDefaults.standard.string(forKey: "minority.interface-language") ?? "english") ?? .english
    }

    private var dateText: String { Self.isoDate(form.date) }
    private var dayOccurrences: [ScheduleOccurrence] { model.occurrences(on: dateText) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.text(existingDraft == nil ? "New Daily Command" : "Edit Daily Command Draft", existingDraft == nil ? "Perintah Harian Baru" : "Edit Draf Perintah Harian"))
                .font(.title2).bold()
            Form {
                DatePicker(language.text("Command date", "Tanggal perintah"), selection: $form.date, displayedComponents: .date)
                TextField(language.text("Title", "Judul"), text: $form.title)
                TextField(language.text("Details", "Rincian"), text: $form.details, axis: .vertical)
                Section(language.text("Scheduled occurrences for \(dateText)", "Occurrence terjadwal untuk \(dateText)")) {
                    if dayOccurrences.isEmpty {
                        Text(language.text("No occurrences are scheduled for this date. Scheduling here will not create one.", "Tidak ada occurrence pada tanggal ini. Perintah tidak membuat jadwal."))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(dayOccurrences) { occurrence in
                        VStack(alignment: .leading, spacing: 5) {
                            Toggle(isOn: occurrenceBinding(occurrence.id)) {
                                VStack(alignment: .leading) {
                                    Text(model.activity(id: occurrence.activityID)?.title ?? language.text("Missing activity", "Kegiatan tidak ditemukan"))
                                    Text("\(occurrence.startTime ?? "—") – \(occurrence.endTime ?? "—")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if form.orderedOccurrenceIDs.contains(occurrence.id) {
                                HStack {
                                    Text(language.text("Order \(order(of: occurrence.id))", "Urutan \(order(of: occurrence.id))"))
                                        .font(.caption)
                                    Button(language.text("Up", "Naik")) { move(occurrence.id, by: -1) }
                                        .disabled(order(of: occurrence.id) == 1)
                                    Button(language.text("Down", "Turun")) { move(occurrence.id, by: 1) }
                                        .disabled(order(of: occurrence.id) == form.orderedOccurrenceIDs.count)
                                    Picker(language.text("Parent version", "Versi Perintah Induk"), selection: parentBinding(for: occurrence.id)) {
                                        Text(language.text("No parent", "Tanpa induk")).tag("")
                                        ForEach(model.parentVersions) { version in
                                            Text("\(version.number) v\(version.versionNumber) · \(version.snapshot?.title ?? version.content.title)")
                                                .tag(version.id.uuidString)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                if let error = form.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            }
            .onChange(of: dateText) { _, newValue in
                let validIDs = Set(model.occurrences(on: newValue).map(\.id))
                form.orderedOccurrenceIDs.removeAll { !validIDs.contains($0) }
            }
            HStack {
                Spacer()
                Button(language.text("Cancel", "Batal")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(language.text("Save Draft", "Simpan Draf")) { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 600)
        .environment(\.locale, language.locale)
    }

    private func save() {
        do {
            let content = try OperationalCommandDraftContent(
                title: form.title.isEmpty
                    ? language.text("Daily command \(dateText)", "Perintah harian \(dateText)")
                    : form.title,
                details: form.details,
                items: form.orderedOccurrenceIDs.map { id in
                    OperationalCommandItem(occurrenceID: id, parentVersionID: UUID(uuidString: form.parentVersionIDs[id] ?? ""))
                }
            )
            if let onSave { try onSave(content, dateText) }
            else { _ = try model.createDailyDraft(date: dateText, content: content) }
            dismiss()
        } catch {
            form.error = error.localizedDescription
        }
    }

    private func occurrenceBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { form.orderedOccurrenceIDs.contains(id) },
            set: { selected in
                if selected, !form.orderedOccurrenceIDs.contains(id) { form.orderedOccurrenceIDs.append(id) }
                else { form.orderedOccurrenceIDs.removeAll { $0 == id } }
            }
        )
    }

    private func parentBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { form.parentVersionIDs[id] ?? "" },
            set: {
                var selections = form.parentVersionIDs
                selections[id] = $0
                form.parentVersionIDs = selections
            }
        )
    }

    private func order(of id: UUID) -> Int { (form.orderedOccurrenceIDs.firstIndex(of: id) ?? -1) + 1 }

    private func move(_ id: UUID, by offset: Int) {
        guard let index = form.orderedOccurrenceIDs.firstIndex(of: id) else { return }
        let destination = index + offset
        guard form.orderedOccurrenceIDs.indices.contains(destination) else { return }
        form.orderedOccurrenceIDs.swapAt(index, destination)
    }

    private static func isoDate(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

private struct OperationalCommandPDFPreview: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = document
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
    }
}

private enum OperationalCommandDocumentRenderer {
    private static let pageSize = CGSize(width: 595.28, height: 841.89)
    private static let pageMargins = CGFloat(42)

    static func makePDF(_ snapshot: OperationalCommandSnapshot, language: InterfaceLanguage) throws -> Data {
        let content = makeContent(snapshot, language: language)
        let frameSetter = CTFramesetterCreateWithAttributedString(content as CFAttributedString)
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let pageRect = CGRect(
            x: pageMargins,
            y: pageMargins,
            width: pageSize.width - 2 * pageMargins,
            height: pageSize.height - 2 * pageMargins
        )
        var offset = 0
        while offset < content.length {
            context.beginPDFPage(nil)
            let path = CGPath(rect: pageRect, transform: nil)
            let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: offset, length: 0), path, nil)
            let visibleRange = CTFrameGetVisibleStringRange(frame)
            guard visibleRange.length > 0 else {
                context.endPDFPage()
                context.closePDF()
                throw CocoaError(.fileWriteUnknown)
            }
            CTFrameDraw(frame, context)
            context.endPDFPage()
            offset += visibleRange.length
        }
        context.closePDF()
        return data as Data
    }

    private static func makeContent(_ snapshot: OperationalCommandSnapshot, language: InterfaceLanguage) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        append("\(snapshot.number)   ·   \(language.text("Version", "Versi")) \(snapshot.versionNumber)", fontSize: 11, weight: .medium, spacing: 12, to: result)
        append(snapshot.title, fontSize: 24, weight: .bold, spacing: 12, to: result)
        if let date = snapshot.date { append(date, fontSize: 11, weight: .regular, spacing: 8, to: result) }
        if let classification = snapshot.classification {
            append("\(language.text("Classification", "Klasifikasi")): \(classification)", fontSize: 11, weight: .regular, spacing: 6, to: result)
        }
        if let priority = snapshot.priority {
            append("\(language.text("Priority", "Prioritas")): \(priority)", fontSize: 11, weight: .regular, spacing: 8, to: result)
        }
        if let details = snapshot.details, !details.isEmpty {
            append(details, fontSize: 11, weight: .regular, spacing: 12, to: result)
        }
        if !snapshot.targets.isEmpty {
            append(language.text("Targets", "Target"), fontSize: 15, weight: .bold, spacing: 8, to: result)
            for (index, target) in snapshot.targets.enumerated() {
                append("\(index + 1). \(target.title)", fontSize: 12, weight: .semibold, spacing: 2, to: result)
                append(target.kind.localizedName(language), fontSize: 9, weight: .regular, spacing: 4, to: result)
                if let details = target.details, !details.isEmpty {
                    append(details, fontSize: 10, weight: .regular, spacing: 4, to: result)
                }
                if let start = target.startDate, let end = target.endDate {
                    append("\(start) — \(end)", fontSize: 9, weight: .regular, spacing: 8, to: result)
                }
            }
        }
        if !snapshot.items.isEmpty {
            append(language.text("Scheduled items", "Kegiatan terjadwal"), fontSize: 15, weight: .bold, spacing: 8, to: result)
            for item in snapshot.items {
                append("\(item.order). \(item.title)", fontSize: 12, weight: .semibold, spacing: 3, to: result)
                append("\(item.date) · \(item.startTime ?? "—")–\(item.endTime ?? "—")", fontSize: 10, weight: .regular, spacing: 4, to: result)
                if let details = item.details, !details.isEmpty {
                    append(details, fontSize: 10, weight: .regular, spacing: 4, to: result)
                }
                if let priority = item.priority {
                    append("\(language.text("Priority", "Prioritas")): \(priority)", fontSize: 9, weight: .regular, spacing: 4, to: result)
                }
                if let parent = item.parent {
                    append("\(parent.number) v\(parent.versionNumber) · \(parent.title)", fontSize: 9, weight: .regular, spacing: 8, to: result)
                }
            }
        }
        return result
    }

    private static func append(
        _ text: String,
        fontSize: CGFloat,
        weight: NSFont.Weight,
        spacing: CGFloat,
        to result: NSMutableAttributedString
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = spacing
        result.append(NSAttributedString(
            string: text + "\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
                .foregroundColor: NSColor.black,
                .paragraphStyle: paragraph
            ]
        ))
    }
}

private extension OperationalCommandVersionState {
    func localizedName(_ language: InterfaceLanguage) -> String {
        switch self {
        case .draft: language.text("Draft", "Draf")
        case .published: language.text("Published", "Terbit")
        case .superseded: language.text("Superseded", "Digantikan")
        case .withdrawn: language.text("Withdrawn", "Ditarik")
        }
    }
}

private extension OperationalCommandTargetKind {
    func localizedName(_ language: InterfaceLanguage) -> String {
        switch self {
        case .plan: language.text("Plan", "Rencana")
        case .activity: language.text("Activity", "Kegiatan")
        case .objective: language.text("Objective", "Tujuan")
        }
    }
}
