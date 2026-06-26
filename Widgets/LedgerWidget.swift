// MARK: - Widgets.swift
// MyLedgerPro – WidgetKit Extension
// Add this to a separate Widget Extension target in Xcode

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Widget Timeline Entry

struct LedgerEntry: TimelineEntry {
    let date: Date
    let totalPending: Double
    let overdueCount: Int
    let overdueAmount: Double
    let totalGiven: Double
    let totalReceived: Double
    let upcomingReminders: Int
    let currencySymbol: String
}

// MARK: - Timeline Provider

struct LedgerTimelineProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> LedgerEntry {
        LedgerEntry(
            date: .now,
            totalPending: 50000,
            overdueCount: 2,
            overdueAmount: 15000,
            totalGiven: 100000,
            totalReceived: 50000,
            upcomingReminders: 3,
            currencySymbol: "₹"
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LedgerEntry) -> Void) {
        let entry = LedgerEntry(
            date: .now,
            totalPending: 50000,
            overdueCount: 2,
            overdueAmount: 15000,
            totalGiven: 100000,
            totalReceived: 50000,
            upcomingReminders: 3,
            currencySymbol: "₹"
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LedgerEntry>) -> Void) {
        // In production: read from shared UserDefaults/App Group
        // to get real data from the main app.
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadEntry() -> LedgerEntry {
        // Read from App Group shared storage
        let defaults = UserDefaults(suiteName: "group.com.myledgerpro.shared")
        let pending     = defaults?.double(forKey: "totalPending") ?? 0
        let overdueAmt  = defaults?.double(forKey: "overdueAmount") ?? 0
        let overdueCount = defaults?.integer(forKey: "overdueCount") ?? 0
        let given       = defaults?.double(forKey: "totalGiven") ?? 0
        let received    = defaults?.double(forKey: "totalReceived") ?? 0
        let reminders   = defaults?.integer(forKey: "upcomingReminders") ?? 0
        let symbol      = defaults?.string(forKey: "currencySymbol") ?? "₹"
        
        return LedgerEntry(
            date: .now,
            totalPending: pending,
            overdueCount: overdueCount,
            overdueAmount: overdueAmt,
            totalGiven: given,
            totalReceived: received,
            upcomingReminders: reminders,
            currencySymbol: symbol
        )
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    var entry: LedgerEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "indianrupeesign.circle.fill")
                    .foregroundStyle(.blue)
                Text("Ledger Pro")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("Pending")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(CurrencyFormatter.formatCompact(entry.totalPending, symbol: entry.currencySymbol))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(entry.totalPending > 0 ? .orange : .green)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            
            if entry.overdueCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text("\(entry.overdueCount) overdue")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            } else {
                Label("All good", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            ContainerRelativeShape()
                .fill(.ultraThinMaterial)
        )
        .widgetURL(URL(string: "myledgerpro://dashboard"))
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    var entry: LedgerEntry
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .foregroundStyle(.blue)
                    Text("My Ledger Pro")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Pending")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.formatCompact(entry.totalPending, symbol: entry.currencySymbol))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }
                
                if entry.overdueCount > 0 {
                    Label("\(entry.overdueCount) overdue", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                statRow("Given", value: CurrencyFormatter.formatCompact(entry.totalGiven, symbol: entry.currencySymbol), color: .red)
                statRow("Received", value: CurrencyFormatter.formatCompact(entry.totalReceived, symbol: entry.currencySymbol), color: .green)
                statRow("Reminders", value: "\(entry.upcomingReminders)", color: .blue)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ContainerRelativeShape()
                .fill(.ultraThinMaterial)
        )
        .widgetURL(URL(string: "myledgerpro://dashboard"))
    }
    
    private func statRow(_ label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    var entry: LedgerEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .foregroundStyle(.blue)
                Text("My Ledger Pro")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                widgetStat("Total Given", CurrencyFormatter.formatCompact(entry.totalGiven, symbol: entry.currencySymbol), .red, "arrow.up.circle.fill")
                widgetStat("Received", CurrencyFormatter.formatCompact(entry.totalReceived, symbol: entry.currencySymbol), .green, "arrow.down.circle.fill")
                widgetStat("Pending", CurrencyFormatter.formatCompact(entry.totalPending, symbol: entry.currencySymbol), .orange, "clock.fill")
                widgetStat("Overdue", "\(entry.overdueCount)", .red, "exclamationmark.triangle.fill")
            }
            
            Divider()
            
            if entry.overdueCount > 0 {
                Label("\(entry.overdueCount) overdue payment(s) — \(CurrencyFormatter.formatCompact(entry.overdueAmount, symbol: entry.currencySymbol)) pending", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Label("All payments on track!", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            
            if entry.upcomingReminders > 0 {
                Label("\(entry.upcomingReminders) upcoming reminder(s)", systemImage: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            ContainerRelativeShape()
                .fill(.ultraThinMaterial)
        )
        .widgetURL(URL(string: "myledgerpro://dashboard"))
    }
    
    private func widgetStat(_ title: String, _ value: String, _ color: Color, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Lock Screen Widget (Accessory)

struct LockScreenWidgetView: View {
    var entry: LedgerEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "indianrupeesign")
                        .font(.caption2)
                    Text(CurrencyFormatter.formatCompact(entry.totalPending, symbol: ""))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.5)
                }
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Pending")
                        .font(.caption2)
                    Text(CurrencyFormatter.formatCompact(entry.totalPending, symbol: entry.currencySymbol))
                        .font(.headline)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
        case .accessoryInline:
            Label(
                "Pending: \(CurrencyFormatter.formatCompact(entry.totalPending, symbol: entry.currencySymbol))",
                systemImage: "indianrupeesign.circle"
            )
        default:
            Text("Ledger")
        }
    }
}

// MARK: - Widget Bundle

struct LedgerWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: LedgerEntry
    
    var body: some View {
        switch family {
        case .systemSmall:  SmallWidgetView(entry: entry)
        case .systemMedium: MediumWidgetView(entry: entry)
        case .systemLarge:  LargeWidgetView(entry: entry)
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            LockScreenWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct LedgerWidget: Widget {
    let kind: String = "LedgerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LedgerTimelineProvider()) { entry in
            LedgerWidgetView(entry: entry)
        }
        .configurationDisplayName("My Ledger Pro")
        .description("Track your pending payments and balances.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

@main
struct LedgerWidgetBundle: WidgetBundle {
    var body: some Widget {
        LedgerWidget()
    }
}

// MARK: - App Group Data Sync (call from main app)

/// Call this from the main app whenever data changes to update widgets
struct WidgetDataSync {
    static func update(
        totalPending: Double,
        overdueCount: Int,
        overdueAmount: Double,
        totalGiven: Double,
        totalReceived: Double,
        upcomingReminders: Int,
        currencySymbol: String = "₹"
    ) {
        let defaults = UserDefaults(suiteName: "group.com.myledgerpro.shared")
        defaults?.set(totalPending,      forKey: "totalPending")
        defaults?.set(overdueAmount,     forKey: "overdueAmount")
        defaults?.set(overdueCount,      forKey: "overdueCount")
        defaults?.set(totalGiven,        forKey: "totalGiven")
        defaults?.set(totalReceived,     forKey: "totalReceived")
        defaults?.set(upcomingReminders, forKey: "upcomingReminders")
        defaults?.set(currencySymbol,    forKey: "currencySymbol")
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}
