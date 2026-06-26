// MARK: - BackupManager.swift
// MyLedgerPro – Backup & Restore System

import Foundation
import SwiftData
import SwiftUI

// MARK: - Backup Manager

@MainActor
final class BackupManager: ObservableObject {
    static let shared = BackupManager()

    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var lastBackupDate: Date?
    @Published var backupProgress: Double = 0
    @Published var statusMessage = ""
    @Published var availableBackups: [BackupFile] = []

    private let fileManager = FileManager.default

    // MARK: - iCloud Container URL

    private var iCloudURL: URL? {
        fileManager.url(forUbiquityContainerIdentifier: "iCloud.com.myledgerpro.app")?
            .appendingPathComponent("Documents")
    }

    private var localBackupURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backups")
    }

    // MARK: - Create Backup

    func createBackup(
        people: [Person],
        transactions: [Transaction],
        reminders: [Reminder]
    ) async throws -> URL {
        isBackingUp = true
        backupProgress = 0
        statusMessage = "Preparing backup..."
        defer { isBackingUp = false }

        let backup = BackupData(
            people: people.map { PersonBackup(from: $0) },
            transactions: transactions.map { TransactionBackup(from: $0) },
            reminders: reminders.map { ReminderBackup(from: $0) },
            exportDate: .now,
            appVersion: AppConstants.appVersion
        )

        backupProgress = 0.3
        statusMessage = "Encoding data..."

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        backupProgress = 0.6
        statusMessage = "Saving backup..."

        // Save locally first
        try fileManager.createDirectory(at: localBackupURL, withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter()
        let dateStr = formatter.string(from: .now).replacingOccurrences(of: ":", with: "-")
        let filename = "\(AppConstants.backupFilePrefix)_\(dateStr).json"
        let localURL = localBackupURL.appendingPathComponent(filename)
        try data.write(to: localURL)

        backupProgress = 0.8

        // Try iCloud
        if let cloudURL = iCloudURL {
            try? fileManager.createDirectory(at: cloudURL, withIntermediateDirectories: true)
            let cloudFile = cloudURL.appendingPathComponent(filename)
            try? fileManager.copyItem(at: localURL, to: cloudFile)
            statusMessage = "Saved to iCloud!"
        } else {
            statusMessage = "Saved locally (iCloud unavailable)"
        }

        backupProgress = 1.0
        lastBackupDate = .now
        await loadAvailableBackups()
        return localURL
    }

    // MARK: - Restore Backup

    func restore(from url: URL, context: ModelContext) async throws {
        isRestoring = true
        statusMessage = "Reading backup file..."
        defer { isRestoring = false }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupData.self, from: data)

        statusMessage = "Restoring people..."
        for pb in backup.people {
            let person = pb.toPerson()
            context.insert(person)
        }

        statusMessage = "Restoring transactions..."
        for tb in backup.transactions {
            let tx = tb.toTransaction()
            context.insert(tx)
        }

        statusMessage = "Restoring reminders..."
        for rb in backup.reminders {
            let r = rb.toReminder()
            context.insert(r)
        }

        try context.save()
        statusMessage = "Restore complete!"
    }

    // MARK: - Load Available Backups

    func loadAvailableBackups() async {
        var files: [BackupFile] = []

        // Local
        if let contents = try? fileManager.contentsOfDirectory(
            at: localBackupURL, includingPropertiesForKeys: [.creationDateKey]
        ) {
            for url in contents where url.pathExtension == "json" {
                let attrs = try? fileManager.attributesOfItem(atPath: url.path)
                let date = attrs?[.creationDate] as? Date ?? .now
                let size = attrs?[.size] as? Int ?? 0
                files.append(BackupFile(url: url, date: date, size: size, isCloud: false))
            }
        }

        // iCloud
        if let cloudURL = iCloudURL,
           let contents = try? fileManager.contentsOfDirectory(
               at: cloudURL, includingPropertiesForKeys: [.creationDateKey]
           ) {
            for url in contents where url.pathExtension == "json" {
                let attrs = try? fileManager.attributesOfItem(atPath: url.path)
                let date = attrs?[.creationDate] as? Date ?? .now
                let size = attrs?[.size] as? Int ?? 0
                files.append(BackupFile(url: url, date: date, size: size, isCloud: true))
            }
        }

        availableBackups = files.sorted { $0.date > $1.date }
    }

    // MARK: - Delete Backup

    func deleteBackup(_ file: BackupFile) throws {
        try fileManager.removeItem(at: file.url)
        availableBackups.removeAll { $0.id == file.id }
    }

    // MARK: - Export JSON

    func exportJSON(people: [Person], transactions: [Transaction], reminders: [Reminder]) async throws -> URL {
        let backup = BackupData(
            people: people.map { PersonBackup(from: $0) },
            transactions: transactions.map { TransactionBackup(from: $0) },
            reminders: reminders.map { ReminderBackup(from: $0) },
            exportDate: .now,
            appVersion: AppConstants.appVersion
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let url = fileManager.temporaryDirectory
            .appendingPathComponent("MyLedgerPro_Export_\(Date.now.formatted(.iso8601)).json")
        try data.write(to: url)
        return url
    }
}

