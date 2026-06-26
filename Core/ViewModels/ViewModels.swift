// MARK: - ViewModels.swift
// MyLedgerPro – ViewModels
// Swift 6 | SwiftUI | MVVM

import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - App ViewModel (Root)

@MainActor
@Observable
final class AppViewModel {
    var isUnlocked = false
    var isAuthenticating = false
    var selectedTab: AppTab = .dashboard
    var currencySymbol = "₹"
    var appearanceMode: AppearanceMode = .auto
    var isSoundEnabled = true
    var isHapticsEnabled = true
    
    func onAppear() {
        Task { await authenticate() }
    }
    
    func authenticate() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        let success = await SecurityService.shared.authenticate()
        isUnlocked = success
        isAuthenticating = false
        if success && isSoundEnabled {
            SoundService.shared.play(.faceIDSuccess)
        }
    }
}

enum AppTab: String, CaseIterable {
    case dashboard   = "Dashboard"
    case people      = "People"
    case transactions = "Transactions"
    case reminders   = "Reminders"
    case reports     = "Reports"
    case analytics   = "Analytics"
    case search      = "Search"
    case archive     = "Archive"
    case ai          = "AI"
    case settings    = "Settings"
    
    var icon: String {
        switch self {
        case .dashboard:    return "chart.bar.fill"
        case .people:       return "person.2.fill"
        case .transactions: return "arrow.left.arrow.right.circle.fill"
        case .reminders:    return "bell.fill"
        case .reports:      return "doc.text.fill"
        case .analytics:    return "chart.line.uptrend.xyaxis"
        case .search:       return "magnifyingglass"
        case .archive:      return "archivebox.fill"
        case .ai:           return "sparkles"
        case .settings:     return "gearshape.fill"
        }
    }
}

// MARK: - Dashboard ViewModel

@MainActor
@Observable
final class DashboardViewModel {
    var totalGiven: Double = 0
    var totalReceived: Double = 0
    var totalPending: Double = 0
    var overdueAmount: Double = 0
    var thisMonthGiven: Double = 0
    var thisMonthReceived: Double = 0
    var activePeopleCount: Int = 0
    var recentTransactions: [Transaction] = []
    var upcomingReminders: [Reminder] = []
    var overdueTransactions: [Transaction] = []
    var chartData: [DayTotal] = []
    var isLoading = false
    var error: String?
    
    func load(personRepo: PersonRepository, txRepo: TransactionRepository, reminderRepo: ReminderRepository) {
        isLoading = true
        Task {
            do {
                let people = try personRepo.fetchAll()
                activePeopleCount = people.count
                
                totalGiven    = try personRepo.totalGiven()
                totalReceived = try personRepo.totalReceived()
                totalPending  = people.reduce(0) { $0 + $1.pendingAmount }
                
                let overdueTxs = try txRepo.fetchOverdue()
                overdueAmount = overdueTxs.reduce(0) { $0 + $1.pendingAmount }
                overdueTransactions = overdueTxs
                
                thisMonthGiven    = try txRepo.totalGivenThisMonth()
                thisMonthReceived = try txRepo.totalReceivedThisMonth()
                recentTransactions = try txRepo.fetchRecent(limit: 10)
                upcomingReminders = try reminderRepo.fetchUpcoming(limit: 5)
                chartData = try txRepo.dailyTotals(for: 30)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    var netBalance: Double { totalReceived - totalGiven }
    var recoveryRate: Double {
        guard totalGiven > 0 else { return 100 }
        return min((totalReceived / totalGiven) * 100, 100)
    }
}

// MARK: - People ViewModel

@MainActor
@Observable
final class PeopleViewModel {
    var people: [Person] = []
    var selectedCategory: PersonCategory? = nil
    var searchText = ""
    var isLoading = false
    var sortOrder: PersonSortOrder = .name
    var showAddPerson = false
    
    var filtered: [Person] {
        var result = people
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) ||
                $0.phone.lowercased().contains(q)
            }
        }
        switch sortOrder {
        case .name:        result.sort { $0.name < $1.name }
        case .pending:     result.sort { $0.pendingAmount > $1.pendingAmount }
        case .lastActive:  result.sort { ($0.lastTransactionDate ?? .distantPast) > ($1.lastTransactionDate ?? .distantPast) }
        case .trustScore:  result.sort { $0.trustScore > $1.trustScore }
        }
        return result
    }
    
