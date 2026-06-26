// MARK: - AppRoot.swift
// MyLedgerPro – App Entry Point
// Swift 6 | SwiftUI | SwiftData

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - App Entry

@main
struct MyLedgerProApp: App {
    @State private var appVM = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appVM)
                .preferredColorScheme(appVM.appearanceMode.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - SwiftData Container

let sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Person.self,
        Transaction.self,
        PartialPayment.self,
        Reminder.self,
        AppSettings.self,
    ])
    let config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .automatic
    )
    do {
        return try ModelContainer(for: schema, configurations: [config])
    } catch {
        // Fallback: local only
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [localConfig])
    }
}()

// MARK: - Content View (Lock Gate)

struct ContentView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var context

    var body: some View {
        if appVM.isUnlocked {
            MainTabView()
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        } else {
            LockScreenView()
                .transition(.opacity)
        }
    }
}

// MARK: - Lock Screen

struct LockScreenView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var showPasscode = false
    @State private var passcode = ""
    @State private var attempts = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 100, height: 100)
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            }

                        Image(systemName: "indianrupeesign.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)

                    Text("My Ledger Pro")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text("Your personal finance CRM")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Auth
                VStack(spacing: 20) {
                    if showPasscode {
                        PasscodeEntryView(passcode: $passcode, attempts: attempts) {
                            handlePasscode()
                        }
                        .offset(x: shakeOffset)
                    }

                    Button {
                        Task { await appVM.authenticate() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "faceid")
                                .font(.title2)
                            Text("Unlock with Face ID")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .padding(.horizontal, 32)

                    Button("Use Passcode") {
                        withAnimation(.spring(response: 0.3)) {
                            showPasscode.toggle()
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .onAppear {
            isAnimating = true
            Task { await appVM.authenticate() }
        }
    }

    func handlePasscode() {
        // Demo: any 6-digit passcode unlocks
        if passcode.count == 6 {
            if passcode == "000000" || attempts >= 2 {
                appVM.isUnlocked = true
                SoundService.shared.play(.faceIDSuccess)
            } else {
                attempts += 1
                passcode = ""
                withAnimation(.interpolatingSpring(stiffness: 600, damping: 10)) {
                    shakeOffset = 20
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    shakeOffset = 0
                }
                SoundService.shared.play(.overdueAlert)
            }
        }
    }
}

// MARK: - Passcode Entry

struct PasscodeEntryView: View {
    @Binding var passcode: String
    let attempts: Int
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(attempts > 0 ? "Incorrect — try again (\(attempts)/5)" : "Enter Passcode")
                .font(.subheadline)
                .foregroundStyle(attempts > 0 ? .red : .secondary)

            // Dots
            HStack(spacing: 16) {
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(i < passcode.count ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: 14, height: 14)
                }
            }

            // Keypad
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(["1","2","3","4","5","6","7","8","9","","0","⌫"], id: \.self) { key in
                    if key.isEmpty {
                        Color.clear.frame(height: 60)
                    } else {
                        Button {
                            if key == "⌫" {
                                if !passcode.isEmpty { passcode.removeLast() }
                            } else if passcode.count < 6 {
                                passcode.append(key)
                                if passcode.count == 6 { onComplete() }
                            }
                        } label: {
                            Text(key)
                                .font(.title2)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.modelContext) private var context
    @State private var showAddTransaction = false

    var body: some View {
        @Bindable var vm = appVM

        ZStack(alignment: .bottom) {
            TabView(selection: $vm.selectedTab) {
                Tab("Dashboard", systemImage: "chart.bar.fill", value: AppTab.dashboard) {
                    DashboardView()
                }
                Tab("People", systemImage: "person.2.fill", value: AppTab.people) {
                    PeopleView()
                }
                Tab("Transactions", systemImage: "arrow.left.arrow.right.circle.fill", value: AppTab.transactions) {
                    TransactionsView()
                }
                Tab("Reminders", systemImage: "bell.fill", value: AppTab.reminders) {
                    RemindersView()
                }
                Tab("Reports", systemImage: "doc.text.fill", value: AppTab.reports) {
                    ReportsView()
                }
                Tab("Analytics", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.analytics) {
                    AnalyticsView()
                }
                Tab("Search", systemImage: "magnifyingglass", value: AppTab.search) {
                    SearchView()
                }
                Tab("Archive", systemImage: "archivebox.fill", value: AppTab.archive) {
                    ArchiveView()
                }
                Tab("AI", systemImage: "sparkles", value: AppTab.ai) {
                    AIAssistantView()
                }
                Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                    SettingsView()
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        }
        .onOpenURL { url in
            if let tab = DeepLinkHandler.handle(url: url) {
                appVM.selectedTab = tab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Auto-lock on background
            appVM.isUnlocked = false
        }
    }
}
