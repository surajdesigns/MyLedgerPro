// MARK: - Models.swift
// MyLedgerPro – Core SwiftData Models
// Swift 6 | SwiftData | iOS 17+

import Foundation
import SwiftData
import SwiftUI

// MARK: - Person Model

@Model
final class Person {
    var id: UUID
    var name: String
    var phone: String
    var email: String
    var address: String
    var notes: String
    var category: PersonCategory
    var photoData: Data?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var isDeleted: Bool
    var deletedAt: Date?
    var trustScore: Double  // 0-100
    
    @Relationship(deleteRule: .cascade, inverse: \Transaction.person)
    var transactions: [Transaction] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Reminder.person)
    var reminders: [Reminder] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        phone: String = "",
        email: String = "",
        address: String = "",
        notes: String = "",
        category: PersonCategory = .friend,
        photoData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.address = address
        self.notes = notes
        self.category = category
        self.photoData = photoData
        self.createdAt = .now
        self.updatedAt = .now
        self.isArchived = false
        self.isDeleted = false
        self.trustScore = 50.0
    }
    
    // MARK: Computed Properties
    
    var totalGiven: Double {
        transactions.filter { $0.type == .given && !$0.isDeleted }.reduce(0) { $0 + $1.amount }
    }
    
    var totalBorrowed: Double {
        transactions.filter { $0.type == .borrowed && !$0.isDeleted }.reduce(0) { $0 + $1.amount }
    }
    
    var totalReceived: Double {
        transactions.filter { $0.type == .received && !$0.isDeleted }.reduce(0) { $0 + $1.amount }
    }
    
    var netBalance: Double {
        // Positive = they owe me, Negative = I owe them
        totalGiven - totalReceived + totalBorrowed
    }
    
    var pendingAmount: Double {
        transactions
            .filter { !$0.isDeleted && $0.status != .paid }
            .reduce(0) { $0 + $1.pendingAmount }
    }
    
    var recoveryPercentage: Double {
        guard totalGiven > 0 else { return 0 }
        return min((totalReceived / totalGiven) * 100, 100)
    }
    
    var lastTransactionDate: Date? {
        transactions.filter { !$0.isDeleted }.map { $0.date }.max()
    }
    
    var hasOverdueTransactions: Bool {
        transactions.contains { !$0.isDeleted && $0.status == .overdue }
    }
    
    var activeTransactionCount: Int {
        transactions.filter { !$0.isDeleted && $0.status != .paid }.count
    }
    
    var categoryColor: Color {
        category.color
    }
    
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Transaction Model

@Model
final class Transaction {
    var id: UUID
    var type: TransactionType
    var amount: Double
    var date: Date
    var dueDate: Date?
    var reminderDate: Date?
    var paymentMethod: PaymentMethod
    var status: TransactionStatus
    var notes: String
    var tags: [String]
    var receiptImageData: Data?
    var billImageData: Data?
    var voiceNoteData: Data?
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    var isArchived: Bool
    var isDeleted: Bool
    var deletedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    
    var person: Person?
    
    @Relationship(deleteRule: .cascade, inverse: \PartialPayment.transaction)
    var partialPayments: [PartialPayment] = []
    
    init(
        id: UUID = UUID(),
        type: TransactionType,
        amount: Double,
        date: Date = .now,
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        paymentMethod: PaymentMethod = .cash,
        notes: String = "",
        tags: [String] = []
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.date = date
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.paymentMethod = paymentMethod
        self.status = .pending
        self.notes = notes
        self.tags = tags
        self.isArchived = false
        self.isDeleted = false
        self.createdAt = .now
        self.updatedAt = .now
    }
    
    // MARK: Computed
    
    var totalPaid: Double {
        partialPayments.filter { !$0.isDeleted }.reduce(0) { $0 + $1.amount }
    }
    
    var pendingAmount: Double {
        max(amount - totalPaid, 0)
    }
    
    var isOverdue: Bool {
        guard let due = dueDate, status != .paid else { return false }
        return due < .now
    }
    
    var overdueByDays: Int {
        guard let due = dueDate, isOverdue else { return 0 }
        return Calendar.current.dateComponents([.day], from: due, to: .now).day ?? 0
    }
}

// MARK: - Partial Payment Model

@Model
final class PartialPayment {
    var id: UUID
    var amount: Double
    var date: Date
    var paymentMethod: PaymentMethod
    var notes: String
    var receiptData: Data?
    var isDeleted: Bool
    var createdAt: Date
    
    var transaction: Transaction?
    
    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date = .now,
        paymentMethod: PaymentMethod = .cash,
        notes: String = ""
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.isDeleted = false
        self.createdAt = .now
    }
}

// MARK: - Reminder Model

