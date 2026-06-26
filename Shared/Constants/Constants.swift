// MARK: - Constants.swift
// MyLedgerPro – App Constants & Configuration

import Foundation
import SwiftUI

// MARK: - App Constants

enum AppConstants {
    // App Info
    static let appName         = "My Ledger Pro"
    static let appVersion      = "1.0.0"
    static let bundleID        = "com.myledgerpro.app"
    static let appGroupID      = "group.com.myledgerpro.shared"
    static let widgetKind      = "LedgerWidget"
    
    // Security
    static let lockTimeoutSeconds: Double = 300  // 5 minutes
    static let maxPasscodeAttempts = 5
    
    // Storage
    static let maxPhotoSizeBytes  = 5 * 1024 * 1024   // 5 MB
    static let maxVoiceNoteSecs   = 120                // 2 minutes
    static let backupFilePrefix   = "MyLedgerPro_Backup"
    
    // Notifications
    static let dailyReminderHour   = 9
    static let dailyReminderMinute = 0
    static let overdueCheckHour    = 8
    
    // UI
    static let animationDuration = 0.3
    static let cardCornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 12
    static let maxDisplayTransactions = 50
    
    // Limits
    static let maxTagsPerTransaction = 10
    static let maxNotesLength = 500
    static let maxPeopleDisplayed = 100
    
    // Currencies
    static let availableCurrencies: [(symbol: String, name: String, code: String)] = [
        ("₹", "Indian Rupee", "INR"),
        ("$", "US Dollar",    "USD"),
        ("€", "Euro",         "EUR"),
        ("£", "British Pound","GBP"),
        ("¥", "Japanese Yen", "JPY"),
        ("د.إ", "UAE Dirham", "AED"),
        ("S$", "Singapore $", "SGD"),
        ("A$", "Australian $","AUD"),
        ("C$", "Canadian $",  "CAD"),
        ("CHF","Swiss Franc", "CHF")
    ]
    
    // Quick amounts (INR)
    static let quickAmounts = [500.0, 1000.0, 2000.0, 5000.0, 10000.0, 25000.0, 50000.0]
    
    // Trust score thresholds
    static let trustHigh   = 75.0
    static let trustMedium = 50.0
    
    // Chart display
    static let chartDays7  = 7
    static let chartDays30 = 30
    static let chartMonths = 6
    
    // Recovery thresholds
    static let recoveryGood    = 80.0
    static let recoveryAverage = 50.0
    
    // iCloud keys
    enum iCloud {
        static let settingsKey  = "app_settings"
        static let lastSyncKey  = "last_sync_date"
    }
    
    // Notification categories
    enum NotificationCategory {
        static let paymentReminder   = "PAYMENT_REMINDER"
        static let overdueAlert      = "OVERDUE_ALERT"
        static let dailySummary      = "DAILY_SUMMARY"
    }
    
    // Siri shortcut activity types
    enum ActivityType {
        static let viewDashboard     = "\(bundleID).viewDashboard"
        static let addTransaction    = "\(bundleID).addTransaction"
        static let checkBalance      = "\(bundleID).checkBalance"
    }
    
    // Deep links
    enum DeepLink {
        static let scheme        = "myledgerpro"
        static let dashboard     = "myledgerpro://dashboard"
        static let addPerson     = "myledgerpro://people/add"
        static let addTransaction = "myledgerpro://transactions/add"
        static let reminders     = "myledgerpro://reminders"
        static let reports       = "myledgerpro://reports"
        static let aiAssistant   = "myledgerpro://ai"
    }
}

// MARK: - Design Tokens

enum DesignTokens {
    // Spacing
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    
    // Corner Radii
    static let radiusSmall:  CGFloat = 8
    static let radiusMedium: CGFloat = 14
    static let radiusLarge:  CGFloat = 20
    static let radiusXL:     CGFloat = 28
    static let radiusPill:   CGFloat = 100
    
    // Icon Sizes
    static let iconSmall:  CGFloat = 16
    static let iconMedium: CGFloat = 22
    static let iconLarge:  CGFloat = 32
    static let iconXL:     CGFloat = 48
    
    // Avatar Sizes
    static let avatarSmall:  CGFloat = 32
    static let avatarMedium: CGFloat = 44
    static let avatarLarge:  CGFloat = 64
    static let avatarXL:     CGFloat = 88
    
    // Shadow
    static let shadowRadiusSm:  CGFloat = 4
    static let shadowRadiusMd:  CGFloat = 10
    static let shadowRadiusLg:  CGFloat = 20
    static let shadowOpacityDark  = 0.3
    static let shadowOpacityLight = 0.1
    
    // Animation
    static let springResponse:  Double = 0.35
    static let springDamping:   Double = 0.75
    static let easeOutDuration: Double = 0.25
    