    func load(repo: PersonRepository) {
        isLoading = true
        Task {
            people = (try? repo.fetchAll()) ?? []
            isLoading = false
        }
    }
    
    func delete(_ person: Person, repo: PersonRepository) {
        Task {
            try? repo.delete(person)
            load(repo: repo)
        }
    }
    
    func archive(_ person: Person, repo: PersonRepository) {
        Task {
            try? repo.archive(person)
            load(repo: repo)
        }
    }
}

enum PersonSortOrder: String, CaseIterable {
    case name = "Name"
    case pending = "Pending Amount"
    case lastActive = "Last Active"
    case trustScore = "Trust Score"
}

// MARK: - Transactions ViewModel

@MainActor
@Observable
final class TransactionsViewModel {
    var transactions: [Transaction] = []
    var filterType: TransactionType? = nil
    var filterStatus: TransactionStatus? = nil
    var filterPaymentMethod: PaymentMethod? = nil
    var dateFrom: Date = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    var dateTo: Date = .now
    var searchText = ""
    var isLoading = false
    var showAddTransaction = false
    
    var filtered: [Transaction] {
        var result = transactions
        if let type = filterType { result = result.filter { $0.type == type } }
        if let status = filterStatus { result = result.filter { $0.status == status } }
        if let method = filterPaymentMethod { result = result.filter { $0.paymentMethod == method } }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.notes.lowercased().contains(q) ||
                $0.person?.name.lowercased().contains(q) == true ||
                $0.tags.joined(separator: " ").lowercased().contains(q)
            }
        }
        return result
    }
    
    func load(repo: TransactionRepository) {
        isLoading = true
        Task {
            transactions = (try? repo.fetchAll()) ?? []
            isLoading = false
        }
    }
    
    func delete(_ tx: Transaction, repo: TransactionRepository) {
        Task {
            try? repo.delete(tx)
            load(repo: repo)
        }
    }
    
    func addPartialPayment(_ payment: PartialPayment, to tx: Transaction, repo: TransactionRepository) {
        Task {
            try? repo.addPartialPayment(payment, to: tx)
            load(repo: repo)
            await HapticService.shared.success()
            SoundService.shared.play(.paymentReceived)
        }
    }
}

// MARK: - Add Transaction ViewModel

@MainActor
@Observable
final class AddTransactionViewModel {
    var selectedPerson: Person?
    var type: TransactionType = .given
    var amount: String = ""
    var date: Date = .now
    var dueDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    var hasDueDate = false
    var paymentMethod: PaymentMethod = .cash
    var notes: String = ""
    var tags: String = ""
    var receiptImage: UIImage?
    var billImage: UIImage?
    var hasReminder = false
    var reminderDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    var isLoading = false
    var error: String?
    var didSave = false
    
    var isValid: Bool {
        selectedPerson != nil && (Double(amount) ?? 0) > 0
    }
    
