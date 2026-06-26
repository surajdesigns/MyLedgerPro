# My Ledger Pro — Xcode Setup Guide

## Quick Start (5 minutes)

### Step 1 — Open Project
```
Double-click: MyLedgerPro.xcodeproj
```

### Step 2 — Add Source Files to Xcode

Xcode may not auto-detect all files. If missing, drag & drop each folder:
- `App/` → into Xcode project navigator
- `Core/` → into Xcode project navigator
- `Features/` → into Xcode project navigator
- `Shared/` → into Xcode project navigator
- `SiriShortcuts/` → into Xcode project navigator

Add to **MyLedgerPro target** (not LedgerWidget):
- AppRoot.swift, Models.swift, Repositories.swift, Services.swift,
  BackupManager.swift, ViewModels.swift, Extensions.swift,
  DesignSystem.swift, Constants.swift, MainViews.swift,
  AddSheets.swift, SecondaryViews.swift, SiriShortcuts.swift

Add to **LedgerWidget target** only:
- LedgerWidget.swift

### Step 3 — Configure Signing
1. Select `MyLedgerPro` target → Signing & Capabilities
2. Set **Team** to your Apple Developer account
3. Bundle ID: `com.myledgerpro.app`
4. Select `LedgerWidget` target → same team
5. Bundle ID: `com.myledgerpro.app.LedgerWidget`

### Step 4 — Add Capabilities (MyLedgerPro target)
Click `+` in Signing & Capabilities:
- ✅ iCloud → enable CloudKit → add container `iCloud.com.myledgerpro.app`
- ✅ App Groups → add `group.com.myledgerpro.shared`
- ✅ Siri
- ✅ Push Notifications
- ✅ Background Modes → Remote notifications

### Step 5 — Add Capabilities (LedgerWidget target)
- ✅ App Groups → add `group.com.myledgerpro.shared`

### Step 6 — Add Frameworks (MyLedgerPro target)
In Build Phases → Link Binary With Libraries, add:
- SwiftData.framework
- WidgetKit.framework
- AppIntents.framework
- Charts.framework
- LocalAuthentication.framework
- UserNotifications.framework
- PhotosUI.framework
- AVFoundation.framework
- AudioToolbox.framework

> Note: All frameworks are built-in Apple frameworks. No SPM packages needed.

### Step 7 — Assets
1. Drag `Resources/Assets.xcassets` into project
2. Set it as asset catalog in both targets
3. The `AppIcon.png` is included — add it in the AppIcon slot

### Step 8 — Info.plist
1. In MyLedgerPro target → Build Settings → search "Info.plist File"
2. Set to: `Resources/Info.plist`
3. Set `GENERATE_INFOPLIST_FILE` = NO

### Step 9 — Entitlements
1. MyLedgerPro target → Build Settings → search "Code Signing Entitlements"
2. Set to: `Resources/MyLedgerPro.entitlements`
3. LedgerWidget target → `Resources/LedgerWidget.entitlements`

### Step 10 — Build & Run
Select iPhone 15 Pro simulator (iOS 17+) → ⌘R

---

## Troubleshooting

**"Cannot find type 'AppViewModel'"**  
→ Make sure AppRoot.swift is added to the MyLedgerPro target

**"Module 'SwiftData' not found"**  
→ Set deployment target to iOS 17.0+

**"Redeclaration of ..."**  
→ Check a file isn't accidentally added to both targets

**Widget not appearing**  
→ Build LedgerWidget scheme separately, then add to main app via embed

**Face ID on simulator**  
→ Simulator → Features → Face ID → Enrolled

---

## Architecture Notes

```
AppRoot.swift
  └── MyLedgerProApp (@main)
       └── ContentView (lock gate)
            ├── LockScreenView (unauthenticated)
            └── MainTabView (authenticated)
                 ├── DashboardView
                 ├── PeopleView
                 ├── TransactionsView
                 ├── RemindersView
                 ├── ReportsView
                 ├── AnalyticsView
                 ├── SearchView
                 ├── ArchiveView
                 ├── AIAssistantView
                 └── SettingsView
```

## Default Passcode (Demo)
Lock screen → "Use Passcode" → enter any 6 digits
(After 2 failed attempts, access is auto-granted for demo)
For production: implement real passcode hash in AppSettings.

---
Built with Swift 6 + SwiftUI + SwiftData
iOS 17+ | Xcode 15.4+
