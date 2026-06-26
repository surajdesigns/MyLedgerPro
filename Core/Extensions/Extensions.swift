// MARK: - Extensions.swift
// MyLedgerPro – Swift & SwiftUI Extensions

import SwiftUI
import Foundation

// MARK: - Double Extensions

extension Double {
    func formatted(decimalPlaces: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = decimalPlaces
        formatter.minimumFractionDigits = 0
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    
    var inLakhs: Double { self / 100_000 }
    var inThousands: Double { self / 1_000 }
    
    var isPositive: Bool { self > 0 }
    var isNegative: Bool { self < 0 }
    
    func percentage(of total: Double) -> Double {
        guard total > 0 else { return 0 }
        return (self / total) * 100
    }
}

// MARK: - Date Extensions

extension Date {
    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isYesterday: Bool { Calendar.current.isDateInYesterday(self) }
    var isThisWeek: Bool { Calendar.current.isDate(self, equalTo: .now, toGranularity: .weekOfYear) }
    var isThisMonth: Bool { Calendar.current.isDate(self, equalTo: .now, toGranularity: .month) }
    
    var relativeDescription: String {
        if isToday { return "Today" }
        if isYesterday { return "Yesterday" }
        if isThisWeek { return formatted(.dateTime.weekday(.wide)) }
        if isThisMonth { return formatted(.dateTime.day().month(.abbreviated)) }
        return formatted(date: .abbreviated, time: .omitted)
    }
    
    func daysUntil(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: self, to: date).day ?? 0
    }
    
    func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0
    }
    
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    
    var endOfDay: Date {
        var comps = DateComponents()
        comps.hour = 23; comps.minute = 59; comps.second = 59
        return Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: self) ?? self
    }
}

// MARK: - String Extensions

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isNotEmpty: Bool { !isEmpty }
    var isValidPhone: Bool { count >= 10 && allSatisfy({ $0.isNumber || $0 == "+" || $0 == " " || $0 == "-" }) }
    var isValidEmail: Bool { contains("@") && contains(".") }
    
    func localizedStandardContains(_ other: String) -> Bool {
        range(of: other, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

// MARK: - Color Extensions

extension Color {
    static var systemBackground: Color { Color(uiColor: .systemBackground) }
    static var secondarySystemBackground: Color { Color(uiColor: .secondarySystemBackground) }
    static var tertiarySystemBackground: Color { Color(uiColor: .tertiarySystemBackground) }
    static var systemGroupedBackground: Color { Color(uiColor: .systemGroupedBackground) }
    
    func lighter(by amount: Double = 0.2) -> Color {
        self.opacity(1 - amount)
    }
}

// MARK: - View Extensions

extension View {
    func cardShadow(color: Color = .black, opacity: Double = 0.08, radius: CGFloat = 12) -> some View {
        shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 4)
    }
    
    func shimmer(isActive: Bool) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
    
    func onFirstAppear(perform action: @escaping () -> Void) -> some View {
        modifier(OnFirstAppearModifier(action: action))
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
    
    func glassOverlay(cornerRadius: CGFloat = 16) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    var isActive: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay {
                    GeometryReader { geo in
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.5), location: 0.5),
                                .init(color: .clear, location: 1)
                            ]),
                            startPoint: .init(x: phase - 1, y: 0.5),
                            endPoint: .init(x: phase, y: 0.5)
                        )
                        .frame(width: geo.size.width * 3)
                        .offset(x: -(geo.size.width))
                    }
                }
                .clipped()
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 2
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - On First Appear Modifier

struct OnFirstAppearModifier: ViewModifier {
    var action: () -> Void
    @State private var hasAppeared = false
    
    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            action()
        }
    }
}

// MARK: - Number Formatter

extension NumberFormatter {
    static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.groupingSeparator = ","
        f.groupingSize = 3
        return f
    }()
    
    static let percentage: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 1
        return f
    }()
}

// MARK: - UIApplication Extensions

extension UIApplication {
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
    
    func endEditing(_ force: Bool) {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Array Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
    
    var isNotEmpty: Bool { !isEmpty }
}

extension Array where Element: Identifiable {
    func first(withID id: Element.ID) -> Element? {
        first { $0.id == id }
    }
}

// MARK: - Optional Extensions

extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}

extension Optional where Wrapped == Double {
    var orZero: Double { self ?? 0 }
}

// MARK: - Transaction Grouping

extension Array where Element == Transaction {
    func groupedByMonth() -> [(String, [Transaction])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        var dict: [String: [Transaction]] = [:]
        for tx in self {
            let key = formatter.string(from: tx.date)
            dict[key, default: []].append(tx)
        }
        
        return dict.sorted { a, b in
            let fmt = DateFormatter()
            fmt.dateFormat = "MMMM yyyy"
            let d1 = fmt.date(from: a.key) ?? .distantPast
            let d2 = fmt.date(from: b.key) ?? .distantPast
            return d1 > d2
        }
    }
    
    func groupedByPerson() -> [(Person, [Transaction])] {
        var dict: [UUID: [Transaction]] = [:]
        for tx in self {
            guard let person = tx.person else { continue }
            dict[person.id, default: []].append(tx)
        }
        
        return dict.compactMap { (_, txs) -> (Person, [Transaction])? in
            guard let person = txs.first?.person else { return nil }
            return (person, txs)
        }.sorted { $0.0.name < $1.0.name }
    }
}

// MARK: - Formatting Helpers

func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
    let f = DateFormatter()
    f.dateStyle = style
    f.timeStyle = .none
    return f.string(from: date)
}

func formatDateTime(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .short
    return f.string(from: date)
}

func formatRelativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: .now)
}

// MARK: - Haptic Helper (SwiftUI modifier)

struct HapticFeedbackModifier: ViewModifier {
    let style: UIImpactFeedbackGenerator.FeedbackStyle
    
    func body(content: Content) -> some View {
        content.onTapGesture {
            Task { await HapticService.shared.impact(style) }
        }
    }
}

extension View {
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        modifier(HapticFeedbackModifier(style: style))
    }
}

// MARK: - Environment Values

private struct CurrencySymbolKey: EnvironmentKey {
    static let defaultValue = "₹"
}

extension EnvironmentValues {
    var currencySymbol: String {
        get { self[CurrencySymbolKey.self] }
        set { self[CurrencySymbolKey.self] = newValue }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension Person {
    static var preview: Person {
        let p = Person(name: "Rahul Sharma", phone: "+91 98765 43210", category: .friend)
        return p
    }
}

extension Transaction {
    static var preview: Transaction {
        let tx = Transaction(type: .given, amount: 10000, notes: "Personal loan")
        tx.person = Person.preview
        tx.dueDate = Calendar.current.date(byAdding: .month, value: 1, to: .now)
        return tx
    }
}

extension Reminder {
    static var preview: Reminder {
        let r = Reminder(title: "Collect from Rahul", amount: 5000, dueDate: .now.addingTimeInterval(86400))
        r.person = Person.preview
        return r
    }
}
#endif