    func save(txRepo: TransactionRepository, reminderRepo: ReminderRepository) {
        guard isValid, let amount = Double(self.amount), let person = selectedPerson else {
            error = "Please select a person and enter a valid amount."
            return
        }
        
        isLoading = true
        Task {
            let tx = Transaction(
                type: type,
                amount: amount,
                date: date,
                dueDate: hasDueDate ? dueDate : nil,
                reminderDate: hasReminder ? reminderDate : nil,
                paymentMethod: paymentMethod,
                notes: notes,
                tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            )
            tx.person = person
            
            if let img = receiptImage, let data = img.jpegData(compressionQuality: 0.7) {
                tx.receiptImageData = data
            }
            if let img = billImage, let data = img.jpegData(compressionQuality: 0.7) {
                tx.billImageData = data
            }
            
            try? txRepo.save(tx)
            
            // Schedule reminder
            if hasReminder {
                let reminder = Reminder(
                    title: "Payment from \(person.name)",
                    amount: amount,
                    dueDate: reminderDate,
                    reminderType: type == .given ? .paymentCollection : .paymentDue
                )
                reminder.person = person
                try? reminderRepo.save(reminder)
                _ = NotificationService.shared.scheduleReminder(reminder)
            }
            
            await HapticService.shared.success()
            SoundService.shared.play(.transactionAdded)
            isLoading = false
            didSave = true
        }
    }
    
    func reset() {
        selectedPerson = nil; type = .given; amount = ""
        date = .now; hasDueDate = false; paymentMethod = .cash
        notes = ""; tags = ""; receiptImage = nil; billImage = nil
        hasReminder = false; error = nil; didSave = false
    }
}

// MARK: - Add Person ViewModel

@MainActor
@Observable
final class AddPersonViewModel {
    var name = ""
    var phone = ""
    var email = ""
    var address = ""
    var notes = ""
    var category: PersonCategory = .friend
    var photo: UIImage?
    var isLoading = false
    var error: String?
    var didSave = false
    
    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    
    func save(repo: PersonRepository) {
        guard isValid else { error = "Name is required."; return }
        isLoading = true
        Task {
            let photoData = photo?.jpegData(compressionQuality: 0.6)
            let person = Person(
                name: name.trimmingCharacters(in: .whitespaces),
                phone: phone, email: email, address: address,
                notes: notes, category: category, photoData: photoData
            )
            try? repo.save(person)
            await HapticService.shared.success()
            isLoading = false
            didSave = true
        }
    }
}

// MARK: - Reminders ViewModel

@MainActor
@Observable
final class RemindersViewModel {
    var upcomingReminders: [Reminder] = []
    var overdueReminders: [Reminder] = []
    var completedReminders: [Reminder] = []
    var showAddReminder = false
    var isLoading = false
    
    func load(repo: ReminderRepository) {
        isLoading = true
        Task {
            upcomingReminders = (try? repo.fetchUpcoming(limit: 50)) ?? []
            overdueReminders  = (try? repo.fetchOverdue()) ?? []
            let all = (try? repo.fetchAll()) ?? []
            completedReminders = all.filter { $0.isCompleted }
            isLoading = false
        }
    }
    
    func complete(_ reminder: Reminder, repo: ReminderRepository) {
        Task {
            try? repo.complete(reminder)
            for nid in reminder.notificationIDs {
                NotificationService.shared.cancelNotification(id: nid)
            }
            await HapticService.shared.success()
            SoundService.shared.play(.reminderCompleted)
            load(repo: repo)
        }
    }
    
    func delete(_ reminder: Reminder, repo: ReminderRepository) {
        Task {
            try? repo.delete(reminder)
            for nid in reminder.notificationIDs {
                NotificationService.shared.cancelNotification(id: nid)
            }
            load(repo: repo)
        }
    }
}

// MARK: - Analytics ViewModel

@MainActor
@Observable
final class AnalyticsViewModel {
    var monthlyData: [MonthlyData] = []
    var topDebtors: [Person] = []
    var recoveryRates: [CategoryRate] = []
    var cashFlowData: [DayTotal] = []
    var totalGiven: Double = 0
    var totalReceived: Double = 0
    var avgRecoveryDays: Double = 0
    var isLoading = false
    
