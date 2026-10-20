import Combine
import SwiftUI
import MinorityPersistence

private enum InterfaceLanguage: String, CaseIterable {
    case english
    case bahasaIndonesia

    var locale: Locale {
        Locale(identifier: self == .english ? "en" : "id")
    }

    var name: String {
        switch self {
        case .english: "English"
        case .bahasaIndonesia: "Bahasa Indonesia"
        }
    }

    func text(_ english: String, _ indonesian: String) -> String {
        self == .english ? english : indonesian
    }
}

@MainActor
final class PlanListModel: ObservableObject {
    private let repository: PlanningRepository
    private let databaseManager: DatabaseManager
    @Published private(set) var plans: [Plan] = []
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?
    @Published var isShowingCreateSheet = false
    @Published var newPlanTitle = ""
    @Published var newPlanStartDate = Calendar(identifier: .gregorian).startOfDay(for: .now)
    @Published var newPlanEndDate = Calendar(identifier: .gregorian).startOfDay(for: .now)
    @Published var createError: String?
    @Published private(set) var objectives: [Objective] = []
    @Published private(set) var objectivePlanCounts: [UUID: Int] = [:]
    @Published private(set) var objectiveLibraryError: String?
    @Published var isShowingObjectiveLibrary = false
    @Published var isCreatingObjective = false
    @Published var objectiveToEdit: Objective?
    @Published var objectiveToDelete: Objective?
    @Published var objectiveOperationError: String?

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
        repository = PlanningRepository(databaseQueue: databaseManager.databaseQueue)
    }

    func load() {
        isLoading = true
        loadError = nil

        do {
            plans = try repository.plans()
        } catch {
            loadError = error.localizedDescription
        }

        isLoading = false
    }

    func create(_ plan: Plan) throws {
        try repository.create(plan)
        plans.append(plan)
        plans.sort {
            ($0.startDate, $0.title, $0.id.uuidString) < ($1.startDate, $1.title, $1.id.uuidString)
        }
    }

    func beginPlanCreation() {
        newPlanTitle = ""
        newPlanStartDate = Calendar(identifier: .gregorian).startOfDay(for: .now)
        newPlanEndDate = newPlanStartDate
        createError = nil
        isShowingCreateSheet = true
    }

    func detailModel(for plan: Plan) -> PlanDetailModel {
        PlanDetailModel(plan: plan, databaseManager: databaseManager)
    }

    func loadObjectives() {
        objectiveLibraryError = nil
        do {
            objectives = try repository.objectives()
            objectivePlanCounts = try Dictionary(uniqueKeysWithValues: objectives.map {
                ($0.id, try repository.objectivePlanCount(id: $0.id))
            })
        } catch {
            objectiveLibraryError = error.localizedDescription
        }
    }

    func createObjective(title: String, details: String) throws {
        try repository.create(Objective(title: title, details: details))
        loadObjectives()
    }

    func updateObjective(id: UUID, title: String, details: String) throws {
        let objective = try Objective(id: id, title: title, details: details)
        guard try repository.update(objective) else {
            throw ObjectiveLibraryError.missingObjective
        }
        loadObjectives()
    }

    func deleteObjective(id: UUID) throws {
        guard try repository.deleteObjective(id: id) else {
            throw ObjectiveLibraryError.missingObjective
        }
        loadObjectives()
    }
}

private enum ObjectiveLibraryError: Error, LocalizedError {
    case missingObjective

    var errorDescription: String? {
        "The objective no longer exists. Reload the objective list and try again."
    }
}

@MainActor
struct PlanListView: View {
    @AppStorage("minority.interface-language") private var languageRawValue = InterfaceLanguage.english.rawValue
    @ObservedObject var model: PlanListModel

