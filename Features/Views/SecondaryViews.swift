// MARK: - SecondaryViews.swift
// MyLedgerPro – Reminders, Reports, Analytics, Search, Archive, AI, Settings

import SwiftUI
import SwiftData
import Charts

// MARK: - Reminders View

struct RemindersView: View {
    @Environment(\.modelContext) private var context
    @State private var vm = RemindersViewModel()
    @State private var selectedSegment = 0
    
    var body: some View {
        ZStack {
            AppBackground()
            
            VStack(spacing: 0) {
                Picker("Segment", selection: $selectedSegment) {
                    Text("Upcoming").tag(0)
                    Text("Overdue").tag(1)
                    Text("Done").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if vm.isLoading {
                    LoadingView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            let items = selectedSegment == 0 ? vm.upcomingReminders
                                      : selectedSegment == 1 ? vm.overdueReminders
                                      : vm.completedReminders
                            
                            if items.isEmpty {
                                EmptyStateView(
                                    icon: "bell.slash.fill",
                                    title: selectedSegment == 1 ? "No Overdue Reminders" : "No Reminders",
                                    subtitle: "Tap + to add a reminder",
                                    action: selectedSegment == 0 ? { vm.showAddReminder = true } : nil
                                )
                                .padding(.top, 60)
                            } else {
                                ForEach(items) { reminder in
                                    GlassCard(cornerRadius: 16, padding: 14,
                                              tint: reminder.isOverdue ? .red : .clear) {
                                        ReminderRow(reminder: reminder) {
                                            vm.complete(reminder, repo: ReminderRepository(context: context))
                                        }
                                    }
                                    .padding(.horizontal)
                                    .swipeActions(edge: .trailing) {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            vm.delete(reminder, repo: ReminderRepository(context: context))
                                        }
                                        if !reminder.isCompleted {
                                            Button("Complete", systemImage: "checkmark.circle.fill") {
                                                vm.complete(reminder, repo: ReminderRepository(context: context))
                                            }
                                            .tint(.green)
                                        }
                                    }
                                }
                            }
                            Spacer(minLength: 100)
                        }
                    }
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingAddButton { vm.showAddReminder = true }
                        .padding(.trailing, 24)
                        .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Reminders")
        .glassNavBar()
        .onAppear { vm.load(repo: ReminderRepository(context: context)) }
        .sheet(isPresented: $vm.showAddReminder, onDismiss: {
            vm.load(repo: ReminderRepository(context: context))
        }) {
            AddReminderSheet()
        }
    }
}

// MARK: - Reports View

struct ReportsView: View {
    @Environment(\.modelContext) private var context
    @State private var selectedRange: ReportRange = .thisMonth
    @State private var customFrom = Calendar.current.startOfMonth(for: .now)
    @State private var customTo = Date.now
    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var showExport = false
    @State private var exportURL: URL?
    var currencySymbol: String = "₹"
    
    enum ReportRange: String, CaseIterable {
        case today      = "Today"
        case thisWeek   = "This Week"
        case thisMonth  = "This Month"
        case thisYear   = "This Year"
        case custom     = "Custom"
    }
    
    var dateRange: (Date, Date) {
        let cal = Calendar.current
        let now = Date.now
        switch selectedRange {
        case .today:     return (cal.startOfDay(for: now), now)
        case .thisWeek:  return (cal.date(byAdding: .day, value: -7, to: now)!, now)
        case .thisMonth: return (cal.startOfMonth(for: now), now)
        case .thisYear:
            let start = cal.date(from: cal.dateComponents([.year], from: now))!
            return (start, now)
        case .custom:    return (customFrom, customTo)
        }
    }
    
