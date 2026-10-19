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
    @Published private(set) var plans: [Plan] = []
    @Published private(set) var isLoading = true
    @Published private(set) var loadError: String?
    @Published var isShowingCreateSheet = false
    @Published var newPlanTitle = ""
    @Published var newPlanStartDate = Calendar(identifier: .gregorian).startOfDay(for: .now)
    @Published var newPlanEndDate = Calendar(identifier: .gregorian).startOfDay(for: .now)
    @Published var createError: String?

    init(databaseManager: DatabaseManager) {
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
            .navigationTitle(language.text("Plans", "Rencana"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        model.beginPlanCreation()
                    } label: {
                        Label(language.text("New Plan", "Rencana Baru"), systemImage: "plus")
                    }
                    .help(language.text("Create a plan", "Buat rencana"))
                    .disabled(model.isLoading || model.loadError != nil)
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
        case .invalidTime, .incompleteTimeRange, .invalidTimeRange:
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
