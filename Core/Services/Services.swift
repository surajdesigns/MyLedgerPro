// MARK: - Services.swift
// MyLedgerPro – Services Layer
// Swift 6 | iOS 17+

import Foundation
import UserNotifications
import LocalAuthentication
import SwiftUI
import AVFoundation
import UIKit

// MARK: - Notification Service

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private init() {}
    
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }
    
    func scheduleReminder(_ reminder: Reminder) -> String {
        let content = UNMutableNotificationContent()
        content.title = reminder.reminderType == .paymentCollection
            ? "💰 Collect Payment"
            : "⏰ Payment Reminder"
        
        if let person = reminder.person {
            content.body = reminder.amount > 0
                ? "\(person.name) – ₹\(reminder.amount.formatted()) due"
                : reminder.title
        } else {
            content.body = reminder.title
        }
        content.sound = .default
        content.badge = 1
        content.userInfo = ["reminderID": reminder.id.uuidString]
        
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.dueDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
        return id
    }
    
    func scheduleOverdueAlert(for transaction: Transaction) {
        guard let person = transaction.person else { return }
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Overdue Payment"
        content.body = "\(person.name) – ₹\(transaction.amount.formatted()) overdue by \(transaction.overdueByDays) day(s)"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("overdue.caf"))
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "overdue-\(transaction.id)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func scheduleDailyReminder(hour: Int = 9, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "📊 My Ledger Pro"
        content.body = "Check your pending payments and reminders."
        content.sound = .default
        
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-reminder",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Security Service

@MainActor
final class SecurityService: ObservableObject {
    static let shared = SecurityService()
    
    @Published var isUnlocked = false
    @Published var isAuthenticating = false
    
    private init() {}
    
    func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fallback to passcode
            return await authenticateWithPasscode(context: context)
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock My Ledger Pro"
            )
            if success {
                await HapticService.shared.success()
                isUnlocked = true
            }
            return success
        } catch {
            return await authenticateWithPasscode(context: context)
        }
    }
    
    private func authenticateWithPasscode(context: LAContext) async -> Bool {
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock My Ledger Pro"
            )
            isUnlocked = success
            return success
        } catch {
            return false
        }
    }
    
    func lock() {
        isUnlocked = false
    }
    
    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }
    
    var biometricIcon: String {
        switch biometricType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "lock.fill"
        }
    }
}

// MARK: - Haptic Service

final class HapticService {
    static let shared = HapticService()
    private init() {}
    
    @MainActor
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    @MainActor
    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    @MainActor
    func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    @MainActor
    func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    @MainActor
    func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Sound Service

final class SoundService {
    static let shared = SoundService()
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func play(_ sound: AppSound) {
        // In production, load actual sound files from bundle
        // Using system sounds as fallback
        AudioServicesPlaySystemSound(sound.systemSoundID)
    }
}

enum AppSound {
    case transactionAdded
    case paymentReceived
    case reminderCompleted
    case backupSuccess
    case faceIDSuccess
    case overdueAlert
    
    var systemSoundID: SystemSoundID {
        switch self {
        case .transactionAdded:  return 1104  // "payment_success" equivalent
        case .paymentReceived:   return 1057
        case .reminderCompleted: return 1025
        case .backupSuccess:     return 1016
        case .faceIDSuccess:     return 1052
        case .overdueAlert:      return 1005
        }
    }
}

import AudioToolbox

// MARK: - Export Service

@MainActor
final class ExportService: ObservableObject {
    static let shared = ExportService()
    
    private init() {}
    
    // MARK: CSV Export
    
    func generateCSV(for person: Person) -> String {
        var csv = "Date,Type,Amount,Method,Status,Notes\n"
        
        let sorted = person.transactions
            .filter { !$0.isDeleted }
            .sorted { $0.date < $1.date }
        
        for tx in sorted {
            let dateStr = tx.date.formatted(date: .abbreviated, time: .omitted)
            let row = "\(dateStr),\(tx.type.rawValue),\(tx.amount),\(tx.paymentMethod.rawValue),\(tx.status.rawValue),\"\(tx.notes)\"\n"
            csv += row
        }
        return csv
    }
    
    func generateFullCSV(transactions: [Transaction]) -> String {
        var csv = "Date,Person,Type,Amount,Method,Status,Notes,Due Date\n"
        for tx in transactions.sorted(by: { $0.date < $1.date }) {
            let dateStr = tx.date.formatted(date: .abbreviated, time: .omitted)
            let dueStr = tx.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? ""
            let person = tx.person?.name ?? "Unknown"
            csv += "\(dateStr),\"\(person)\",\(tx.type.rawValue),\(tx.amount),\(tx.paymentMethod.rawValue),\(tx.status.rawValue),\"\(tx.notes)\",\(dueStr)\n"
        }
        return csv
    }
    
    // MARK: PDF Generation
    
    func generatePDFStatement(for person: Person, currencySymbol: String = "₹") -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        
        return renderer.pdfData { context in
            context.beginPage()
            let ctx = context.cgContext
            
            // Header
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.label
            ]
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.label
            ]
            
