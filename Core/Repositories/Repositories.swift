// MARK: - Repository.swift
// MyLedgerPro – Repository Layer
// Swift 6 | SwiftData

import Foundation
import SwiftData
import SwiftUI

// MARK: - Person Repository

@MainActor
final class PersonRepository: ObservableObject {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func fetchAll(includeArchived: Bool = false) throws -> [Person] {
        var descriptor = FetchDescriptor<Person>(
            predicate: #Predicate { person in
                !person.isDeleted && (includeArchived || !person.isArchived)
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    func fetch(by id: UUID) throws -> Person? {
        let descriptor = FetchDescriptor<Person>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    func search(query: String) throws -> [Person] {
        let lower = query.lowercased()
        let descriptor = FetchDescriptor<Person>(
            predicate: #Predicate { person in
                !person.isDeleted &&
                (person.name.localizedStandardContains(lower) ||
                 person.phone.localizedStandardContains(lower) ||
                 person.notes.localizedStandardContains(lower))
            },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }
    
    func fetch(byCategory category: PersonCategory) throws -> [Person] {
        let catRaw = category.rawValue
        let descriptor = FetchDescriptor<Person>(
            predicate: #Predicate { person in
                !person.isDeleted && person.category.rawValue == catRaw
            },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }
    
    func save(_ person: Person) throws {
        context.insert(person)
        try context.save()
    }
    
    func update(_ person: Person) throws {
        person.updatedAt = .now
        try context.save()
    }
    
    func archive(_ person: Person) throws {
        person.isArchived = true
        person.updatedAt = .now
        try context.save()
    }
    
    func delete(_ person: Person, soft: Bool = true) throws {
        if soft {
            person.isDeleted = true
            person.deletedAt = .now
            person.updatedAt = .now
            try context.save()
        } else {
            context.delete(person)
            try context.save()
        }
    }
    
    func restore(_ person: Person) throws {
        person.isDeleted = false
        person.isArchived = false
        person.deletedAt = nil
        person.updatedAt = .now
        try context.save()
    }
    
    func fetchDeleted() throws -> [Person] {
        let descriptor = FetchDescriptor<Person>(
            predicate: #Predicate { $0.isDeleted },
            sortBy: [SortDescriptor(\.deletedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    // MARK: Stats
    
    func totalNetBalance() throws -> Double {
        let people = try fetchAll()
        return people.reduce(0) { $0 + $1.netBalance }
    }
    
    func totalGiven() throws -> Double {
        let people = try fetchAll()
        return people.reduce(0) { $0 + $1.totalGiven }
    }
    
    func totalReceived() throws -> Double {
        let people = try fetchAll()
        return people.reduce(0) { $0 + $1.totalReceived }
    }
}

// MARK: - Transaction Repository

@MainActor
final class TransactionRepository: ObservableObject {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func fetchAll(includeDeleted: Bool = false) throws -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { tx in
                includeDeleted || !tx.isDeleted
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    func fetch(for person: Person) throws -> [Transaction] {
        let pid = person.id
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { tx in
                !tx.isDeleted && tx.person?.id == pid
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    func fetchPending() throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { tx in
                !tx.isDeleted && tx.status.rawValue == "Pending"
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        return try context.fetch(descriptor)
    }
    
    func fetchOverdue() throws -> [Transaction] {
        let now = Date.now
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { tx in
                !tx.isDeleted &&
                tx.status.rawValue != "Paid" &&
                tx.dueDate != nil &&
                (tx.dueDate ?? now) < now
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        return try context.fetch(descriptor)
    }
    
    func fetchRecent(limit: Int = 10) throws -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { !$0.isDeleted },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
    
    func fetch(from startDate: Date, to endDate: Date) throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { tx in
                !tx.isDeleted && tx.date >= startDate && tx.date <= endDate
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    func search(query: String) throws -> [Transaction] {
        let lower = query.lowercased()
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { tx in
                !tx.isDeleted &&
                (tx.notes.localizedStandardContains(lower) ||
                 tx.person?.name.localizedStandardContains(lower) == true)
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    func save(_ transaction: Transaction) throws {
        context.insert(transaction)
        try context.save()
    }
    
    func update(_ transaction: Transaction) throws {
        transaction.updatedAt = .now
        try context.save()
    }
    
    func delete(_ transaction: Transaction, soft: Bool = true) throws {
        if soft {
            transaction.isDeleted = true
            transaction.deletedAt = .now
            try context.save()
        } else {
            context.delete(transaction)
            try context.save()
        }
    }
    
    func addPartialPayment(_ payment: PartialPayment, to transaction: Transaction) throws {
        payment.transaction = transaction
        transaction.partialPayments.append(payment)
        // Auto-update status
        if transaction.pendingAmount <= 0 {
            transaction.status = .paid
        }
        transaction.updatedAt = .now
        context.insert(payment)
        try context.save()
    }
    
    // MARK: Analytics
    
    func totalGivenThisMonth() throws -> Double {
        let calendar = Calendar.current
        let start = calendar.startOfMonth(for: .now)
        let end = calendar.endOfMonth(for: .now)
        let txs = try fetch(from: start, to: end)
        return txs.filter { $0.type == .given }.reduce(0) { $0 + $1.amount }
    }
    
    func totalReceivedThisMonth() throws -> Double {
        let calendar = Calendar.current
        let start = calendar.startOfMonth(for: .now)
        let end = calendar.endOfMonth(for: .now)
        let txs = try fetch(from: start, to: end)
        return txs.filter { $0.type == .received }.reduce(0) { $0 + $1.amount }
    }
    
    func dailyTotals(for days: Int = 30) throws -> [DayTotal] {
        let calendar = Calendar.current
        let end = Date.now
        guard let start = calendar.date(byAdding: .day, value: -days, to: end) else { return [] }
        let txs = try fetch(from: start, to: end)
        
        var result: [DayTotal] = []
        for day in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: day, to: start) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            
            let dayTxs = txs.filter { $0.date >= dayStart && $0.date < dayEnd }
            let given = dayTxs.filter { $0.type == .given }.reduce(0) { $0 + $1.amount }
            let received = dayTxs.filter { $0.type == .received }.reduce(0) { $0 + $1.amount }
            result.append(DayTotal(date: date, given: given, received: received))
        }
        return result
    }
}

// MARK: - Reminder Repository

@MainActor
final class ReminderRepository: ObservableObject {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func fetchAll() throws -> [Reminder] {
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { !$0.isDeleted },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        return try context.fetch(descriptor)
    }
    
    func fetchUpcoming(limit: Int = 5) throws -> [Reminder] {
        let now = Date.now
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { r in
                !r.isDeleted && !r.isCompleted && r.dueDate >= now
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
    
    func fetchOverdue() throws -> [Reminder] {
        let now = Date.now
        let descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { r in
                !r.isDeleted && !r.isCompleted && r.dueDate < now
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        return try context.fetch(descriptor)
    }
    
    func save(_ reminder: Reminder) throws {
        context.insert(reminder)
        try context.save()
    }
    
    func complete(_ reminder: Reminder) throws {
        reminder.isCompleted = true
        try context.save()
    }
    
    func delete(_ reminder: Reminder) throws {
        reminder.isDeleted = true
        try context.save()
    }
}

// MARK: - Settings Repository

@MainActor
final class SettingsRepository: ObservableObject {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    func get() throws -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let settings = try context.fetch(descriptor).first {
            return settings
        }
        let settings = AppSettings()
        context.insert(settings)
        try context.save()
        return settings
    }
    
    func save(_ settings: AppSettings) throws {
        try context.save()
    }
}

// MARK: - Supporting Types

struct DayTotal: Identifiable {
    let id = UUID()
    let date: Date
    let given: Double
    let received: Double
    
    var net: Double { received - given }
    
    var label: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    func endOfMonth(for date: Date) -> Date {
        guard let start = self.date(from: dateComponents([.year, .month], from: date)),
              let end = self.date(byAdding: DateComponents(month: 1, second: -1), to: start)
        else { return date }
        return end
    }
}
