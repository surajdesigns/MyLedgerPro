// MARK: - DesignSystem.swift
// MyLedgerPro – Liquid Glass Design System
// iOS 27 / SwiftUI

import SwiftUI

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16
    var tint: Color = .clear
    @ViewBuilder var content: () -> Content
    
    @Environment(\.colorScheme) var scheme
    
    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(0.05))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(scheme == .dark ? 0.15 : 0.6),
                                        Color.white.opacity(scheme == .dark ? 0.05 : 0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    }
            }
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.4 : 0.1), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Glass Button

struct GlassButton: View {
    var title: String
    var icon: String? = nil
    var color: Color = .blue
    var isLoading = false
    var action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            Task {
                await HapticService.shared.impact(.medium)
            }
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    if let icon { Image(systemName: icon) }
                    Text(title).fontWeight(.semibold)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    }
                    .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Glass Nav Bar

struct GlassNavBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

extension View {
    func glassNavBar() -> some View { modifier(GlassNavBackground()) }
}

// MARK: - Stat Card

struct StatCard: View {
    var title: String
    var value: String
    var icon: String
    var color: Color
    var subtitle: String? = nil
    
    var body: some View {
        GlassCard(tint: color) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                        .padding(8)
                        .background(color.opacity(0.15), in: Circle())
                    Spacer()
                }
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(color)
                        .fontWeight(.medium)
                }
            }
        }
    }
}

// MARK: - Person Avatar

struct PersonAvatar: View {
    var person: Person
    var size: CGFloat = 44
    
    var body: some View {
        ZStack {
            if let data = person.photoData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [person.categoryColor, person.categoryColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                
                Text(person.initials)
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        }
        .shadow(color: person.categoryColor.opacity(0.3), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    var transaction: Transaction
    var currencySymbol: String = "₹"
    
    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: transaction.type.icon)
                .font(.title3)
                .foregroundStyle(transaction.type.color)
                .padding(10)
                .background(transaction.type.color.opacity(0.12), in: Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.person?.name ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 6) {
                    Text(transaction.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if !transaction.notes.isEmpty {
                    Text(transaction.notes)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyFormatter.format(transaction.amount, symbol: currencySymbol))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(transaction.type == .received ? .green : .primary)
                
                StatusBadge(status: transaction.status)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    var status: TransactionStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    var title: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "See All"
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            Spacer()
            if let action {
                Button(actionTitle, action: action)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    var icon: String
    var title: String
    var subtitle: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "Add New"
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.secondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let action {
                GlassButton(title: actionTitle, icon: "plus", action: action)
                    .frame(maxWidth: 200)
            }
        }
        .padding(40)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var message: String = "Loading..."
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(.blue)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Floating Action Button

struct FloatingAddButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            Task { await HapticService.shared.impact(.rigid) }
            action()
        }) {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.4), radius: 14, x: 0, y: 6)
                }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Currency Text Field

struct CurrencyTextField: View {
    var title: String
    var symbol: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Text(symbol)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            TextField(title, text: $text)
                .keyboardType(.decimalPad)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Gradient Background

struct AppBackground: View {
    @Environment(\.colorScheme) var scheme
    
    var body: some View {
        ZStack {
            (scheme == .dark ? Color.black : Color(uiColor: .systemGroupedBackground))
                .ignoresSafeArea()
            
            // Subtle gradient blobs
            GeometryReader { geo in
                Circle()
                    .fill(Color.blue.opacity(scheme == .dark ? 0.06 : 0.04))
                    .frame(width: geo.size.width * 0.8)
                    .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.1)
                    .blur(radius: 60)
                
                Circle()
                    .fill(Color.purple.opacity(scheme == .dark ? 0.05 : 0.03))
                    .frame(width: geo.size.width * 0.7)
                    .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.5)
                    .blur(radius: 60)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Person Cell

struct PersonCell: View {
    var person: Person
    var currencySymbol: String = "₹"
    
    var body: some View {
        HStack(spacing: 14) {
            PersonAvatar(person: person)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(person.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(CurrencyFormatter.format(person.pendingAmount, symbol: currencySymbol))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(person.pendingAmount > 0 ? .red : .green)
                }
                
                HStack(spacing: 8) {
                    Label(person.category.rawValue, systemImage: person.category.icon)
                        .font(.caption)
                        .foregroundStyle(person.categoryColor)
                    
                    if person.hasOverdueTransactions {
                        Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Quick Amount Chips

struct QuickAmountChips: View {
    @Binding var amount: String
    let amounts = ["500", "1000", "2000", "5000", "10000"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(amounts, id: \.self) { a in
                    Button("₹\(a)") {
                        amount = a
                        Task { await HapticService.shared.selection() }
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Recovery Gauge

struct RecoveryGauge: View {
    var percentage: Double
    var color: Color = .green
    var size: CGFloat = 80
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: percentage / 100)
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: percentage)
            
            VStack(spacing: 0) {
                Text("\(Int(percentage))%")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Recovery")
                    .font(.system(size: size * 0.12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Reminder Row

struct ReminderRow: View {
    var reminder: Reminder
    var onComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Check button
            Button(action: onComplete) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(reminder.isCompleted ? .green : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .strikethrough(reminder.isCompleted)
                    .foregroundStyle(reminder.isCompleted ? .secondary : .primary)
                
                HStack(spacing: 6) {
                    if let person = reminder.person {
                        Label(person.name, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if reminder.amount > 0 {
                        Text("₹\(reminder.amount.formatted())")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(reminder.dueDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                }
                .foregroundStyle(reminder.isOverdue ? .red : .secondary)
            }
            
            Spacer()
            
            if reminder.isOverdue && !reminder.isCompleted {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Payment Method Selector

struct PaymentMethodPicker: View {
    @Binding var selection: PaymentMethod
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    Button(action: { selection = method }) {
                        Label(method.rawValue, systemImage: method.icon)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selection == method
                                ? Color.blue.opacity(0.2)
                                : Color.clear,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selection == method ? Color.blue : Color.secondary.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                            .foregroundStyle(selection == method ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Trust Score Badge

struct TrustScoreBadge: View {
    var score: Double
    
    var color: Color {
        if score >= 75 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
    
    var label: String {
        if score >= 75 { return "High Trust" }
        if score >= 50 { return "Medium" }
        return "Low Trust"
    }
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Form Field

struct FormField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var icon: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - Bar Chart Component

struct SimpleBarChart: View {
    var data: [DayTotal]
    var showGiven: Bool = true
    var showReceived: Bool = true
    
    var maxVal: Double {
        data.map { max($0.given, $0.received) }.max() ?? 1
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(data.suffix(14)) { day in
                VStack(spacing: 2) {
                    if showGiven {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.red.opacity(0.7))
                            .frame(height: CGFloat(day.given / maxVal) * 60)
                    }
                    if showReceived {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green.opacity(0.7))
                            .frame(height: CGFloat(day.received / maxVal) * 60)
                    }
                }
            }
        }
        .frame(height: 70)
    }
}

// MARK: - Overdue Alert Banner

struct OverdueAlertBanner: View {
    var count: Int
    var amount: Double
    var symbol: String = "₹"
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) Overdue Payment\(count > 1 ? "s" : "")")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Total: \(CurrencyFormatter.format(amount, symbol: symbol))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.red, .red.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}