            // Title
            NSAttributedString(string: "Account Statement", attributes: titleAttrs)
                .draw(at: CGPoint(x: 40, y: 40))
            NSAttributedString(string: "My Ledger Pro", attributes: subAttrs)
                .draw(at: CGPoint(x: 40, y: 68))
            
            // Person Info
            let personText = "Client: \(person.name)    Phone: \(person.phone)"
            NSAttributedString(string: personText, attributes: subAttrs)
                .draw(at: CGPoint(x: 40, y: 96))
            
            let dateText = "Generated: \(Date.now.formatted(date: .long, time: .shortened))"
            NSAttributedString(string: dateText, attributes: subAttrs)
                .draw(at: CGPoint(x: 40, y: 114))
            
            // Divider
            ctx.setStrokeColor(UIColor.separator.cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: 40, y: 136))
            ctx.addLine(to: CGPoint(x: 555, y: 136))
            ctx.strokePath()
            
            // Column headers
            let headers = ["Date", "Type", "Amount", "Method", "Status"]
            let colX: [CGFloat] = [40, 120, 220, 330, 440]
            for (i, header) in headers.enumerated() {
                NSAttributedString(string: header, attributes: [
                    .font: UIFont.boldSystemFont(ofSize: 11),
                    .foregroundColor: UIColor.secondaryLabel
                ]).draw(at: CGPoint(x: colX[i], y: 146))
            }
            
            // Transactions
            var y: CGFloat = 166
            let transactions = person.transactions.filter { !$0.isDeleted }.sorted { $0.date < $1.date }
            
            for tx in transactions {
                if y > 780 {
                    context.beginPage()
                    y = 40
                }
                let cols = [
                    tx.date.formatted(date: .abbreviated, time: .omitted),
                    tx.type.rawValue,
                    "\(currencySymbol)\(tx.amount.formatted())",
                    tx.paymentMethod.rawValue,
                    tx.status.rawValue
                ]
                for (i, col) in cols.enumerated() {
                    NSAttributedString(string: col, attributes: rowAttrs)
                        .draw(at: CGPoint(x: colX[i], y: y))
                }
                y += 20
                
                // Partial payments
                for pp in tx.partialPayments.filter({ !$0.isDeleted }) {
                    if y > 780 { context.beginPage(); y = 40 }
                    let ppText = "  ↳ Partial: \(currencySymbol)\(pp.amount.formatted()) via \(pp.paymentMethod.rawValue)"
                    NSAttributedString(string: ppText, attributes: [
                        .font: UIFont.italicSystemFont(ofSize: 10),
                        .foregroundColor: UIColor.secondaryLabel
                    ]).draw(at: CGPoint(x: colX[0], y: y))
                    y += 16
                }
            }
            
            // Summary
            y += 20
            ctx.setStrokeColor(UIColor.separator.cgColor)
            ctx.move(to: CGPoint(x: 40, y: y))
            ctx.addLine(to: CGPoint(x: 555, y: y))
            ctx.strokePath()
            y += 10
            
            let summaryAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.label
            ]
            NSAttributedString(string: "Total Given: \(currencySymbol)\(person.totalGiven.formatted())", attributes: summaryAttrs)
                .draw(at: CGPoint(x: 40, y: y))
            NSAttributedString(string: "Total Received: \(currencySymbol)\(person.totalReceived.formatted())", attributes: summaryAttrs)
                .draw(at: CGPoint(x: 220, y: y))
            NSAttributedString(string: "Pending: \(currencySymbol)\(person.pendingAmount.formatted())", attributes: [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: person.pendingAmount > 0 ? UIColor.systemRed : UIColor.systemGreen
            ]).draw(at: CGPoint(x: 400, y: y))
        }
    }
    
    // MARK: Backup
    
    func exportBackup(people: [Person], transactions: [Transaction], reminders: [Reminder]) throws -> Data {
        let backup = BackupData(
            version: 1,
            exportedAt: .now,
            people: people.map { BackupPerson(from: $0) },
            transactions: transactions.map { BackupTransaction(from: $0) },
            reminders: reminders.map { BackupReminder(from: $0) }
        )
        return try JSONEncoder().encode(backup)
    }
    
    func writeToTemp(data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }
}

// MARK: - Backup Data Structures

struct BackupData: Codable {
    let version: Int
    let exportedAt: Date
    let people: [BackupPerson]
    let transactions: [BackupTransaction]
    let reminders: [BackupReminder]
}

struct BackupPerson: Codable {
    let id: UUID; let name: String; let phone: String; let email: String
    let category: String; let notes: String; let createdAt: Date
    
    init(from p: Person) {
        id = p.id; name = p.name; phone = p.phone; email = p.email
        category = p.category.rawValue; notes = p.notes; createdAt = p.createdAt
    }
}

struct BackupTransaction: Codable {
    let id: UUID; let personID: UUID?; let type: String; let amount: Double
    let date: Date; let dueDate: Date?; let status: String
    let notes: String; let paymentMethod: String
    