    // Glass
    static let glassBorderOpacityLight = 0.5
    static let glassBorderOpacityDark  = 0.15
    static let glassTintOpacity        = 0.05
}

// MARK: - Color Palette

extension Color {
    // Brand colors
    static let brandBlue   = Color("BrandBlue",   bundle: .main)
    static let brandPurple = Color("BrandPurple", bundle: .main)
    
    // Semantic colors
    static var given:    Color { .red }
    static var received: Color { .green }
    static var pending:  Color { .orange }
    static var overdue:  Color { .red }
    static var settled:  Color { .green }
    
    // Category colors (matching PersonCategory)
    static var familyColor:   Color { .blue }
    static var friendColor:   Color { .green }
    static var businessColor: Color { .orange }
    static var employeeColor: Color { .purple }
    
    // Trust score colors
    static var trustHigh:    Color { .green }
    static var trustMedium:  Color { .orange }
    static var trustLow:     Color { .red }
    
    // Glass colors
    static func glassBackground(scheme: ColorScheme) -> Color {
        scheme == .dark
        ? Color.white.opacity(0.05)
        : Color.white.opacity(0.7)
    }
    
    static func glassBorder(scheme: ColorScheme) -> Color {
        scheme == .dark
        ? Color.white.opacity(DesignTokens.glassBorderOpacityDark)
        : Color.white.opacity(DesignTokens.glassBorderOpacityLight)
    }
}

// MARK: - Typography

enum Typography {
    static let largeTitle  = Font.largeTitle.weight(.bold)
    static let title1      = Font.title.weight(.bold)
    static let title2      = Font.title2.weight(.semibold)
    static let title3      = Font.title3.weight(.semibold)
    static let headline    = Font.headline
    static let subheadline = Font.subheadline
    static let body        = Font.body
    static let callout     = Font.callout
    static let footnote    = Font.footnote
    static let caption1    = Font.caption
    static let caption2    = Font.caption2
    
    static let monoBody    = Font.body.monospaced()
    static let monoCaption = Font.caption.monospaced()
}

// MARK: - Haptic Patterns

enum HapticPattern {
    static func transactionSaved() {
        Task {
            await HapticService.shared.impact(.medium)
            try? await Task.sleep(for: .milliseconds(100))
            await HapticService.shared.impact(.light)
        }
    }
    
    static func paymentReceived() {
        Task {
            await HapticService.shared.success()
            try? await Task.sleep(for: .milliseconds(150))
            await HapticService.shared.impact(.light)
        }
    }
    
    static func error() {
        Task { await HapticService.shared.error() }
    }
    
    static func deleteAction() {
        Task { await HapticService.shared.impact(.heavy) }
    }
}

// MARK: - Feature Flags

enum FeatureFlags {
    static let isAppleWatchEnabled  = false  // Pending watchOS target
    static let isMLPredictionEnabled = false  // Pending CoreML model
    static let isMultiCurrencyEnabled = true
    static let isDynamicIslandEnabled = true
    static let isVoiceInputEnabled    = true
    static let isLocationEnabled      = false // Requires additional permission handling
    static let isShareExtensionEnabled = false // Pending Share Extension target
    static let isCloudKitEnabled       = true
    
    // AB testing
    static let useNewDashboardLayout  = true
    static let useAnimatedCharts      = true
    static let showRecoveryGauge      = true
}

// MARK: - Error Types

enum AppError: LocalizedError {
    case databaseSaveFailed
    case personNotFound
    case transactionNotFound
    case invalidAmount
    case notificationPermissionDenied
    case exportFailed
    case backupFailed
    case authenticationFailed
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .databaseSaveFailed:           return "Failed to save data. Please try again."
        case .personNotFound:               return "Person not found."
        case .transactionNotFound:          return "Transaction not found."
        case .invalidAmount:                return "Please enter a valid amount."
        case .notificationPermissionDenied: return "Notification permission is required. Please enable it in Settings."
        case .exportFailed:                 return "Export failed. Please try again."
        case .backupFailed:                 return "Backup failed. Please check your iCloud connection."
        case .authenticationFailed:         return "Authentication failed. Please try again."
        case .unknownError(let msg):        return msg
        }
    }
    
    var icon: String {
        switch self {
        case .databaseSaveFailed:           return "externaldrive.badge.exclamationmark"
        case .personNotFound:               return "person.badge.xmark"
        case .transactionNotFound:          return "doc.badge.exclamationmark"
        case .invalidAmount:                return "indianrupeesign.circle.badge.exclamationmark"
        case .notificationPermissionDenied: return "bell.slash.fill"
        case .exportFailed:                 return "square.and.arrow.up.trianglebadge.exclamationmark"
        case .backupFailed:                 return "icloud.slash.fill"
        case .authenticationFailed:         return "faceid"
        case .unknownError:                 return "exclamationmark.triangle.fill"
        }
    }
}
