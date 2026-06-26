// MARK: - SiriShortcuts.swift
// MyLedgerPro – App Intents & Siri Shortcuts
// Requires: AppIntents framework (iOS 16+)

import AppIntents
import SwiftData
import SwiftUI

// MARK: - Quick Add Transaction Intent

struct AddTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Transaction"
    static var description = IntentDescription("Quickly record money given or received.")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Person Name", description: "Who is this transaction with?")
    var personName: String
    
    @Parameter(title: "Amount", description: "Transaction amount in rupees")
    var amount: Double
    
    @Parameter(title: "Type", description: "Given or Received?")
    var transactionType: TransactionTypeEnum
    
    @Parameter(title: "Notes", description: "Optional notes", default: "")
    var notes: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$transactionType) \(\.$amount) with \(\.$personName)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // In production: use App Group SwiftData container
        let dialog = IntentDialog(
            "Recorded \(transactionType.rawValue == "given" ? "giving" : "receiving") ₹\(Int(amount)) \(transactionType.rawValue == "given" ? "to" : "from") \(personName)."
        )
        return .result(dialog: dialog)
    }
}

enum TransactionTypeEnum: String, AppEnum {
    case given    = "given"
    case received = "received"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Transaction Type"
    static var caseDisplayRepresentations: [TransactionTypeEnum: DisplayRepresentation] = [
        .given:    DisplayRepresentation(title: "Given"),
        .received: DisplayRepresentation(title: "Received")
    ]
}

// MARK: - Check Balance Intent

struct CheckBalanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Pending Balance"
    static var description = IntentDescription("Get your total pending balance.")
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.myledgerpro.shared")
        let pending = defaults?.double(forKey: "totalPending") ?? 0
        let overdue = defaults?.integer(forKey: "overdueCount") ?? 0
        let symbol  = defaults?.string(forKey: "currencySymbol") ?? "₹"
        
        var message = "Your total pending balance is \(symbol)\(Int(pending))."
        if overdue > 0 {
            message += " You have \(overdue) overdue payment(s)."
        }
        
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

// MARK: - Check Person Balance Intent

struct CheckPersonBalanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Person Balance"
    static var description = IntentDescription("Check how much a specific person owes you.")
    
    @Parameter(title: "Person Name")
    var personName: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Check balance for \(\.$personName)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // In production: query SwiftData through App Group
        let message = "Checking balance for \(personName). Please open the app for detailed information."
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

// MARK: - Open Dashboard Intent

struct OpenDashboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Dashboard"
    static var description = IntentDescription("Open My Ledger Pro dashboard.")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Deep link handling in SceneDelegate / onOpenURL
        return .result()
    }
}

// MARK: - Add Reminder Intent

struct AddReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Reminder"
    static var description = IntentDescription("Set a payment reminder.")
    
    @Parameter(title: "Person Name")
    var personName: String
    
    @Parameter(title: "Amount")
    var amount: Double
    
    @Parameter(title: "Days from Now", default: 7)
    var daysFromNow: Int
    
    static var parameterSummary: some ParameterSummary {
        Summary("Remind me about ₹\(\.$amount) from \(\.$personName) in \(\.$daysFromNow) days")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dueDate = Calendar.current.date(byAdding: .day, value: daysFromNow, to: .now) ?? .now
        
        // Schedule notification
        let content = UNMutableNotificationContent()
        content.title = "💰 Payment Reminder"
        content.body = "Collect ₹\(Int(amount)) from \(personName)"
        content.sound = .default
        
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: dueDate)
        
        return .result(dialog: "Reminder set for ₹\(Int(amount)) from \(personName) on \(dateStr).")
    }
}

// MARK: - App Shortcuts Provider

struct LedgerProShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckBalanceIntent(),
            phrases: [
                "Check my pending balance in \(.applicationName)",
                "How much is pending in \(.applicationName)",
                "Show my balance in \(.applicationName)"
            ],
            shortTitle: "Pending Balance",
            systemImageName: "indianrupeesign.circle.fill"
        )
        
        AppShortcut(
            intent: AddTransactionIntent(),
            phrases: [
                "Add transaction in \(.applicationName)",
                "Record payment in \(.applicationName)",
                "Add money given in \(.applicationName)"
            ],
            shortTitle: "Add Transaction",
            systemImageName: "plus.circle.fill"
        )
        
        AppShortcut(
            intent: OpenDashboardIntent(),
            phrases: [
                "Open \(.applicationName) dashboard",
                "Show \(.applicationName)",
                "Open my ledger"
            ],
            shortTitle: "Open Dashboard",
            systemImageName: "chart.bar.fill"
        )
        
        AppShortcut(
            intent: AddReminderIntent(),
            phrases: [
                "Set payment reminder in \(.applicationName)",
                "Remind me about payment in \(.applicationName)"
            ],
            shortTitle: "Add Reminder",
            systemImageName: "bell.fill"
        )
    }
}

// MARK: - Deep Link Handler

struct DeepLinkHandler {
    static func handle(url: URL) -> AppTab? {
        guard url.scheme == "myledgerpro" else { return nil }
        
        switch url.host {
        case "dashboard":   return .dashboard
        case "people":      return .people
        case "transactions":return .transactions
        case "reminders":   return .reminders
        case "reports":     return .reports
        case "analytics":   return .analytics
        case "search":      return .search
        case "archive":     return .archive
        case "ai":          return .ai
        case "settings":    return .settings
        default:            return .dashboard
        }
    }
}

// MARK: - Notification Action Handler

class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationActionHandler()
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let reminderID = userInfo["reminderID"] as? String {
            // Post notification to handle in app
            NotificationCenter.default.post(
                name: .didReceiveReminderNotification,
                object: nil,
                userInfo: ["reminderID": reminderID]
            )
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}

extension Notification.Name {
    static let didReceiveReminderNotification = Notification.Name("didReceiveReminderNotification")
}