    init(from t: Transaction) {
        id = t.id; personID = t.person?.id; type = t.type.rawValue
        amount = t.amount; date = t.date; dueDate = t.dueDate
        status = t.status.rawValue; notes = t.notes
        paymentMethod = t.paymentMethod.rawValue
    }
}

struct BackupReminder: Codable {
    let id: UUID; let title: String; let amount: Double
    let dueDate: Date; let isCompleted: Bool; let personID: UUID?
    
    init(from r: Reminder) {
        id = r.id; title = r.title; amount = r.amount
        dueDate = r.dueDate; isCompleted = r.isCompleted; personID = r.person?.id
    }
}

// MARK: - Currency Formatter

struct CurrencyFormatter {
    static func format(_ amount: Double, symbol: String = "₹") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(symbol)\(formatted)"
    }
    
    static func formatCompact(_ amount: Double, symbol: String = "₹") -> String {
        if amount >= 100_000 {
            return "\(symbol)\(String(format: "%.1f", amount / 100_000))L"
        } else if amount >= 1_000 {
            return "\(symbol)\(String(format: "%.1f", amount / 1_000))K"
        }
        return format(amount, symbol: symbol)
    }
}

// MARK: - AI Service

@MainActor
final class AIService: ObservableObject {
    static let shared = AIService()
    
    @Published var isProcessing = false
    @Published var lastResponse = ""
    
    private init() {}
    
    func processQuery(_ query: String, context: AIContext) async -> String {
        isProcessing = true
        defer { isProcessing = false }
        
        // Rule-based AI for offline use; production could integrate OpenAI/local LLM
        let lower = query.lowercased()
        
        if lower.contains("how much") && (lower.contains("owe") || lower.contains("pending")) {
            return generateBalanceSummary(context: context)
        } else if lower.contains("summary") || lower.contains("overview") {
            return generateMonthlySummary(context: context)
        } else if lower.contains("overdue") {
            return generateOverdueReport(context: context)
        } else if lower.contains("top") || lower.contains("biggest") {
            return generateTopDebtors(context: context)
        } else {
            return generateGeneralInsight(context: context)
        }
    }
    
    private func generateBalanceSummary(context: AIContext) -> String {
        let pending = context.totalPending
        let people = context.activePeople
        return """
        💰 Balance Summary
        
        Total Pending: ₹\(pending.formatted())
        Active People: \(people)
        
        You have outstanding amounts from \(people) people. \
        \(context.overdueCount > 0 ? "⚠️ \(context.overdueCount) payment(s) are overdue!" : "✅ No overdue payments.")
        """
    }
    
    private func generateMonthlySummary(context: AIContext) -> String {
        return """
        📊 This Month Summary
        
        Given:     ₹\(context.monthlyGiven.formatted())
        Recovered: ₹\(context.monthlyReceived.formatted())
        Net Flow:  ₹\(abs(context.monthlyGiven - context.monthlyReceived).formatted()) \
        \(context.monthlyGiven > context.monthlyReceived ? "outgoing" : "incoming")
        
        Recovery rate: \(context.monthlyGiven > 0 ? Int((context.monthlyReceived / context.monthlyGiven) * 100) : 100)%
        """
    }
    
    private func generateOverdueReport(context: AIContext) -> String {
        guard context.overdueCount > 0 else {
            return "✅ Great news! You have no overdue payments at the moment."
        }
        return """
        ⚠️ Overdue Payments
        
        Count: \(context.overdueCount)
        Total: ₹\(context.overdueAmount.formatted())
        
        Consider sending reminders or making calls to recover these amounts.
        """
    }
    
    private func generateTopDebtors(context: AIContext) -> String {
        guard !context.topDebtors.isEmpty else {
            return "📭 Everyone is up to date! No pending amounts."
        }
        var result = "🏆 Top Outstanding Balances\n\n"
        for (i, debtor) in context.topDebtors.prefix(5).enumerated() {
            result += "\(i+1). \(debtor.name): ₹\(debtor.pendingAmount.formatted())\n"
        }
        return result
    }
    
    private func generateGeneralInsight(context: AIContext) -> String {
        return """
        📈 Financial Snapshot
        
        Total Given:     ₹\(context.totalGiven.formatted())
        Total Received:  ₹\(context.totalReceived.formatted())
        Net Pending:     ₹\(context.totalPending.formatted())
        
        Active People:   \(context.activePeople)
        Overdue:         \(context.overdueCount)
        
        Overall recovery rate: \(context.totalGiven > 0 ? Int((context.totalReceived / context.totalGiven) * 100) : 100)%
        """
    }
}

struct AIContext {
    var totalGiven: Double = 0
    var totalReceived: Double = 0
    var totalPending: Double = 0
    var monthlyGiven: Double = 0
    var monthlyReceived: Double = 0
    var overdueCount: Int = 0
    var overdueAmount: Double = 0
    var activePeople: Int = 0
    var topDebtors: [Person] = []
}