    func load(personRepo: PersonRepository, txRepo: TransactionRepository) {
        isLoading = true
        Task {
            let people = (try? personRepo.fetchAll()) ?? []
            topDebtors = people.sorted { $0.pendingAmount > $1.pendingAmount }.prefix(10).map { $0 }
            totalGiven = people.reduce(0) { $0 + $1.totalGiven }
            totalReceived = people.reduce(0) { $0 + $1.totalReceived }
            
            // Monthly data for last 6 months
            monthlyData = generateMonthlyData(txRepo: txRepo)
            
            // Category recovery rates
            recoveryRates = PersonCategory.allCases.map { cat in
                let catPeople = people.filter { $0.category == cat }
                let given = catPeople.reduce(0) { $0 + $1.totalGiven }
                let received = catPeople.reduce(0) { $0 + $1.totalReceived }
                let rate = given > 0 ? (received / given) * 100 : 0
                return CategoryRate(category: cat, rate: rate, given: given, received: received)
            }
            
            cashFlowData = (try? txRepo.dailyTotals(for: 30)) ?? []
            isLoading = false
        }
    }
    
    private func generateMonthlyData(txRepo: TransactionRepository) -> [MonthlyData] {
        var result: [MonthlyData] = []
        let cal = Calendar.current
        for i in (0..<6).reversed() {
            guard let date = cal.date(byAdding: .month, value: -i, to: .now) else { continue }
            let start = cal.startOfMonth(for: date)
            let end = cal.endOfMonth(for: date)
            let txs = (try? txRepo.fetch(from: start, to: end)) ?? []
            let given = txs.filter { $0.type == .given }.reduce(0) { $0 + $1.amount }
            let received = txs.filter { $0.type == .received }.reduce(0) { $0 + $1.amount }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            result.append(MonthlyData(month: formatter.string(from: date), given: given, received: received))
        }
        return result
    }
}

struct MonthlyData: Identifiable {
    let id = UUID()
    let month: String
    let given: Double
    let received: Double
}

struct CategoryRate: Identifiable {
    let id = UUID()
    let category: PersonCategory
    let rate: Double
    let given: Double
    let received: Double
}

// MARK: - Search ViewModel

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var results: SearchResults = SearchResults()
    var isSearching = false
    var selectedFilter: SearchFilter = .all
    
    func search(personRepo: PersonRepository, txRepo: TransactionRepository) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = SearchResults()
            return
        }
        isSearching = true
        Task {
            let people = (try? personRepo.search(query: query)) ?? []
            let transactions = (try? txRepo.search(query: query)) ?? []
            results = SearchResults(people: people, transactions: transactions)
            isSearching = false
        }
    }
}

struct SearchResults {
    var people: [Person] = []
    var transactions: [Transaction] = []
    
    var isEmpty: Bool { people.isEmpty && transactions.isEmpty }
    var totalCount: Int { people.count + transactions.count }
}

enum SearchFilter: String, CaseIterable {
    case all = "All"
    case people = "People"
    case transactions = "Transactions"
}

// MARK: - Settings ViewModel

@MainActor
@Observable
final class SettingsViewModel {
    var settings: AppSettings?
    var isFaceIDEnabled = true
    var appearanceMode: AppearanceMode = .auto
    var currencySymbol = "₹"
    var currency = "INR"
    var isSoundEnabled = true
    var isHapticsEnabled = true
    var isCloudBackupEnabled = true
    var isNotificationsEnabled = true
    var fontSize: FontSizeOption = .medium
    var animationSpeed: AnimationSpeed = .normal
    var showBackupSuccess = false
    var showExportSheet = false
    
    func load(repo: SettingsRepository) {
        Task {
            if let s = try? repo.get() {
                settings = s
                isFaceIDEnabled = s.isFaceIDEnabled
                appearanceMode = s.appearanceMode
                currencySymbol = s.currencySymbol
                currency = s.currency
                isSoundEnabled = s.isSoundEnabled
                isHapticsEnabled = s.isHapticsEnabled
                isCloudBackupEnabled = s.isCloudBackupEnabled
                isNotificationsEnabled = s.isNotificationsEnabled
                fontSize = s.fontSize
                animationSpeed = s.animationSpeed
            }
        }
    }
    