    var given: Double     { transactions.filter { $0.type == .given }.reduce(0) { $0 + $1.amount } }
    var received: Double  { transactions.filter { $0.type == .received }.reduce(0) { $0 + $1.amount } }
    var borrowed: Double  { transactions.filter { $0.type == .borrowed }.reduce(0) { $0 + $1.amount } }
    var pending: Double   { transactions.filter { $0.status != .paid }.reduce(0) { $0 + $1.pendingAmount } }
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Range picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ReportRange.allCases, id: \.self) { range in
                                FilterChip(title: range.rawValue, isSelected: selectedRange == range) {
                                    selectedRange = range
                                    loadData()
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    // Custom date range
                    if selectedRange == .custom {
                        GlassCard {
                            VStack(spacing: 12) {
                                DatePicker("From", selection: $customFrom, displayedComponents: .date)
                                Divider().opacity(0.4)
                                DatePicker("To", selection: $customTo, displayedComponents: .date)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if isLoading {
                        LoadingView(message: "Generating Report...")
                    } else {
                        // Summary cards
                        summarySection
                        
                        // Per-person breakdown
                        personBreakdown
                        
                        // Export
                        GlassButton(title: "Export Report", icon: "square.and.arrow.up", color: .blue) {
                            exportReport()
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 60)
                }
                .padding(.top)
            }
        }
        .navigationTitle("Reports")
        .glassNavBar()
        .onAppear { loadData() }
        .onChange(of: customFrom) { _, _ in loadData() }
        .onChange(of: customTo) { _, _ in loadData() }
        .sheet(isPresented: $showExport) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    private var summarySection: some View {
        VStack(spacing: 14) {
            Text("Summary for \(selectedRange.rawValue)")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Given Out", value: CurrencyFormatter.formatCompact(given, symbol: currencySymbol), icon: "arrow.up.circle.fill", color: .red)
                StatCard(title: "Received", value: CurrencyFormatter.formatCompact(received, symbol: currencySymbol), icon: "arrow.down.circle.fill", color: .green)
                StatCard(title: "Borrowed", value: CurrencyFormatter.formatCompact(borrowed, symbol: currencySymbol), icon: "hand.raised.fill", color: .orange)
                StatCard(title: "Pending", value: CurrencyFormatter.formatCompact(pending, symbol: currencySymbol), icon: "clock.fill", color: .purple)
            }
            .padding(.horizontal)
        }
    }
    
    private var personBreakdown: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("By Person")
                    .font(.headline)
                    .fontWeight(.bold)
                
                let grouped = Dictionary(grouping: transactions) { $0.person?.id }
                let sorted = grouped.compactMap { (_, txs) -> (Person, Double)? in
                    guard let person = txs.first?.person else { return nil }
                    let total = txs.reduce(0) { $0 + $1.amount }
                    return (person, total)
                }.sorted { $0.1 > $1.1 }
                
                if sorted.isEmpty {
                    Text("No transactions in this period")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sorted.prefix(10), id: \.0.id) { (person, total) in
                        HStack {
                            PersonAvatar(person: person, size: 32)
                            Text(person.name)
                                .font(.subheadline)
                            Spacer()
                            Text(CurrencyFormatter.format(total, symbol: currencySymbol))
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        Divider().opacity(0.3)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func loadData() {
        isLoading = true
        let (from, to) = dateRange
        Task {
            transactions = (try? TransactionRepository(context: context).fetch(from: from, to: to)) ?? []
            isLoading = false
        }
    }
    
    private func exportReport() {
        let csv = ExportService.shared.generateFullCSV(transactions: transactions)
        if let data = csv.data(using: .utf8),
           let url = ExportService.shared.writeToTemp(data: data, filename: "Report_\(selectedRange.rawValue).csv") {
            exportURL = url
            showExport = true
        }
    }
}

// MARK: - Analytics View

struct AnalyticsView: View {
    @Environment(\.modelContext) private var context
    @State private var vm = AnalyticsViewModel()
    var currencySymbol: String = "₹"
    
    var body: some View {
        ZStack {
            AppBackground()
            
            if vm.isLoading {
                LoadingView(message: "Crunching numbers...")
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Summary header
                        summaryHeader
                        
                        // Monthly bar chart
                        monthlyChart
                        
                        // Category rates
                        categoryRates
                        
                        // Top debtors
                        topDebtors
                        
                        // Cash flow
                        cashFlowSection
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.top)
                }
            }
        }
        .navigationTitle("Analytics")
        .glassNavBar()
        .onAppear {
            vm.load(
                personRepo: PersonRepository(context: context),
                txRepo: TransactionRepository(context: context)
            )
        }
    }
    
    private var summaryHeader: some View {
        GlassCard {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Overall Performance")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("All time recovery rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    let rate = vm.totalGiven > 0 ? (vm.totalReceived / vm.totalGiven) * 100 : 0
                    ProgressView(value: rate / 100)
                        .tint(rate >= 75 ? .green : rate >= 50 ? .orange : .red)
                        .padding(.top, 4)
                    
                    Text("\(Int(rate))% recovered")
                        .font(.caption)
                        .foregroundStyle(rate >= 75 ? .green : .orange)
                }
                
                RecoveryGauge(
                    percentage: vm.totalGiven > 0 ? (vm.totalReceived / vm.totalGiven) * 100 : 0,
                    size: 90
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var monthlyChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Monthly Trends (6 months)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                if !vm.monthlyData.isEmpty {
                    Chart {
                        ForEach(vm.monthlyData) { item in
                            BarMark(x: .value("Month", item.month), y: .value("Given", item.given))
                                .foregroundStyle(.red.opacity(0.7))
                                .position(by: .value("Type", "Given"))
                            
                            BarMark(x: .value("Month", item.month), y: .value("Received", item.received))
                                .foregroundStyle(.green.opacity(0.7))
                                .position(by: .value("Type", "Received"))
                        }
                    }
                    .frame(height: 180)
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel(value.as(String.self) ?? "")
                                .font(.caption2)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(CurrencyFormatter.formatCompact(v, symbol: currencySymbol))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 20) {
                        Label("Given", systemImage: "circle.fill").foregroundStyle(.red.opacity(0.8))
                        Label("Received", systemImage: "circle.fill").foregroundStyle(.green.opacity(0.8))
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var categoryRates: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Recovery by Category")
                    .font(.headline)
                    .fontWeight(.bold)
                
                ForEach(vm.recoveryRates) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: item.category.icon)
                                .foregroundStyle(item.category.color)
                                .frame(width: 20)
                            Text(item.category.rawValue)
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(item.rate))%")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(item.rate >= 75 ? .green : item.rate >= 50 ? .orange : .red)
                        }
                        ProgressView(value: min(item.rate / 100, 1))
                            .tint(item.rate >= 75 ? .green : item.rate >= 50 ? .orange : .red)
                    }
                    if item.category != vm.recoveryRates.last?.category {
                        Divider().opacity(0.3)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var topDebtors: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Highest Outstanding")
                    .font(.headline)
                    .fontWeight(.bold)
                
                if vm.topDebtors.filter({ $0.pendingAmount > 0 }).isEmpty {
                    Text("Everyone is settled up! 🎉")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(vm.topDebtors.filter({ $0.pendingAmount > 0 }).prefix(5)) { person in
                        HStack {
                            PersonAvatar(person: person, size: 36)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(person.category.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(CurrencyFormatter.format(person.pendingAmount, symbol: currencySymbol))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.red)
                                Text("\(Int(person.recoveryPercentage))% paid")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if person.id != vm.topDebtors.filter({ $0.pendingAmount > 0 }).prefix(5).last?.id {
                            Divider().opacity(0.3)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var cashFlowSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Cash Flow (30 days)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                if !vm.cashFlowData.isEmpty {
                    Chart {
                        ForEach(vm.cashFlowData.filter { $0.given > 0 || $0.received > 0 }) { day in
                            LineMark(
                                x: .value("Date", day.date),
                                y: .value("Given", day.given)
                            )
                            .foregroundStyle(.red.opacity(0.8))
                            .interpolationMethod(.catmullRom)
                            
                            LineMark(
                                x: .value("Date", day.date),
                                y: .value("Received", day.received)
                            )
                            .foregroundStyle(.green.opacity(0.8))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .frame(height: 140)
                    .chartXAxis(.hidden)
                } else {
                    Text("No data available for this period")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Search View

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @State private var vm = SearchViewModel()
    @FocusState private var isFocused: Bool
    var currencySymbol: String = "₹"
    
    var body: some View {
        ZStack {
            AppBackground()
            
            VStack(spacing: 0) {
                // Custom search bar
                searchBar
                
                if vm.query.isEmpty {
                    searchHints
                } else if vm.isSearching {
                    LoadingView(message: "Searching...")
                } else if vm.results.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results",
                        subtitle: "Try a different search term"
                    )
                } else {
                    // Filter tabs
                    filterTabs
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if vm.selectedFilter != .transactions && !vm.results.people.isEmpty {
                                Section(header: sectionHeader("People", count: vm.results.people.count)) {
                                    ForEach(vm.results.people) { person in
                                        NavigationLink(destination: PersonDetailView(person: person, currencySymbol: currencySymbol)) {
                                            GlassCard(cornerRadius: 16, padding: 12) {
                                                PersonCell(person: person, currencySymbol: currencySymbol)
                                            }
                                            .padding(.horizontal)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            if vm.selectedFilter != .people && !vm.results.transactions.isEmpty {
                                Section(header: sectionHeader("Transactions", count: vm.results.transactions.count)) {
                                    ForEach(vm.results.transactions) { tx in
                                        NavigationLink(destination: TransactionDetailView(transaction: tx, currencySymbol: currencySymbol)) {
                                            GlassCard(cornerRadius: 16, padding: 12) {
                                                TransactionRow(transaction: tx, currencySymbol: currencySymbol)
                                            }
                                            .padding(.horizontal)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            Spacer(minLength: 60)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .navigationTitle("Search")
        .glassNavBar()
        .onChange(of: vm.query) { _, _ in
            vm.search(
                personRepo: PersonRepository(context: context),
                txRepo: TransactionRepository(context: context)
            )
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search people, amounts, notes...", text: $vm.query)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit {
                    vm.search(
                        personRepo: PersonRepository(context: context),
                        txRepo: TransactionRepository(context: context)
                    )
                }
            
            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding()
        .onAppear { isFocused = true }
    }
    
    private var filterTabs: some View {
        HStack(spacing: 0) {
            ForEach(SearchFilter.allCases, id: \.self) { filter in
                Button {
                    vm.selectedFilter = filter
                } label: {
                    Text(filter.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            vm.selectedFilter == filter ? Color.blue.opacity(0.15) : Color.clear,
                            in: Capsule()
                        )
                        .foregroundStyle(vm.selectedFilter == filter ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
    
    private var searchHints: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Search by")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                let hints = [
                    ("person.fill", "Person name (e.g. Rahul)"),
                    ("indianrupeesign.circle.fill", "Amount (e.g. 5000)"),
                    ("calendar.fill", "Month (e.g. January)"),
                    ("tag.fill", "Tag (e.g. loan)"),
                    ("note.text", "Notes (e.g. urgent)")
                ]
                
                ForEach(hints, id: \.0) { (icon, hint) in
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: 32)
                        Text(hint)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 60)
            }
        }
    }
    
    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            Text("(\(count))")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Archive View

struct ArchiveView: View {
    @Environment(\.modelContext) private var context
    @State private var vm = ArchiveViewModel()
    @State private var selectedSegment = 0
    
    var body: some View {
        ZStack {
            AppBackground()
            
            VStack(spacing: 0) {
                Picker("Type", selection: $selectedSegment) {
                    Text("Archived").tag(0)
                    Text("Deleted").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if vm.isLoading {
                    LoadingView()
                } else {
                    let items = selectedSegment == 0 ? vm.archivedPeople : vm.deletedPeople
                    
                    if items.isEmpty {
                        EmptyStateView(
                            icon: "archivebox",
                            title: selectedSegment == 0 ? "No Archived People" : "Recycle Bin Empty",
                            subtitle: selectedSegment == 0 ? "Archive people to store them here" : "Deleted items appear here for recovery"
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(items) { person in
                                    GlassCard(cornerRadius: 16, padding: 12) {
                                        HStack {
                                            PersonAvatar(person: person, size: 44)
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(person.name)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.secondary)
                                                
                                                if selectedSegment == 1, let del = person.deletedAt {
                                                    Text("Deleted \(del.formatted(date: .abbreviated, time: .omitted))")
                                                        .font(.caption)
                                                        .foregroundStyle(.red.opacity(0.7))
                                                } else {
                                                    Text("Archived")
                                                        .font(.caption)
                                                        .foregroundStyle(.orange.opacity(0.8))
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            HStack(spacing: 10) {
                                                Button {
                                                    vm.restore(person, repo: PersonRepository(context: context))
                                                } label: {
                                                    Image(systemName: "arrow.counterclockwise.circle.fill")
                                                        .foregroundStyle(.blue)
                                                        .font(.title3)
                                                }
                                                
                                                if selectedSegment == 1 {
                                                    Button(role: .destructive) {
                                                        vm.permanentlyDelete(person, repo: PersonRepository(context: context))
                                                    } label: {
                                                        Image(systemName: "trash.circle.fill")
                                                            .foregroundStyle(.red)
                                                            .font(.title3)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                Spacer(minLength: 60)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
        }
        .navigationTitle("Archive")
        .glassNavBar()
        .onAppear { vm.load(repo: PersonRepository(context: context)) }
    }
}

// MARK: - AI Assistant View

struct AIAssistantView: View {
    @Environment(\.modelContext) private var context
    @State private var vm = AIAssistantViewModel()
    @FocusState private var inputFocused: Bool
    
    let quickPrompts = [
        "How much is pending overall?",
        "Show me this month's summary",
        "Who are the top debtors?",
        "Any overdue payments?",
        "Show recovery rate"
    ]
    
    var body: some View {
        ZStack {
            AppBackground()
            
            VStack(spacing: 0) {
                
                if vm.messages.isEmpty {
                    // Welcome screen
                    welcomeScreen
                } else {
                    // Chat messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(vm.messages) { message in
                                    AIMessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                if vm.isProcessing {
                                    TypingIndicator()
                                }
                                
                                Spacer(minLength: 20).id("bottom")
                            }
                            .padding()
                        }
                        .onChange(of: vm.messages.count) { _, _ in
                            withAnimation { proxy.scrollTo("bottom") }
                        }
                    }
                }
                
                // Input bar
                inputBar
            }
        }
        .navigationTitle("AI Assistant")
        .glassNavBar()
        .toolbar {
            if !vm.messages.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear", systemImage: "trash") {
                        vm.clearHistory()
                    }
                }
            }
        }
    }
    
    private var welcomeScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 8) {
                    Text("AI Assistant")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Ask anything about your finances")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 10) {
                    Text("Try asking:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    ForEach(quickPrompts, id: \.self) { prompt in
                        Button {
                            vm.inputText = prompt
                            vm.sendMessage(
                                personRepo: PersonRepository(context: context),
                                txRepo: TransactionRepository(context: context)
                            )
                        } label: {
                            HStack {
                                Image(systemName: "sparkle")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                Text(prompt)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask anything about your money...", text: $vm.inputText, axis: .vertical)
                .focused($inputFocused)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            
            Button {
                inputFocused = false
                vm.sendMessage(
                    personRepo: PersonRepository(context: context),
                    txRepo: TransactionRepository(context: context)
                )
            } label: {
                Image(systemName: vm.isProcessing ? "ellipsis" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(vm.inputText.isEmpty ? .secondary : .blue)
            }
            .disabled(vm.inputText.isEmpty || vm.isProcessing)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

struct AIMessageBubble: View {
    var message: AIMessage
    
    var isUser: Bool { message.role == .user }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }
            
            if !isUser {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(6)
                    .background(Color.blue.opacity(0.1), in: Circle())
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(isUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                        ? AnyShapeStyle(LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.clear.background(.ultraThinMaterial)),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
}

struct TypingIndicator: View {
    @State private var dot1 = false
    @State private var dot2 = false
    @State private var dot3 = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(6)
                .background(Color.blue.opacity(0.1), in: Circle())
            
            HStack(spacing: 4) {
                Circle().fill(Color.secondary).frame(width: 7, height: 7)
                    .scaleEffect(dot1 ? 1.3 : 0.8).animation(.easeInOut(duration: 0.4).repeatForever().delay(0), value: dot1)
                Circle().fill(Color.secondary).frame(width: 7, height: 7)
                    .scaleEffect(dot2 ? 1.3 : 0.8).animation(.easeInOut(duration: 0.4).repeatForever().delay(0.15), value: dot2)
                Circle().fill(Color.secondary).frame(width: 7, height: 7)
                    .scaleEffect(dot3 ? 1.3 : 0.8).animation(.easeInOut(duration: 0.4).repeatForever().delay(0.3), value: dot3)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            
            Spacer()
        }
        .onAppear { dot1 = true; dot2 = true; dot3 = true }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var vm = SettingsViewModel()
    @State private var showAbout = false
    @State private var showBackupAlert = false
    var currencySymbol: String = "₹"
    
    var body: some View {
        ZStack {
            AppBackground()
            
            List {
                
                // Security
                Section {
                    settingsRow(icon: "faceid", title: "Face ID / Touch ID", iconColor: .blue) {
                        Toggle("", isOn: $vm.isFaceIDEnabled)
                            .tint(.blue)
                            .onChange(of: vm.isFaceIDEnabled) { _, _ in
                                vm.save(repo: SettingsRepository(context: context))
                            }
                    }
                } header: { sectionLabel("Security") }
                .listRowBackground(Color.clear)
                
                // Appearance
                Section {
                    settingsRow(icon: "paintpalette.fill", title: "Appearance", iconColor: .purple) {
                        Picker("", selection: $vm.appearanceMode) {
                            ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .onChange(of: vm.appearanceMode) { _, _ in
                            vm.save(repo: SettingsRepository(context: context))
                        }
                    }
                    
                    settingsRow(icon: "textformat.size", title: "Font Size", iconColor: .indigo) {
                        Picker("", selection: $vm.fontSize) {
                            ForEach(FontSizeOption.allCases, id: \.self) { size in
                                Text(size.rawValue).tag(size)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .onChange(of: vm.fontSize) { _, _ in
                            vm.save(repo: SettingsRepository(context: context))
                        }
                    }
                    
                    settingsRow(icon: "wand.and.sparkles", title: "Animations", iconColor: .pink) {
                        Picker("", selection: $vm.animationSpeed) {
                            ForEach(AnimationSpeed.allCases, id: \.self) { speed in
                                Text(speed.rawValue).tag(speed)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .onChange(of: vm.animationSpeed) { _, _ in
                            vm.save(repo: SettingsRepository(context: context))
                        }
                    }
                } header: { sectionLabel("Appearance") }
                .listRowBackground(Color.clear)
                
                // Currency
                Section {
                    settingsRow(icon: "indianrupeesign.circle.fill", title: "Currency Symbol", iconColor: .green) {
                        Picker("", selection: $vm.currencySymbol) {
                            Text("₹ INR").tag("₹")
                            Text("$ USD").tag("$")
                            Text("€ EUR").tag("€")
                            Text("£ GBP").tag("£")
                            Text("¥ JPY").tag("¥")
                            Text("AED").tag("AED")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .onChange(of: vm.currencySymbol) { _, _ in
                            vm.save(repo: SettingsRepository(context: context))
                        }
                    }
                } header: { sectionLabel("Currency") }
                .listRowBackground(Color.clear)
                
                // Notifications
                Section {
                    settingsRow(icon: "bell.fill", title: "Notifications", iconColor: .orange) {
                        Toggle("", isOn: $vm.isNotificationsEnabled)
                            .tint(.orange)
                            .onChange(of: vm.isNotificationsEnabled) { _, enabled in
                                vm.save(repo: SettingsRepository(context: context))
                                if enabled {
                                    Task { await NotificationService.shared.requestPermission() }
                                }
                            }
                    }
                    
                    settingsRow(icon: "speaker.wave.2.fill", title: "Sound Effects", iconColor: .teal) {
                        Toggle("", isOn: $vm.isSoundEnabled)
                            .tint(.teal)
                            .onChange(of: vm.isSoundEnabled) { _, _ in
                                vm.save(repo: SettingsRepository(context: context))
                            }
                    }
                    
                    settingsRow(icon: "iphone.radiowaves.left.and.right", title: "Haptics", iconColor: .cyan) {
                        Toggle("", isOn: $vm.isHapticsEnabled)
                            .tint(.cyan)
                            .onChange(of: vm.isHapticsEnabled) { _, _ in
                                vm.save(repo: SettingsRepository(context: context))
                            }
                    }
                } header: { sectionLabel("Notifications & Sound") }
                .listRowBackground(Color.clear)
                
                // Backup
                Section {
                    settingsRow(icon: "icloud.fill", title: "iCloud Backup", iconColor: .blue) {
                        Toggle("", isOn: $vm.isCloudBackupEnabled)
                            .tint(.blue)
                            .onChange(of: vm.isCloudBackupEnabled) { _, _ in
                                vm.save(repo: SettingsRepository(context: context))
                            }
                    }
                    
                    Button {
                        showBackupAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise.icloud.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                            Text("Backup Now")
                                .foregroundStyle(.primary)
                            Spacer()
                            if let date = vm.settings?.lastBackupDate {
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                } header: { sectionLabel("Backup") }
                .listRowBackground(Color.clear)
                
                // About
                Section {
                    Button {
                        showAbout = true
                    } label: {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                            Text("About My Ledger Pro")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("v1.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: { sectionLabel("About") }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .glassNavBar()
        .onAppear { vm.load(repo: SettingsRepository(context: context)) }
        .alert("Backup Created", isPresented: $vm.showBackupSuccess) {
            Button("OK") {}
        } message: {
            Text("Your data has been backed up successfully.")
        }
        .alert("Backup Now?", isPresented: $showBackupAlert) {
            Button("Backup") {
                Task {
                    let people = (try? PersonRepository(context: context).fetchAll(includeArchived: true)) ?? []
                    let txs = (try? TransactionRepository(context: context).fetchAll(includeDeleted: true)) ?? []
                    let reminders = (try? ReminderRepository(context: context).fetchAll()) ?? []
                    vm.performBackup(people: people, transactions: txs, reminders: reminders)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will create a backup of all your data.")
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
    }
    
    private func settingsRow<T: View>(icon: String, title: String, iconColor: Color, @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 7))
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            trailing()
        }
        .padding(.vertical, 2)
    }
    
    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer(minLength: 20)
                        
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(spacing: 6) {
                            Text("My Ledger Pro")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("Personal Finance CRM")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Version 1.0")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                featureRow("🔐", "Face ID / Touch ID Security")
                                featureRow("☁️", "iCloud Backup")
                                featureRow("📊", "Advanced Analytics")
                                featureRow("🤖", "AI-powered Insights")
                                featureRow("🔔", "Smart Reminders")
                                featureRow("📄", "PDF & CSV Export")
                                featureRow("💾", "Offline First")
                                featureRow("📱", "iOS 17+ Design")
                            }
                        }
                        .padding(.horizontal)
                        
                        Text("Built with ❤️ using Swift 6 & SwiftUI")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .glassNavBar()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(icon)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}