    private var language: InterfaceLanguage {
        InterfaceLanguage(rawValue: languageRawValue) ?? .english
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    ProgressView(language.text("Loading plans…", "Memuat rencana…"))
                } else if let loadError = model.loadError {
                    VStack(spacing: 12) {
                        ContentUnavailableView(
                            language.text("Plans Could Not Be Loaded", "Rencana Tidak Dapat Dimuat"),
                            systemImage: "exclamationmark.triangle",
                            description: Text(loadError)
                        )
                        Button(language.text("Try Again", "Coba Lagi")) {
                            model.load()
                        }
                    }
                } else if model.plans.isEmpty {
                    ContentUnavailableView(
                        language.text("No Plans Yet", "Belum Ada Rencana"),
                        systemImage: "list.bullet.rectangle",
                        description: Text(language.text(
                            "Create a plan to see it here.",
                            "Buat rencana untuk melihatnya di sini."
                        ))
                    )
                } else {
                    List(model.plans) { plan in
                        NavigationLink {
                            PlanDetailView(language: language, model: model.detailModel(for: plan))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.title)
                                    .font(.headline)
                                Text("\(plan.startDate) — \(plan.endDate)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
            .navigationTitle(language.text("Plans", "Rencana"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            model.beginPlanCreation()
                        } label: {
                            Label(language.text("New Plan", "Rencana Baru"), systemImage: "plus")
                        }
                        Button {
                            model.loadObjectives()
                            model.isShowingObjectiveLibrary = true
                        } label: {
                            Label(language.text("Objectives", "Tujuan"), systemImage: "scope")
                        }
                        .disabled(model.isLoading || model.loadError != nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .environment(\.locale, language.locale)
        .task {
            model.load()
        }
        .sheet(isPresented: $model.isShowingCreateSheet) {
            CreatePlanSheet(language: language, model: model)
        }
        .sheet(isPresented: $model.isShowingObjectiveLibrary) {
            ObjectiveLibrarySheet(language: language, model: model)
        }
    }
}

@MainActor
final class PlanDetailModel: ObservableObject {
    let plan: Plan
    private let repository: PlanningRepository
    @Published private(set) var activities: [Activity] = []
    @Published private(set) var activitiesAvailableToLink: [Activity] = []
    @Published private(set) var objectives: [Objective] = []
    @Published private(set) var objectivesAvailableToLink: [Objective] = []
    @Published private(set) var occurrences: [UUID: [ScheduleOccurrence]] = [:]
    @Published private(set) var executionRecords: [UUID: ExecutionRecord] = [:]
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?
    @Published var isShowingActivitySheet = false
    @Published var isShowingLinkActivitySheet = false
    @Published var isShowingObjectiveSheet = false
    @Published var isShowingLinkObjectiveSheet = false
    @Published var activityToSchedule: Activity?
    @Published var activityIDToLink: UUID?
    @Published var objectiveIDToLink: UUID?
    @Published var objectiveError: String?
    @Published var objectiveLinkError: String?
    @Published var linkError: String?
    @Published var executionSaveError: String?

    init(plan: Plan, databaseManager: DatabaseManager) {
        self.plan = plan
        repository = PlanningRepository(databaseQueue: databaseManager.databaseQueue)
    }

    func load() {
        isLoading = true
        loadError = nil
        do {
            activities = try repository.activities(forPlanID: plan.id)
            activitiesAvailableToLink = try repository.activitiesNotLinked(toPlanID: plan.id)
            objectives = try repository.objectives(forPlanID: plan.id)
            objectivesAvailableToLink = try repository.objectivesNotLinked(toPlanID: plan.id)
            occurrences = try Dictionary(uniqueKeysWithValues: activities.map {
                ($0.id, try repository.scheduleOccurrences(forActivityID: $0.id))
            })
            var recordsByOccurrence: [UUID: ExecutionRecord] = [:]
            for activity in activities {
                for record in try repository.executionRecords(forActivityID: activity.id) {
                    recordsByOccurrence[record.occurrenceID] = record
                }
            }
            executionRecords = recordsByOccurrence
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func createActivity(title: String, details: String) throws {
        let activity = try Activity(title: title, details: details)
        try repository.create(activity, linkedToPlanID: plan.id)
        load()
    }

    func linkExistingActivity(id: UUID) throws {
        try repository.link(activityID: id, toPlanID: plan.id)
        activityIDToLink = nil
        linkError = nil
        load()
    }

    func createObjective(title: String, details: String) throws {
        let objective = try Objective(title: title, details: details)
        try repository.create(objective, linkedToPlanID: plan.id)
        load()
    }

    func linkExistingObjective(id: UUID) throws {
        try repository.link(objectiveID: id, toPlanID: plan.id)
        objectiveIDToLink = nil
        load()
    }

    func unlinkObjective(id: UUID) throws {
        try repository.unlink(objectiveID: id, fromPlanID: plan.id)
        load()
    }

    func schedule(_ occurrence: ScheduleOccurrence) throws {
        try repository.schedule(occurrence)
        load()
    }

    func recordExecution(for occurrenceID: UUID) throws {
        let record = try ExecutionRecord(occurrenceID: occurrenceID, recordedAt: .now)
        try repository.recordExecution(record)
        executionSaveError = nil
        load()
    }
}

@MainActor
private struct PlanDetailView: View {
    let language: InterfaceLanguage
    @StateObject private var model: PlanDetailModel

    init(language: InterfaceLanguage, model: PlanDetailModel) {
        self.language = language
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView(language.text("Loading plan details…", "Memuat rincian rencana…"))
            } else if let loadError = model.loadError {
                VStack(spacing: 12) {
                    ContentUnavailableView(
                        language.text("Plan Details Could Not Be Loaded", "Rincian Rencana Tidak Dapat Dimuat"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                    Button(language.text("Try Again", "Coba Lagi")) { model.load() }
                }
            } else {
                List {
                    Section(language.text("Objectives", "Tujuan")) {
                        if model.objectives.isEmpty {
                            Text(language.text("No objectives linked to this plan.", "Belum ada tujuan pada rencana ini."))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(model.objectives) { objective in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(objective.title).font(.headline)
                                        if let details = objective.details {
                                            Text(details).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button(language.text("Unlink", "Lepas Tautan"), role: .destructive) {
                                        do {
                                            try model.unlinkObjective(id: objective.id)
                                        } catch {
                                            model.objectiveError = error.localizedDescription
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }

                    Section(language.text("Activities", "Kegiatan")) {
                        if model.activities.isEmpty {
                            Text(language.text(
                                "Add an activity to this plan. Scheduling is a separate, explicit step.",
                                "Tambahkan kegiatan ke rencana ini. Penjadwalan adalah langkah terpisah dan eksplisit."
                            ))
                            .foregroundStyle(.secondary)
                        }
                        ForEach(model.activities) { activity in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(activity.title).font(.headline)
                                        if let details = activity.details {
                                            Text(details).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button(language.text("Schedule Once", "Jadwalkan Sekali")) {
                                        model.activityToSchedule = activity
                                    }
                                }

                                let items = model.occurrences[activity.id] ?? []
                                if items.isEmpty {
                                    Text(language.text("No scheduled occurrences", "Belum ada jadwal"))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(items) { occurrence in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(scheduleDescription(occurrence))
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            if let record = model.executionRecords[occurrence.id] {
                                                Label {
                                                    Text("\(language.text("Recorded at", "Catatan dibuat pada")) · \(record.recordedAt.formatted(date: .abbreviated, time: .shortened))")
                                                } icon: {
                                                    Image(systemName: "checkmark.circle.fill")
                                                }
                                                .font(.caption)
                                            } else {
                                                HStack {
                                                    Text(language.text("No execution record", "Belum ada catatan pelaksanaan"))
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                    Button(language.text("Record as completed", "Catat sudah terlaksana")) {
                                                        do {
                                                            try model.recordExecution(for: occurrence.id)
                                                        } catch {
                                                            model.executionSaveError = error.localizedDescription
                                                        }
                                                    }
                                                    .font(.caption)
                                                }
                                                Text(language.text(
                                                    "The saved time is when you record this, not when the activity happened.",
                                                    "Waktu yang disimpan adalah saat Anda mencatat, bukan saat kegiatan dilakukan."
                                                ))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
            }
        }
        .navigationTitle(model.plan.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        model.isShowingObjectiveSheet = true
                    } label: {
                        Label(language.text("New Objective", "Tujuan Baru"), systemImage: "scope")
                    }
                    Button {
                        model.objectiveIDToLink = nil
                        model.isShowingLinkObjectiveSheet = true
                    } label: {
                        Label(language.text("Link Existing Objective", "Tautkan Tujuan yang Ada"), systemImage: "link")
                    }
                    Button {
                        model.isShowingActivitySheet = true
                    } label: {
                        Label(language.text("New Activity", "Kegiatan Baru"), systemImage: "plus")
                    }
                    Button {
                        model.isShowingLinkActivitySheet = true
                    } label: {
                        Label(language.text("Link Existing Activity", "Tautkan Kegiatan yang Ada"), systemImage: "link")
                    }
                } label: {
                    Label(language.text("Add Activity", "Tambah Kegiatan"), systemImage: "plus")
                }
                .disabled(model.isLoading || model.loadError != nil)
            }
        }
        .task { model.load() }
        .sheet(isPresented: $model.isShowingActivitySheet) {
            CreateActivitySheet(language: language, model: model)
        }
        .sheet(isPresented: $model.isShowingObjectiveSheet) {
            CreateObjectiveSheet(language: language, model: model)
        }
        .sheet(isPresented: $model.isShowingLinkObjectiveSheet) {
            LinkExistingObjectiveSheet(language: language, model: model)
        }
        .sheet(isPresented: $model.isShowingLinkActivitySheet) {
            LinkExistingActivitySheet(language: language, model: model)
        }
        .sheet(item: $model.activityToSchedule) { activity in
            ScheduleOccurrenceSheet(language: language, activity: activity, model: model)
        }
        .alert(
            language.text("Execution Record Could Not Be Saved", "Catatan Pelaksanaan Tidak Dapat Disimpan"),
            isPresented: Binding(
                get: { model.executionSaveError != nil },
                set: { if !$0 { model.executionSaveError = nil } }
            )
        ) {
            Button(language.text("OK", "OK"), role: .cancel) { model.executionSaveError = nil }
        } message: {
            Text(model.executionSaveError ?? "")
        }
        .alert(
            language.text("Objective Could Not Be Updated", "Tujuan Tidak Dapat Diperbarui"),
            isPresented: Binding(
                get: { model.objectiveError != nil },
                set: { if !$0 { model.objectiveError = nil } }
            )
        ) {
            Button(language.text("OK", "OK"), role: .cancel) { model.objectiveError = nil }
        } message: {
            Text(model.objectiveError ?? "")
        }
    }

    private func scheduleDescription(_ occurrence: ScheduleOccurrence) -> String {
        let times = if let start = occurrence.startTime, let end = occurrence.endTime {
            " · \(start)–\(end)"
        } else {
            ""
        }
        return "\(occurrence.scheduledDate)\(times)"
    }
}

@MainActor
private struct LinkExistingActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let language: InterfaceLanguage
    @ObservedObject var model: PlanDetailModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language.text("Link Existing Activity", "Tautkan Kegiatan yang Ada"))
                .font(.title2)
                .bold()
            Text(language.text(
                "Choose an activity to link to \(model.plan.title). The activity remains one shared record.",
                "Pilih kegiatan untuk ditautkan ke \(model.plan.title). Kegiatan tetap menjadi satu data bersama."
            ))
            .foregroundStyle(.secondary)

            if model.activitiesAvailableToLink.isEmpty {
                ContentUnavailableView(
                    language.text("No Activities to Link", "Tidak Ada Kegiatan untuk Ditautkan"),
                    systemImage: "link",
                    description: Text(language.text(
                        "Create an activity in another plan first.",
                        "Buat kegiatan di rencana lain terlebih dahulu."
                    ))
                )
                .frame(minHeight: 150)
            } else {
                List {
                    ForEach(model.activitiesAvailableToLink) { activity in
                        Button {
                            model.activityIDToLink = activity.id
                            model.linkError = nil
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: model.activityIDToLink == activity.id ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(model.activityIDToLink == activity.id ? Color.accentColor : Color.secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(activity.title)
                                    if let details = activity.details {
                                        Text(details)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
                .frame(minHeight: 180)
            }

            if let error = model.linkError {
                Text("\(language.text("The activity could not be linked:", "Kegiatan tidak dapat ditautkan:")) \(error)")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button(language.text("Cancel", "Batal")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(language.text("Link Activity", "Tautkan Kegiatan")) {
                    linkSelectedActivity()
                }
                .disabled(model.activityIDToLink == nil || model.activitiesAvailableToLink.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 320)
        .environment(\.locale, language.locale)
        .onAppear {
            model.activityIDToLink = nil
            model.linkError = nil
        }
    }

    private func linkSelectedActivity() {
        guard let activityID = model.activityIDToLink else { return }
        model.linkError = nil
        do {
            try model.linkExistingActivity(id: activityID)
            dismiss()
        } catch {
            model.linkError = error.localizedDescription
        }
    }
}

@MainActor
private final class ActivityCreationForm: ObservableObject {
    @Published var title = ""
    @Published var details = ""
    @Published var error: String?
    let language: InterfaceLanguage
    let model: PlanDetailModel

    init(language: InterfaceLanguage, model: PlanDetailModel) {
        self.language = language
        self.model = model
    }

    func save() -> Bool {
        error = nil
        do {
            try model.createActivity(title: title, details: details)
            return true
        } catch let validationError as PlanningValidationError {
            error = validationError == .emptyTitle
                ? language.text("Enter a title for the activity.", "Masukkan judul kegiatan.")
                : validationError.localizedDescription
        } catch let saveError {
            error = "\(language.text("The activity could not be saved:", "Kegiatan tidak dapat disimpan:")) \(saveError.localizedDescription)"
        }
        return false
    }
}

@MainActor
private struct CreateActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var form: ActivityCreationForm

    init(language: InterfaceLanguage, model: PlanDetailModel) {
        _form = StateObject(wrappedValue: ActivityCreationForm(language: language, model: model))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(form.language.text("New Activity", "Kegiatan Baru")).font(.title2).bold()
            Text(form.language.text("This activity will be linked to \(form.model.plan.title).", "Kegiatan ini akan dihubungkan ke \(form.model.plan.title)."))
                .foregroundStyle(.secondary)
            Form {
                TextField(form.language.text("Title", "Judul"), text: $form.title)
                TextField(form.language.text("Details (optional)", "Rincian (opsional)"), text: $form.details, axis: .vertical)
                if let error = form.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            }
            HStack {
                Spacer()
                Button(form.language.text("Cancel", "Batal")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(form.language.text("Create Activity", "Buat Kegiatan")) {
                    if form.save() { dismiss() }
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 260)
    }

}

@MainActor
private final class ObjectiveCreationForm: ObservableObject {
    @Published var title = ""
    @Published var details = ""
    @Published var error: String?
    let language: InterfaceLanguage
    let model: PlanDetailModel

    init(language: InterfaceLanguage, model: PlanDetailModel) {
        self.language = language
        self.model = model
    }

    func save() -> Bool {
        error = nil
        do {
            try model.createObjective(title: title, details: details)
            return true
        } catch let validationError as PlanningValidationError {
            error = validationError == .emptyTitle
                ? language.text("Enter a title for the objective.", "Masukkan judul tujuan.")
                : validationError.localizedDescription
        } catch let saveError {
            error = "\(language.text("The objective could not be saved:", "Tujuan tidak dapat disimpan:")) \(saveError.localizedDescription)"
        }
        return false
    }
}

@MainActor
private struct CreateObjectiveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var form: ObjectiveCreationForm

    init(language: InterfaceLanguage, model: PlanDetailModel) {
        _form = StateObject(wrappedValue: ObjectiveCreationForm(language: language, model: model))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(form.language.text("New Objective", "Tujuan Baru"))
                .font(.title2)
                .bold()
            Text(form.language.text("This objective will be linked to the current plan.", "Tujuan ini akan ditautkan ke rencana saat ini."))
                .foregroundStyle(.secondary)
            Form {
                TextField(form.language.text("Title", "Judul"), text: $form.title)
                TextField(form.language.text("Details (optional)", "Rincian (opsional)"), text: $form.details, axis: .vertical)
                if let error = form.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            }
            HStack {
                Spacer()
                Button(form.language.text("Cancel", "Batal")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(form.language.text("Create Objective", "Buat Tujuan")) {
                    if form.save() { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 260)
        .environment(\.locale, form.language.locale)
    }
}

@MainActor
private struct LinkExistingObjectiveSheet: View {
    @Environment(\.dismiss) private var dismiss
    let language: InterfaceLanguage
    @ObservedObject var model: PlanDetailModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language.text("Link Existing Objective", "Tautkan Tujuan yang Ada"))
                .font(.title2)
                .bold()
            Text(language.text(
                "The same objective can be shared across plans.",
                "Tujuan yang sama dapat digunakan bersama di beberapa rencana."
            ))
            .foregroundStyle(.secondary)

            if model.objectivesAvailableToLink.isEmpty {
                ContentUnavailableView(
                    language.text("No Objectives to Link", "Tidak Ada Tujuan untuk Ditautkan"),
                    systemImage: "scope",
                    description: Text(language.text(
                        "Create an objective in another plan first.",
                        "Buat tujuan di rencana lain terlebih dahulu."
                    ))
                )
                .frame(minHeight: 150)
            } else {
                List(model.objectivesAvailableToLink) { objective in
                    Button {
                        model.objectiveIDToLink = objective.id
                        model.objectiveLinkError = nil
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: model.objectiveIDToLink == objective.id ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(model.objectiveIDToLink == objective.id ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(objective.title)
                                if let details = objective.details {
                                    Text(details).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
                .frame(minHeight: 180)
            }

            if let error = model.objectiveLinkError {
                Text("\(language.text("The objective could not be linked:", "Tujuan tidak dapat ditautkan:")) \(error)")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button(language.text("Cancel", "Batal")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(language.text("Link Objective", "Tautkan Tujuan")) {
                    guard let objectiveID = model.objectiveIDToLink else { return }
                    model.objectiveLinkError = nil
                    do {
                        try model.linkExistingObjective(id: objectiveID)
                        dismiss()
                    } catch {
                        model.objectiveLinkError = error.localizedDescription
                    }
                }
                .disabled(model.objectiveIDToLink == nil || model.objectivesAvailableToLink.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 320)
        .environment(\.locale, language.locale)
        .onAppear {
            model.objectiveIDToLink = nil
            model.objectiveLinkError = nil
            model.load()
        }
    }
}

@MainActor
private struct ObjectiveLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss
    let language: InterfaceLanguage
    @ObservedObject var model: PlanListModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(language.text("Objectives", "Tujuan"))
                    .font(.title2)
                    .bold()
                Spacer()
                Button(language.text("New Objective", "Tujuan Baru")) { model.isCreatingObjective = true }
                    .disabled(model.objectiveLibraryError != nil)
            }

            if let error = model.objectiveLibraryError {
                ContentUnavailableView(
                    language.text("Objectives Could Not Be Loaded", "Tujuan Tidak Dapat Dimuat"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
                Button(language.text("Try Again", "Coba Lagi")) { model.loadObjectives() }
            } else if model.objectives.isEmpty {
                ContentUnavailableView(
                    language.text("No Objectives Yet", "Belum Ada Tujuan"),
                    systemImage: "scope",
                    description: Text(language.text(
                        "Create an objective, then link it to one or more plans.",
                        "Buat tujuan, lalu tautkan ke satu atau beberapa rencana."
                    ))
                )
            } else {
                List(model.objectives) { objective in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(objective.title).font(.headline)
                            if let details = objective.details {
                                Text(details).foregroundStyle(.secondary)
                            }
                            let linkCount = model.objectivePlanCounts[objective.id, default: 0]
                            Text(linkCount == 0
                                ? language.text("Not linked to a plan", "Belum tertaut ke rencana")
                                : language.text("Linked to \(linkCount) plans", "Tertaut ke \(linkCount) rencana"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(language.text("Edit", "Ubah")) { model.objectiveToEdit = objective }
                            .buttonStyle(.borderless)
                        if model.objectivePlanCounts[objective.id, default: 0] == 0 {
                            Button(language.text("Delete", "Hapus"), role: .destructive) {
                                model.objectiveToDelete = objective
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let operationError = model.objectiveOperationError {
                Text(operationError)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button(language.text("Done", "Selesai")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 380)
        .environment(\.locale, language.locale)
        .sheet(isPresented: $model.isCreatingObjective) {
            ObjectiveLibraryForm(language: language, model: model, objective: nil)
        }
        .sheet(item: $model.objectiveToEdit) { objective in
            ObjectiveLibraryForm(language: language, model: model, objective: objective)
        }
        .confirmationDialog(
            language.text("Delete Objective?", "Hapus Tujuan?"),
            isPresented: Binding(
                get: { model.objectiveToDelete != nil },
                set: { if !$0 { model.objectiveToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(language.text("Delete Objective", "Hapus Tujuan"), role: .destructive) {
                guard let objective = model.objectiveToDelete else { return }
                do {
                    try model.deleteObjective(id: objective.id)
                    model.objectiveToDelete = nil
                    model.objectiveOperationError = nil
                } catch {
                    model.objectiveOperationError = "\(language.text("The objective could not be deleted:", "Tujuan tidak dapat dihapus:")) \(error.localizedDescription)"
                    model.objectiveToDelete = nil
                    model.loadObjectives()
                }
            }
            Button(language.text("Cancel", "Batal"), role: .cancel) { model.objectiveToDelete = nil }
        } message: {
            Text(language.text(
                "Only objectives that are not linked to any plan can be deleted.",
                "Hanya tujuan yang tidak tertaut ke rencana mana pun yang dapat dihapus."
            ))
        }
    }
}

@MainActor
private final class ObjectiveLibraryFormModel: ObservableObject {
    @Published var title: String
    @Published var details: String
    @Published var error: String?
    let language: InterfaceLanguage
    let model: PlanListModel
    let objective: Objective?

    init(language: InterfaceLanguage, model: PlanListModel, objective: Objective?) {
        self.language = language
        self.model = model
        self.objective = objective
        title = objective?.title ?? ""
        details = objective?.details ?? ""
    }

    func save() -> Bool {
        error = nil
        do {
            if let objective {
                try model.updateObjective(id: objective.id, title: title, details: details)
            } else {
                try model.createObjective(title: title, details: details)
            }
            return true
        } catch let validationError as PlanningValidationError {
            error = validationError == .emptyTitle
                ? language.text("Enter a title for the objective.", "Masukkan judul tujuan.")
                : validationError.localizedDescription
        } catch let saveError {
            error = "\(language.text("The objective could not be saved:", "Tujuan tidak dapat disimpan:")) \(saveError.localizedDescription)"
        }
        return false
    }
}

@MainActor
private struct ObjectiveLibraryForm: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var form: ObjectiveLibraryFormModel

    init(language: InterfaceLanguage, model: PlanListModel, objective: Objective?) {
        _form = StateObject(wrappedValue: ObjectiveLibraryFormModel(
            language: language,
            model: model,
            objective: objective
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(form.objective == nil
                ? form.language.text("New Objective", "Tujuan Baru")
                : form.language.text("Edit Objective", "Ubah Tujuan"))
                .font(.title2)
                .bold()
            Text(form.language.text(
                "Changes update the same objective everywhere it is linked.",
                "Perubahan memperbarui tujuan yang sama di semua rencana yang tertaut."
            ))
            .foregroundStyle(.secondary)
            Form {
                TextField(form.language.text("Title", "Judul"), text: $form.title)
                TextField(form.language.text("Details (optional)", "Rincian (opsional)"), text: $form.details, axis: .vertical)
                if let error = form.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            }
            HStack {
                Spacer()
                Button(form.language.text("Cancel", "Batal")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(form.language.text("Save", "Simpan")) {
                    if form.save() { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 270)
        .environment(\.locale, form.language.locale)
    }
}

@MainActor
private final class ScheduleCreationForm: ObservableObject {
    let language: InterfaceLanguage
    let activity: Activity
    let model: PlanDetailModel
    @Published var date = Calendar(identifier: .gregorian).startOfDay(for: .now)
    @Published var includesTime = false
    @Published var start = Calendar(identifier: .gregorian).date(from: DateComponents(hour: 9)) ?? .now
    @Published var end = Calendar(identifier: .gregorian).date(from: DateComponents(hour: 10)) ?? .now
    @Published var error: String?

    init(language: InterfaceLanguage, activity: Activity, model: PlanDetailModel) {
        self.language = language
        self.activity = activity
        self.model = model
    }

    func save() -> Bool {
        error = nil
        do {
            let occurrence = try ScheduleOccurrence(
                activityID: activity.id,
                scheduledDate: Self.isoDate(date),
                startTime: includesTime ? Self.isoTime(start) : nil,
                endTime: includesTime ? Self.isoTime(end) : nil
            )
            try model.schedule(occurrence)
            return true
        } catch let validationError as PlanningValidationError {
            switch validationError {
            case .invalidDate:
                error = language.text("Choose a valid calendar date.", "Pilih tanggal kalender yang valid.")
            case .invalidTime:
                error = language.text("Choose a valid time.", "Pilih waktu yang valid.")
            case .incompleteTimeRange:
                error = language.text("Enter both start and end times.", "Masukkan waktu mulai dan selesai.")
            case .invalidTimeRange:
                error = language.text(
                    "The end time must be later than the start time.",
                    "Waktu selesai harus setelah waktu mulai."
                )
            case .emptyTitle, .invalidDateRange, .invalidExecutionTimestamp:
                error = language.text("The schedule details are invalid.", "Rincian jadwal tidak valid.")
            }
        } catch let saveError {
            error = "\(language.text("The schedule could not be saved:", "Jadwal tidak dapat disimpan:")) \(saveError.localizedDescription)"
        }
        return false
    }

    private static func isoDate(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", locale: Locale(identifier: "en_US_POSIX"), c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func isoTime(_ date: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", locale: Locale(identifier: "en_US_POSIX"), c.hour ?? 0, c.minute ?? 0)
    }
}

@MainActor
private struct ScheduleOccurrenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var form: ScheduleCreationForm

    init(language: InterfaceLanguage, activity: Activity, model: PlanDetailModel) {
        _form = StateObject(wrappedValue: ScheduleCreationForm(language: language, activity: activity, model: model))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(form.language.text("Schedule Activity", "Jadwalkan Kegiatan")).font(.title2).bold()
            Text(form.activity.title).foregroundStyle(.secondary)
            Form {
                DatePicker(form.language.text("Date", "Tanggal"), selection: $form.date, displayedComponents: .date)
                Toggle(form.language.text("Set a time", "Atur waktu"), isOn: $form.includesTime)
                if form.includesTime {
                    DatePicker(form.language.text("Start", "Mulai"), selection: $form.start, displayedComponents: .hourAndMinute)
                    DatePicker(form.language.text("End", "Selesai"), selection: $form.end, displayedComponents: .hourAndMinute)
                }
                if let error = form.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
            }
            HStack {
                Spacer()
                Button(form.language.text("Cancel", "Batal")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(form.language.text("Save Schedule", "Simpan Jadwal")) {
                    if form.save() { dismiss() }
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: form.includesTime ? 340 : 260)
        .environment(\.locale, form.language.locale)
        .environment(\.calendar, Calendar(identifier: .gregorian))
    }

}

@MainActor
private struct CreatePlanSheet: View {
    @Environment(\.dismiss) private var dismiss

    let language: InterfaceLanguage
    @ObservedObject var model: PlanListModel

    private var startDateText: String { Self.isoDate(model.newPlanStartDate) }
    private var endDateText: String { Self.isoDate(model.newPlanEndDate) }
    private var hasValidDateRange: Bool { startDateText <= endDateText }
    private var invalidDateRangeMessage: String {
        language.text(
            "The end date must not be before the start date.",
            "Tanggal selesai tidak boleh sebelum tanggal mulai."
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language.text("New Plan", "Rencana Baru"))
                .font(.title2)
                .bold()

            Form {
                TextField(language.text("Title", "Judul"), text: $model.newPlanTitle)
                DatePicker(
                    language.text("Start date", "Tanggal mulai"),
                    selection: $model.newPlanStartDate,
                    displayedComponents: .date
                )
                DatePicker(
                    language.text("End date", "Tanggal selesai"),
                    selection: $model.newPlanEndDate,
                    displayedComponents: .date
                )

                if !hasValidDateRange {
                    Text(invalidDateRangeMessage)
                    .foregroundStyle(.red)
                }

                if let createError = model.createError {
                    Text(createError)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            HStack {
                Spacer()
                Button(language.text("Cancel", "Batal")) {
                    model.isShowingCreateSheet = false
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(language.text("Create Plan", "Buat Rencana")) {
                    createPlan()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 300)
        .environment(\.locale, language.locale)
        .environment(\.calendar, Calendar(identifier: .gregorian))
    }

    private func createPlan() {
        model.createError = nil

        do {
            let plan = try Plan(title: model.newPlanTitle, startDate: startDateText, endDate: endDateText)
            try model.create(plan)
            model.isShowingCreateSheet = false
            dismiss()
        } catch let validationError as PlanningValidationError {
            if case .invalidDateRange = validationError {
                // The date-range warning is already visible beside the controls.
            } else {
                model.createError = validationMessage(for: validationError)
            }
        } catch {
            model.createError = "\(language.text("The plan could not be saved:", "Rencana tidak dapat disimpan:")) \(error.localizedDescription)"
        }
    }

    private func validationMessage(for error: PlanningValidationError) -> String {
        switch error {
        case .emptyTitle:
            language.text("Enter a title for the plan.", "Masukkan judul rencana.")
        case .invalidDate:
            language.text("Enter valid start and end dates.", "Masukkan tanggal mulai dan selesai yang valid.")
        case .invalidDateRange:
            invalidDateRangeMessage
        case .invalidTime, .incompleteTimeRange, .invalidTimeRange, .invalidExecutionTimestamp:
            language.text("The plan contains invalid date or time values.", "Rencana berisi tanggal atau waktu yang tidak valid.")
        }
    }

    private static func isoDate(_ date: Date) -> String {
        let components = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            locale: Locale(identifier: "en_US_POSIX"),
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

@MainActor
struct LanguageSettingsView: View {
    @AppStorage("minority.interface-language") private var languageRawValue = InterfaceLanguage.english.rawValue

    private var language: InterfaceLanguage {
        InterfaceLanguage(rawValue: languageRawValue) ?? .english
    }

    var body: some View {
        Form {
            Picker(language.text("Interface language", "Bahasa antarmuka"), selection: $languageRawValue) {
                ForEach(InterfaceLanguage.allCases, id: \.rawValue) { option in
                    Text(option.name).tag(option.rawValue)
                }
            }
        }
        .padding(24)
        .frame(width: 420)
        .environment(\.locale, language.locale)
    }
}

@MainActor
struct DatabaseUnavailableView: View {
    @AppStorage("minority.interface-language") private var languageRawValue = InterfaceLanguage.english.rawValue

    let error: String?

    private var language: InterfaceLanguage {
        InterfaceLanguage(rawValue: languageRawValue) ?? .english
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Minority")
                .font(.largeTitle)
            Text(language.text("Database Unavailable", "Basis Data Tidak Tersedia"))
                .font(.title2)
            Text(language.text(
                "The local database could not be opened. Your existing data has not been reset.",
                "Basis data lokal tidak dapat dibuka. Data yang ada tidak direset."
            ))
            .foregroundStyle(.secondary)
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .environment(\.locale, language.locale)
    }
}