@Model
final class Reminder {
    var id: UUID
    var title: String
    var notes: String
    var amount: Double
    var dueDate: Date
    var repeatSchedule: RepeatSchedule
    var reminderType: ReminderType
    var isCompleted: Bool
    var isDeleted: Bool
    var createdAt: Date
    var notificationIDs: [String]
    
    var person: Person?
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        amount: Double = 0,
        dueDate: Date,
        repeatSchedule: RepeatSchedule = .none,
        reminderType: ReminderType = .paymentDue
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.amount = amount
        self.dueDate = dueDate
        self.repeatSchedule = repeatSchedule
        self.reminderType = reminderType
        self.isCompleted = false
        self.isDeleted = false
        self.createdAt = .now
        self.notificationIDs = []
    }
    
    var isOverdue: Bool {
        !isCompleted && dueDate < .now
    }
}

// MARK: - AppSettings Model

@Model
final class AppSettings {
    var id: UUID
    var currency: String
    var currencySymbol: String
    var appearanceMode: AppearanceMode
    var isFaceIDEnabled: Bool
    var isPasscodeEnabled: Bool
    var passcodeHash: String
    var isNotificationsEnabled: Bool
    var isCloudBackupEnabled: Bool
    var isSoundEnabled: Bool
    var isHapticsEnabled: Bool
    var defaultPaymentMethod: PaymentMethod
    var fontSize: FontSizeOption
    var animationSpeed: AnimationSpeed
    var lastBackupDate: Date?
    var isFirstLaunch: Bool
    
    init() {
        self.id = UUID()
        self.currency = "INR"
        self.currencySymbol = "₹"
        self.appearanceMode = .auto
        self.isFaceIDEnabled = true
        self.isPasscodeEnabled = false
        self.passcodeHash = ""
        self.isNotificationsEnabled = true
        self.isCloudBackupEnabled = true
        self.isSoundEnabled = true
        self.isHapticsEnabled = true
        self.defaultPaymentMethod = .cash
        self.fontSize = .medium
        self.animationSpeed = .normal
        self.isFirstLaunch = true
    }
}

// MARK: - Enums

enum PersonCategory: String, Codable, CaseIterable {
    case family = "Family"
    case friend = "Friend"
    case business = "Business"
    case employee = "Employee"
    
    var color: Color {
        switch self {
        case .family:   return .blue
        case .friend:   return .green
        case .business: return .orange
        case .employee: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .family:   return "house.fill"
        case .friend:   return "person.2.fill"
        case .business: return "briefcase.fill"
        case .employee: return "person.badge.clock.fill"
        }
    }
}

enum TransactionType: String, Codable, CaseIterable {
    case given    = "Given"
    case borrowed = "Borrowed"
    case received = "Received"
    
    var color: Color {
        switch self {
        case .given:    return .red
        case .borrowed: return .orange
        case .received: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .given:    return "arrow.up.circle.fill"
        case .borrowed: return "arrow.down.circle.fill"
        case .received: return "checkmark.circle.fill"
        }
    }
    
    var displayText: String { rawValue }
}

enum TransactionStatus: String, Codable, CaseIterable {
    case paid    = "Paid"
    case pending = "Pending"
    case overdue = "Overdue"
    
    var color: Color {
        switch self {
        case .paid:    return .green
        case .pending: return .orange
        case .overdue: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .paid:    return "checkmark.seal.fill"
        case .pending: return "clock.fill"
        case .overdue: return "exclamationmark.triangle.fill"
        }
    }
}

enum PaymentMethod: String, Codable, CaseIterable {
    case cash  = "Cash"
    case upi   = "UPI"
    case bank  = "Bank Transfer"
    case card  = "Card"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .cash:  return "banknote.fill"
        case .upi:   return "qrcode"
        case .bank:  return "building.columns.fill"
        case .card:  return "creditcard.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum RepeatSchedule: String, Codable, CaseIterable {
    case none    = "None"
    case daily   = "Daily"
    case weekly  = "Weekly"
    case monthly = "Monthly"
    case yearly  = "Yearly"
    case custom  = "Custom"
}

enum ReminderType: String, Codable, CaseIterable {
    case paymentDue        = "Payment Due"
    case paymentCollection = "Payment Collection"
    case overdue           = "Overdue"
    case general           = "General"
}

enum AppearanceMode: String, Codable, CaseIterable {
    case light = "Light"
    case dark  = "Dark"
    case auto  = "Auto"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark:  return .dark
        case .auto:  return nil
        }
    }
}

enum FontSizeOption: String, Codable, CaseIterable {
    case small  = "Small"
    case medium = "Medium"
    case large  = "Large"
    
    var scale: Double {
        switch self {
        case .small:  return 0.9
        case .medium: return 1.0
        case .large:  return 1.15
        }
    }
}

enum AnimationSpeed: String, Codable, CaseIterable {
    case slow   = "Slow"
    case normal = "Normal"
    case fast   = "Fast"
    case none   = "None"
}
