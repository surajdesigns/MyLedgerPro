// MARK: - DashboardView.swift
// MyLedgerPro – Dashboard Screen

import SwiftUI
import SwiftData

// MARK: - Dashboard

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @State private var vm = DashboardViewModel()
    @State private var showAddTransaction = false
    var currencySymbol: String = "₹"
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Header
                    headerSection
                    
                    // Overdue alert
                    if !vm.overdueTransactions.isEmpty {
                        OverdueAlertBanner(
                            count: vm.overdueTransactions.count,
                            amount: vm.overdueAmount,
                            symbol: currencySymbol
                        )
                        .padding(.horizontal)
                    }
                    
                    // Stats grid
                    statsGrid
                    
                    // Chart
                    chartSection
                    
                    // Recent Transactions
                    recentSection
                    
                    // Upcoming Reminders
                    remindersSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.top)
            }
            
            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingAddButton { showAddTransaction = true }
                        .padding(.trailing, 24)
                        .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Dashboard")
        .glassNavBar()
        .onAppear {
            vm.load(
                personRepo: PersonRepository(context: context),
                txRepo: TransactionRepository(context: context),
                reminderRepo: ReminderRepository(context: context)
            )
        }
        .sheet(isPresented: $showAddTransaction) {
            AddTransactionSheet(currencySymbol: currencySymbol)
        }
        .refreshable {
            vm.load(
                personRepo: PersonRepository(context: context),
                txRepo: TransactionRepository(context: context),
                reminderRepo: ReminderRepository(context: context)
            )
        }
    }
    
    // MARK: Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("My Ledger Pro")
                    .font(.title)
                    .fontWeight(.bold)
            }
            Spacer()
            
            GlassCard(cornerRadius: 50, padding: 10) {
                VStack(spacing: 2) {
                    Text("\(vm.activePeopleCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("People")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 52, height: 40)
            }
        }
        .padding(.horizontal)
    }
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good Morning ☀️" }
        if hour < 17 { return "Good Afternoon 🌤" }
        return "Good Evening 🌙"
    }
    
    // MARK: Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            StatCard(
                title: "Total Given",
                value: CurrencyFormatter.formatCompact(vm.totalGiven, symbol: currencySymbol),
                icon: "arrow.up.circle.fill",
                color: .red,
                subtitle: "All time"
            )
            StatCard(
                title: "Total Received",
                value: CurrencyFormatter.formatCompact(vm.totalReceived, symbol: currencySymbol),
                icon: "arrow.down.circle.fill",
                color: .green,
                subtitle: "All time"
            )
            StatCard(
                title: "Pending",
                value: CurrencyFormatter.formatCompact(vm.totalPending, symbol: currencySymbol),
                icon: "clock.fill",
                color: .orange,
                subtitle: vm.overdueTransactions.isEmpty ? "All on track" : "\(vm.overdueTransactions.count) overdue"
            )
            StatCard(
                title: "This Month",
                value: CurrencyFormatter.formatCompact(vm.thisMonthGiven, symbol: currencySymbol),
                icon: "calendar.circle.fill",
                color: .blue,
                subtitle: "Given out"
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: Chart
    
    private var chartSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Last 14 Days")
                
                SimpleBarChart(data: vm.chartData)
                
                HStack(spacing: 20) {
                    Label("Given", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.8))
                    Label("Received", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green.opacity(0.8))
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: Recent Transactions
    
    private var recentSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Recent Transactions")
                
                if vm.recentTransactions.isEmpty {
                    HStack {
                        Spacer()
                        Text("No transactions yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                        Spacer()
                    }
                } else {
                    ForEach(vm.recentTransactions.prefix(5)) { tx in
                        TransactionRow(transaction: tx, currencySymbol: currencySymbol)
                        if tx.id != vm.recentTransactions.prefix(5).last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: Reminders
    
    private var remindersSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Upcoming Reminders")
                
                if vm.upcomingReminders.isEmpty {
                    Text("No upcoming reminders")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(vm.upcomingReminders) { reminder in
                        ReminderRow(reminder: reminder) {}
                        if reminder.id != vm.upcomingReminders.last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - People View

struct PeopleView: View {
    @Environment(\.modelContext) private var context
    @State private var vm = PeopleViewModel()
    @State private var showAddPerson = false
    var currencySymbol: String = "₹"
    
    var body: some View {
        ZStack {
            AppBackground()
            
            if vm.isLoading {
                LoadingView()
            } else if vm.filtered.isEmpty {
                EmptyStateView(
                    icon: "person.2.fill",
                    title: "No People Yet",
                    subtitle: "Add people to track money given and received",
                    action: { showAddPerson = true },
                    actionTitle: "Add Person"
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Category filter
                        categoryFilterBar
                        
                        // People list
                        LazyVStack(spacing: 8) {
                            ForEach(vm.filtered) { person in
                                NavigationLink(destination: PersonDetailView(person: person, currencySymbol: currencySymbol)) {
                                    GlassCard(cornerRadius: 16, padding: 12) {
                                        PersonCell(person: person, currencySymbol: currencySymbol)
                                    }
                                    .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        vm.delete(person, repo: PersonRepository(context: context))
                                    }
                                    Button("Archive", systemImage: "archivebox") {
                                        vm.archive(person, repo: PersonRepository(context: context))
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                        .padding(.top, 8)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingAddButton { showAddPerson = true }
                        .padding(.trailing, 24)
                        .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("People")
        .glassNavBar()
        .searchable(text: $vm.searchText, prompt: "Search people...")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(PersonSortOrder.allCases, id: \.self) { order in
                        Button(order.rawValue) { vm.sortOrder = order }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
        }
        .onAppear { vm.load(repo: PersonRepository(context: context)) }
        .sheet(isPresented: $showAddPerson, onDismiss: { vm.load(repo: PersonRepository(context: context)) }) {
            AddPersonSheet()
        }
    }
    
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(title: "All", isSelected: vm.selectedCategory == nil) {
                    vm.selectedCategory = nil
                }
                ForEach(PersonCategory.allCases, id: \.self) { cat in
                    FilterChip(title: cat.rawValue, icon: cat.icon, color: cat.color, isSelected: vm.selectedCategory == cat) {
                        vm.selectedCategory = vm.selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }
}

struct FilterChip: View {
    var title: String
    var icon: String? = nil
    var color: Color = .blue
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.caption2) }
                Text(title).font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? color.opacity(0.2) : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? color : Color.secondary.opacity(0.3), lineWidth: 1))
            .foregroundStyle(isSelected ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Person Detail View

struct PersonDetailView: View {
    var person: Person
    var currencySymbol: String = "₹"
    @Environment(\.modelContext) private var context
    @State private var showAddTransaction = false
    @State private var showExportOptions = false
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Profile header
                    profileHeader
                    
                    // Quick stats
                    personStatsGrid
                    
                    // Recovery gauge
                    recoverySection
                    
                    // Transactions
                    transactionHistory
                    
                    Spacer(minLength: 100)
                }
                .padding(.top)
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingAddButton { showAddTransaction = true }
                        .padding(.trailing, 24)
                        .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle(person.name)
        .glassNavBar()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Call", systemImage: "phone") {
                        if let url = URL(string: "tel:\(person.phone)") {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("WhatsApp", systemImage: "message") {
                        if let url = URL(string: "https://wa.me/\(person.phone)") {
                            UIApplication.shared.open(url)
                        }
                    }
                    Divider()
                    Button("Export PDF", systemImage: "doc.fill") {
                        showExportOptions = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAddTransaction) {
            AddTransactionSheet(preselectedPerson: person, currencySymbol: currencySymbol)
        }
        .sheet(isPresented: $showExportOptions) {
            ExportSheet(person: person, currencySymbol: currencySymbol)
        }
    }
    
    private var profileHeader: some View {
        GlassCard {
            HStack(spacing: 16) {
                PersonAvatar(person: person, size: 72)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(person.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if !person.phone.isEmpty {
                        Label(person.phone, systemImage: "phone.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Label(person.category.rawValue, systemImage: person.category.icon)
                            .font(.caption)
                            .foregroundStyle(person.categoryColor)
                        
                        TrustScoreBadge(score: person.trustScore)
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal)
    }
    
    private var personStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            miniStat("Given", value: CurrencyFormatter.formatCompact(person.totalGiven, symbol: currencySymbol), color: .red)
            miniStat("Received", value: CurrencyFormatter.formatCompact(person.totalReceived, symbol: currencySymbol), color: .green)
            miniStat("Pending", value: CurrencyFormatter.formatCompact(person.pendingAmount, symbol: currencySymbol), color: .orange)
        }
        .padding(.horizontal)
    }
    
    private func miniStat(_ title: String, value: String, color: Color) -> some View {
        GlassCard(cornerRadius: 14, padding: 12, tint: color) {
            VStack(spacing: 4) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var recoverySection: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recovery Rate")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ProgressView(value: person.recoveryPercentage / 100)
                        .tint(person.recoveryPercentage >= 75 ? .green : person.recoveryPercentage >= 50 ? .orange : .red)
                    
                    if let lastDate = person.lastTransactionDate {
                        Text("Last activity: \(lastDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer(minLength: 20)
                
                RecoveryGauge(percentage: person.recoveryPercentage)
            }
        }
        .padding(.horizontal)
    }
    
    private var transactionHistory: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Transactions")
                
                let txs = person.transactions.filter { !$0.isDeleted }.sorted { $0.date > $1.date }
                
                if txs.isEmpty {
                    HStack {
                        Spacer()
                        Text("No transactions")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .padding(.vertical, 16)
                        Spacer()
                    }
                } else {
                    ForEach(txs) { tx in
                        NavigationLink(destination: TransactionDetailView(transaction: tx, currencySymbol: currencySymbol)) {
                            TransactionRow(transaction: tx, currencySymbol: currencySymbol)
                        }
                        .buttonStyle(.plain)
                        if tx.id != txs.last?.id { Divider().opacity(0.4) }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Transaction Detail View

struct TransactionDetailView: View {
    var transaction: Transaction
    var currencySymbol: String = "₹"
    @Environment(\.modelContext) private var context
    @State private var showAddPayment = false
    @State private var partialAmount = ""
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Main card
                    mainInfoCard
                    
                    // Partial payments
                    if !transaction.partialPayments.filter({ !$0.isDeleted }).isEmpty {
                        partialPaymentsCard
                    }
                    
                    // Add payment button
                    if transaction.status != .paid {
                        GlassButton(title: "Record Partial Payment", icon: "plus.circle.fill", color: .green) {
                            showAddPayment = true
                        }
                        .padding(.horizontal)
                    }
                    
                    // Photos
                    if transaction.receiptImageData != nil || transaction.billImageData != nil {
                        photosCard
                    }
                    
                    // Notes
                    if !transaction.notes.isEmpty {
                        notesCard
                    }
                    
                    Spacer(minLength: 60)
                }
                .padding(.top)
            }
        }
        .navigationTitle("Transaction")
        .glassNavBar()
        .sheet(isPresented: $showAddPayment) {
            AddPartialPaymentSheet(transaction: transaction, currencySymbol: currencySymbol)
        }
    }
    
    private var mainInfoCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: transaction.type.icon)
                        .font(.largeTitle)
                        .foregroundStyle(transaction.type.color)
                    
                    Spacer()
                    
                    StatusBadge(status: transaction.status)
                }
                
                VStack(spacing: 4) {
                    Text(CurrencyFormatter.format(transaction.amount, symbol: currencySymbol))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if transaction.pendingAmount > 0 && transaction.pendingAmount < transaction.amount {
                        Text("Pending: \(CurrencyFormatter.format(transaction.pendingAmount, symbol: currencySymbol))")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
                
                Divider().opacity(0.4)
                
                infoRow("Person", value: transaction.person?.name ?? "Unknown", icon: "person.fill")
                infoRow("Type", value: transaction.type.rawValue, icon: transaction.type.icon)
                infoRow("Date", value: transaction.date.formatted(date: .long, time: .shortened), icon: "calendar")
                infoRow("Method", value: transaction.paymentMethod.rawValue, icon: transaction.paymentMethod.icon)
                
                if let due = transaction.dueDate {
                    infoRow("Due Date", value: due.formatted(date: .long, time: .omitted), icon: "clock.fill")
                }
                
                if transaction.isOverdue {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Overdue by \(transaction.overdueByDays) day(s)")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                
                if !transaction.tags.isEmpty {
                    HStack {
                        Text("Tags:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(transaction.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1), in: Capsule())
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func infoRow(_ label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
    
    private var partialPaymentsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Payments Received")
                
                let payments = transaction.partialPayments.filter { !$0.isDeleted }.sorted { $0.date < $1.date }
                
                ForEach(payments) { pp in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pp.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                            Text(pp.paymentMethod.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(CurrencyFormatter.format(pp.amount, symbol: currencySymbol))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                    if pp.id != payments.last?.id { Divider().opacity(0.4) }
                }
                
                Divider()
                
                HStack {
                    Text("Paid: \(CurrencyFormatter.format(transaction.totalPaid, symbol: currencySymbol))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                    Spacer()
                    if transaction.pendingAmount > 0 {
                        Text("Remaining: \(CurrencyFormatter.format(transaction.pendingAmount, symbol: currencySymbol))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var photosCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Documents")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 12) {
                    if let data = transaction.receiptImageData, let img = UIImage(data: data) {
                        photoThumb(img, title: "Receipt")
                    }
                    if let data = transaction.billImageData, let img = UIImage(data: data) {
                        photoThumb(img, title: "Bill")
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func photoThumb(_ img: UIImage, title: String) -> some View {
        VStack(spacing: 4) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var notesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Notes", systemImage: "note.text")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(transaction.notes)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Transactions View

struct TransactionsView: View {
    @Environment(\.modelContext) private var context
    @State private var vm = TransactionsViewModel()
    var currencySymbol: String = "₹"
    
    var body: some View {
        ZStack {
            AppBackground()
            
            VStack(spacing: 0) {
                // Filter bar
                filterBar
                
                if vm.isLoading {
                    LoadingView()
                } else if vm.filtered.isEmpty {
                    EmptyStateView(
                        icon: "arrow.left.arrow.right.circle",
                        title: "No Transactions",
                        subtitle: "Tap + to record your first transaction",
                        action: { vm.showAddTransaction = true },
                        actionTitle: "Add Transaction"
                    )
                } else {
                    List {
                        ForEach(vm.filtered) { tx in
                            NavigationLink(destination: TransactionDetailView(transaction: tx, currencySymbol: currencySymbol)) {
                                TransactionRow(transaction: tx, currencySymbol: currencySymbol)
                            }
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    vm.delete(tx, repo: TransactionRepository(context: context))
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingAddButton { vm.showAddTransaction = true }
                        .padding(.trailing, 24)
                        .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Transactions")
        .glassNavBar()
        .searchable(text: $vm.searchText, prompt: "Search transactions...")
        .onAppear { vm.load(repo: TransactionRepository(context: context)) }
        .sheet(isPresented: $vm.showAddTransaction, onDismiss: { vm.load(repo: TransactionRepository(context: context)) }) {
            AddTransactionSheet(currencySymbol: currencySymbol)
        }
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(title: "All", isSelected: vm.filterType == nil) {
                    vm.filterType = nil
                }
                ForEach(TransactionType.allCases, id: \.self) { type in
                    FilterChip(title: type.rawValue, icon: type.icon, color: type.color, isSelected: vm.filterType == type) {
                        vm.filterType = vm.filterType == type ? nil : type
                    }
                }
                
                Divider().frame(height: 24)
                
                ForEach(TransactionStatus.allCases, id: \.self) { status in
                    FilterChip(title: status.rawValue, color: status.color, isSelected: vm.filterStatus == status) {
                        vm.filterStatus = vm.filterStatus == status ? nil : status
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }
}