    func save(repo: SettingsRepository) {
        guard let s = settings else { return }
        s.isFaceIDEnabled = isFaceIDEnabled
        s.appearanceMode = appearanceMode
        s.currencySymbol = currencySymbol
        s.currency = currency
        s.isSoundEnabled = isSoundEnabled
        s.isHapticsEnabled = isHapticsEnabled
        s.isCloudBackupEnabled = isCloudBackupEnabled
        s.isNotificationsEnabled = isNotificationsEnabled
        s.fontSize = fontSize
        s.animationSpeed = animationSpeed
        try? repo.save(s)
    }
    
    func performBackup(people: [Person], transactions: [Transaction], reminders: [Reminder]) {
        Task {
            let data = try? ExportService.shared.exportBackup(
                people: people, transactions: transactions, reminders: reminders
            )
            if let data, let url = ExportService.shared.writeToTemp(data: data, filename: "MyLedgerPro_Backup.json") {
                settings?.lastBackupDate = .now
                try? SettingsRepository(context: settings.unsafelyUnwrapped.modelContext!).save(settings!)
                showBackupSuccess = true
                await HapticService.shared.success()
                SoundService.shared.play(.backupSuccess)
            }
        }
    }
}

// MARK: - AI Assistant ViewModel

@MainActor
@Observable
final class AIAssistantViewModel {
    var messages: [AIMessage] = []
    var inputText = ""
    var isProcessing = false
    var context = AIContext()
    
    func sendMessage(personRepo: PersonRepository, txRepo: TransactionRepository) {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let userMsg = AIMessage(role: .user, content: inputText)
        messages.append(userMsg)
        let query = inputText
        inputText = ""
        isProcessing = true
        
        Task {
            // Build context
            let people = (try? personRepo.fetchAll()) ?? []
            context.totalGiven = people.reduce(0) { $0 + $1.totalGiven }
            context.totalReceived = people.reduce(0) { $0 + $1.totalReceived }
            context.totalPending = people.reduce(0) { $0 + $1.pendingAmount }
            context.activePeople = people.count
            context.topDebtors = people.sorted { $0.pendingAmount > $1.pendingAmount }
            
            let overdueTxs = (try? txRepo.fetchOverdue()) ?? []
            context.overdueCount = overdueTxs.count
            context.overdueAmount = overdueTxs.reduce(0) { $0 + $1.pendingAmount }
            context.monthlyGiven = (try? txRepo.totalGivenThisMonth()) ?? 0
            context.monthlyReceived = (try? txRepo.totalReceivedThisMonth()) ?? 0
            
            let response = await AIService.shared.processQuery(query, context: context)
            let assistantMsg = AIMessage(role: .assistant, content: response)
            messages.append(assistantMsg)
            isProcessing = false
            await HapticService.shared.selection()
        }
    }
    
    func clearHistory() {
        messages = []
    }
}

struct AIMessage: Identifiable {
    let id = UUID()
    let role: AIRole
    let content: String
    let timestamp: Date = .now
}

enum AIRole {
    case user, assistant
}

// MARK: - Archive ViewModel

@MainActor
@Observable
final class ArchiveViewModel {
    var archivedPeople: [Person] = []
    var deletedPeople: [Person] = []
    var isLoading = false
    
    func load(repo: PersonRepository) {
        isLoading = true
        Task {
            archivedPeople = (try? repo.fetchAll(includeArchived: true))?.filter { $0.isArchived } ?? []
            deletedPeople  = (try? repo.fetchDeleted()) ?? []
            isLoading = false
        }
    }
    
    func restore(_ person: Person, repo: PersonRepository) {
        Task {
            try? repo.restore(person)
            await HapticService.shared.success()
            load(repo: repo)
        }
    }
    
    func permanentlyDelete(_ person: Person, repo: PersonRepository) {
        Task {
            try? repo.delete(person, soft: false)
            load(repo: repo)
        }
    }
}

// MARK: - ModelContext Extension

extension AppSettings {
    var modelContext: ModelContext? {
        // This is a workaround to get modelContext from a SwiftData model
        // In real usage, pass the context explicitly
        nil
    }
}