// MARK: - Backup File Model

struct BackupFile: Identifiable {
    let id = UUID()
    let url: URL
    let date: Date
    let size: Int
    let isCloud: Bool

    var displayName: String { url.lastPathComponent }
    var sizeFormatted: String {
        let kb = Double(size) / 1024
        if kb < 1024 { return String(format: "%.1f KB", kb) }
        return String(format: "%.1f MB", kb / 1024)
    }
}

// MARK: - Backup Data Codable Models

struct BackupData: Codable {
    let people: [PersonBackup]
    let transactions: [TransactionBackup]
    let reminders: [ReminderBackup]
    let exportDate: Date
    let appVersion: String
}

struct PersonBackup: Codable {
    let id: UUID
    let name: String
    let phone: String
    let email: String
    let address: String
    let notes: String
    let category: String
    let createdAt: Date
    let trustScore: Double

    init(from p: Person) {
        id = p.id; name = p.name; phone = p.phone
        email = p.email; address = p.address; notes = p.notes
        category = p.category.rawValue; createdAt = p.createdAt; trustScore = p.trustScore
    }

    func toPerson() -> Person {
        Person(
            id: id, name: name, phone: phone, email: email,
            address: address, notes: notes,
            category: PersonCategory(rawValue: category) ?? .friend
        )
    }
}

struct TransactionBackup: Codable {
    let id: UUID
    let type: String
    let amount: Double
    let date: Date
    let dueDate: Date?
    let paymentMethod: String
    let status: String
    let notes: String
    let tags: [String]

    init(from tx: Transaction) {
        id = tx.id; type = tx.type.rawValue; amount = tx.amount
        date = tx.date; dueDate = tx.dueDate
        paymentMethod = tx.paymentMethod.rawValue; status = tx.status.rawValue
        notes = tx.notes; tags = tx.tags
    }

    func toTransaction() -> Transaction {
        Transaction(
            id: id,
            type: TransactionType(rawValue: type) ?? .given,
            amount: amount, date: date, dueDate: dueDate,
            paymentMethod: PaymentMethod(rawValue: paymentMethod) ?? .cash,
            notes: notes, tags: tags
        )
    }
}

struct ReminderBackup: Codable {
    let id: UUID
    let title: String
    let notes: String
    let amount: Double
    let dueDate: Date
    let repeatSchedule: String
    let reminderType: String

    init(from r: Reminder) {
        id = r.id; title = r.title; notes = r.notes; amount = r.amount
        dueDate = r.dueDate; repeatSchedule = r.repeatSchedule.rawValue
        reminderType = r.reminderType.rawValue
    }

    func toReminder() -> Reminder {
        Reminder(
            id: id, title: title, notes: notes, amount: amount, dueDate: dueDate,
            repeatSchedule: RepeatSchedule(rawValue: repeatSchedule) ?? .none,
            reminderType: ReminderType(rawValue: reminderType) ?? .general
        )
    }
}
