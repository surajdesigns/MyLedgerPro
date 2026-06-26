// MARK: - AddSheets.swift
// MyLedgerPro – Add/Edit Sheets

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Add Transaction Sheet

struct AddTransactionSheet: View {
    var preselectedPerson: Person? = nil
    var currencySymbol: String = "₹"
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var vm = AddTransactionViewModel()
    @State private var showPersonPicker = false
    @State private var showReceiptPicker = false
    @State private var showBillPicker = false
    @State private var receiptItem: PhotosPickerItem?
    @State private var billItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Type selector
                        typeSelector
                        
                        // Amount
                        amountSection
                        
                        // Person
                        personSection
                        
                        // Date & Method
                        dateAndMethodSection
                        
                        // Due date toggle
                        dueDateSection
                        
                        // Reminder
                        reminderSection
                        
                        // Notes & Tags
                        notesSection
                        
                        // Photos
                        photosSection
                        
                        // Error
                        if let error = vm.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }
                        
                        // Save button
                        GlassButton(
                            title: "Save Transaction",
                            icon: "checkmark.circle.fill",
                            color: .blue,
                            isLoading: vm.isLoading
                        ) {
                            vm.save(
                                txRepo: TransactionRepository(context: context),
                                reminderRepo: ReminderRepository(context: context)
                            )
                        }
                        .padding(.horizontal)
                        .disabled(!vm.isValid)
                        .opacity(vm.isValid ? 1 : 0.6)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .glassNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let p = preselectedPerson { vm.selectedPerson = p }
            }
            .onChange(of: vm.didSave) { _, saved in
                if saved { dismiss() }
            }
            .onChange(of: receiptItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        vm.receiptImage = img
                    }
                }
            }
            .onChange(of: billItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        vm.billImage = img
                    }
                }
            }
        }
    }
    
    // MARK: - Type Selector
    
    private var typeSelector: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Transaction Type")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 0) {
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        Button {
                            vm.type = type
                            Task { await HapticService.shared.selection() }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.title3)
                                Text(type.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                vm.type == type
                                ? type.color.opacity(0.18)
                                : Color.clear,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .foregroundStyle(vm.type == type ? type.color : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Amount
    
    private var amountSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Amount")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                CurrencyTextField(title: "0.00", symbol: currencySymbol, text: $vm.amount)
                
                QuickAmountChips(amount: $vm.amount)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Person
    
    private var personSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Person")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Button {
                    showPersonPicker = true
                } label: {
                    HStack {
                        if let person = vm.selectedPerson {
                            PersonAvatar(person: person, size: 32)
                            Text(person.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        } else {
                            Image(systemName: "person.badge.plus")
                                .foregroundStyle(.blue)
                            Text("Select Person")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showPersonPicker) {
            PersonPickerSheet(selected: $vm.selectedPerson)
        }
    }
    
    // MARK: - Date & Method
    
    private var dateAndMethodSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                DatePicker("Date & Time", selection: $vm.date)
                    .font(.subheadline)
                
                Divider().opacity(0.4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Payment Method")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    PaymentMethodPicker(selection: $vm.paymentMethod)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Due Date
    
    private var dueDateSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $vm.hasDueDate) {
                    Label("Set Due Date", systemImage: "calendar.badge.clock")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .tint(.blue)
                
                if vm.hasDueDate {
                    DatePicker("Due Date", selection: $vm.dueDate, displayedComponents: .date)
                        .font(.subheadline)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.3), value: vm.hasDueDate)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Reminder
    
    private var reminderSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $vm.hasReminder) {
                    Label("Set Reminder", systemImage: "bell.badge.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .tint(.orange)
                
                if vm.hasReminder {
                    DatePicker("Remind On", selection: $vm.reminderDate)
                        .font(.subheadline)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.3), value: vm.hasReminder)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Notes
    
    private var notesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                FormField(title: "Notes", placeholder: "Add notes...", text: $vm.notes, icon: "note.text")
                FormField(title: "Tags", placeholder: "loan, personal, urgent (comma separated)", text: $vm.tags, icon: "tag.fill")
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Photos
    
    private var photosSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Documents & Photos")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 14) {
                    PhotosPickerWrapper(item: $receiptItem, image: vm.receiptImage, title: "Receipt")
                    PhotosPickerWrapper(item: $billItem, image: vm.billImage, title: "Bill")
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Photos Picker Wrapper

struct PhotosPickerWrapper: View {
    @Binding var item: PhotosPickerItem?
    var image: UIImage?
    var title: String
    
    var body: some View {
        PhotosPicker(selection: $item, matching: .images) {
            VStack(spacing: 6) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.08))
                        .frame(width: 70, height: 60)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .foregroundStyle(.blue.opacity(0.6))
                        }
                }
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Person Picker Sheet

struct PersonPickerSheet: View {
    @Binding var selected: Person?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var people: [Person] = []
    @State private var searchText = ""
    @State private var showAddPerson = false
    
    var filtered: [Person] {
        if searchText.isEmpty { return people }
        let q = searchText.lowercased()
        return people.filter { $0.name.lowercased().contains(q) || $0.phone.lowercased().contains(q) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                List {
                    ForEach(filtered) { person in
                        Button {
                            selected = person
                            Task { await HapticService.shared.selection() }
                            dismiss()
                        } label: {
                            HStack {
                                PersonCell(person: person)
                                Spacer()
                                if selected?.id == person.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Person")
            .navigationBarTitleDisplayMode(.inline)
            .glassNavBar()
            .searchable(text: $searchText, prompt: "Search people...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("New Person", systemImage: "plus") {
                        showAddPerson = true
                    }
                }
            }
            .onAppear {
                people = (try? PersonRepository(context: context).fetchAll()) ?? []
            }
            .sheet(isPresented: $showAddPerson, onDismiss: {
                people = (try? PersonRepository(context: context).fetchAll()) ?? []
            }) {
                AddPersonSheet()
            }
        }
    }
}

// MARK: - Add Person Sheet

struct AddPersonSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var vm = AddPersonViewModel()
    @State private var photoItem: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Photo
                        photoSection
                        
                        // Basic info
                        basicInfoCard
                        
                        // Category
                        categoryCard
                        
                        // Notes
                        GlassCard {
                            FormField(title: "Notes", placeholder: "Any notes about this person...", text: $vm.notes, icon: "note.text")
                        }
                        .padding(.horizontal)
                        
                        if let error = vm.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        
                        GlassButton(
                            title: "Save Person",
                            icon: "person.badge.plus",
                            color: .blue,
                            isLoading: vm.isLoading
                        ) {
                            vm.save(repo: PersonRepository(context: context))
                        }
                        .padding(.horizontal)
                        .disabled(!vm.isValid)
                        .opacity(vm.isValid ? 1 : 0.6)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .glassNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: vm.didSave) { _, saved in
                if saved { dismiss() }
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        vm.photo = img
                    }
                }
            }
        }
    }
    
    private var photoSection: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack {
                    if let photo = vm.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 90, height: 90)
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue.opacity(0.7))
                            }
                    }
                    
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 90, height: 90)
                }
            }
            .buttonStyle(.plain)
            
            Text("Tap to add photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var basicInfoCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                FormField(title: "Full Name *", placeholder: "Enter full name", text: $vm.name, icon: "person.fill")
                Divider().opacity(0.4)
                FormField(title: "Phone Number", placeholder: "+91 XXXXX XXXXX", text: $vm.phone, keyboardType: .phonePad, icon: "phone.fill")
                Divider().opacity(0.4)
                FormField(title: "Email", placeholder: "email@example.com", text: $vm.email, keyboardType: .emailAddress, icon: "envelope.fill")
                Divider().opacity(0.4)
                FormField(title: "Address", placeholder: "Enter address", text: $vm.address, icon: "mappin.fill")
            }
        }
        .padding(.horizontal)
    }
    
    private var categoryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Category")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 0) {
                    ForEach(PersonCategory.allCases, id: \.self) { cat in
                        Button {
                            vm.category = cat
                            Task { await HapticService.shared.selection() }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.title3)
                                Text(cat.rawValue)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                vm.category == cat ? cat.color.opacity(0.18) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .foregroundStyle(vm.category == cat ? cat.color : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Add Partial Payment Sheet

struct AddPartialPaymentSheet: View {
    var transaction: Transaction
    var currencySymbol: String = "₹"
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var date = Date.now
    @State private var method: PaymentMethod = .cash
    @State private var notes = ""
    @State private var isLoading = false
    
    var maxAmount: Double { transaction.pendingAmount }
    var enteredAmount: Double { Double(amount) ?? 0 }
    var isValid: Bool { enteredAmount > 0 && enteredAmount <= maxAmount }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Pending info
                        GlassCard(tint: .orange) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total Amount")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(CurrencyFormatter.format(transaction.amount, symbol: currencySymbol))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Still Pending")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(CurrencyFormatter.format(maxAmount, symbol: currencySymbol))
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Amount
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Payment Amount")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                
                                CurrencyTextField(title: "0.00", symbol: currencySymbol, text: $amount)
                                
                                // Quick full payment button
                                Button("Pay Full Amount (\(CurrencyFormatter.format(maxAmount, symbol: currencySymbol)))") {
                                    amount = "\(Int(maxAmount))"
                                    Task { await HapticService.shared.selection() }
                                }
                                .font(.caption)
                                .foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Date and method
                        GlassCard {
                            VStack(spacing: 14) {
                                DatePicker("Payment Date", selection: $date)
                                    .font(.subheadline)
                                
                                Divider().opacity(0.4)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Payment Method")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                    PaymentMethodPicker(selection: $method)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        GlassCard {
                            FormField(title: "Notes", placeholder: "Add notes...", text: $notes, icon: "note.text")
                        }
                        .padding(.horizontal)
                        
                        GlassButton(
                            title: "Record Payment",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            isLoading: isLoading
                        ) {
                            save()
                        }
                        .padding(.horizontal)
                        .disabled(!isValid)
                        .opacity(isValid ? 1 : 0.6)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .glassNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func save() {
        guard isValid else { return }
        isLoading = true
        let payment = PartialPayment(
            amount: enteredAmount,
            date: date,
            paymentMethod: method,
            notes: notes
        )
        let repo = TransactionRepository(context: context)
        Task {
            try? repo.addPartialPayment(payment, to: transaction)
            isLoading = false
            dismiss()
        }
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    var person: Person
    var currencySymbol: String = "₹"
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var shareItem: Any?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                VStack(spacing: 20) {
                    Text("Export Statement")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    Text("Choose export format for \(person.name)'s account")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Summary card
                    GlassCard {
                        VStack(spacing: 12) {
                            statRow("Total Transactions", "\(person.transactions.filter { !$0.isDeleted }.count)")
                            Divider().opacity(0.4)
                            statRow("Total Given", CurrencyFormatter.format(person.totalGiven, symbol: currencySymbol))
                            Divider().opacity(0.4)
                            statRow("Total Received", CurrencyFormatter.format(person.totalReceived, symbol: currencySymbol))
                            Divider().opacity(0.4)
                            statRow("Pending", CurrencyFormatter.format(person.pendingAmount, symbol: currencySymbol))
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        GlassButton(title: "Export as PDF", icon: "doc.fill", color: .red) {
                            exportPDF()
                        }
                        
                        GlassButton(title: "Export as CSV", icon: "tablecells.fill", color: .green) {
                            exportCSV()
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .glassNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let item = shareItem {
                    ShareSheet(activityItems: [item])
                }
            }
        }
    }
    
    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
    
    private func exportPDF() {
        let data = ExportService.shared.generatePDFStatement(for: person, currencySymbol: currencySymbol)
        if let url = ExportService.shared.writeToTemp(data: data, filename: "\(person.name)_Statement.pdf") {
            shareItem = url
            showShareSheet = true
        }
    }
    
    private func exportCSV() {
        let csv = ExportService.shared.generateCSV(for: person)
        if let data = csv.data(using: .utf8),
           let url = ExportService.shared.writeToTemp(data: data, filename: "\(person.name)_Statement.csv") {
            shareItem = url
            showShareSheet = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Add Reminder Sheet

struct AddReminderSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var amount = ""
    @State private var dueDate = Date.now.addingTimeInterval(86400)
    @State private var repeatSchedule: RepeatSchedule = .none
    @State private var reminderType: ReminderType = .paymentDue
    @State private var selectedPerson: Person?
    @State private var showPersonPicker = false
    @State private var isLoading = false
    
    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        GlassCard {
                            VStack(spacing: 14) {
                                FormField(title: "Reminder Title *", placeholder: "e.g. Collect from Rahul", text: $title, icon: "bell.fill")
                                Divider().opacity(0.4)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Amount (optional)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                    CurrencyTextField(title: "0.00", symbol: "₹", text: $amount)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        GlassCard {
                            Button {
                                showPersonPicker = true
                            } label: {
                                HStack {
                                    if let person = selectedPerson {
                                        PersonAvatar(person: person, size: 28)
                                        Text(person.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                    } else {
                                        Image(systemName: "person.badge.plus")
                                            .foregroundStyle(.blue)
                                        Text("Link to Person (optional)")
                                            .font(.subheadline)
                                            .foregroundStyle(.blue)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        
                        GlassCard {
                            VStack(spacing: 14) {
                                DatePicker("Due Date & Time", selection: $dueDate)
                                    .font(.subheadline)
                                
                                Divider().opacity(0.4)
                                
                                Picker("Repeat", selection: $repeatSchedule) {
                                    ForEach(RepeatSchedule.allCases, id: \.self) { schedule in
                                        Text(schedule.rawValue).tag(schedule)
                                    }
                                }
                                .pickerStyle(.segmented)
                                
                                Divider().opacity(0.4)
                                
                                Picker("Type", selection: $reminderType) {
                                    ForEach(ReminderType.allCases, id: \.self) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .padding(.horizontal)
                        
                        GlassButton(title: "Create Reminder", icon: "bell.badge.fill", color: .orange, isLoading: isLoading) {
                            save()
                        }
                        .padding(.horizontal)
                        .disabled(!isValid)
                        .opacity(isValid ? 1 : 0.6)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .glassNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showPersonPicker) {
                PersonPickerSheet(selected: $selectedPerson)
            }
        }
    }
    
    private func save() {
        guard isValid else { return }
        isLoading = true
        let reminder = Reminder(
            title: title.trimmingCharacters(in: .whitespaces),
            amount: Double(amount) ?? 0,
            dueDate: dueDate,
            repeatSchedule: repeatSchedule,
            reminderType: reminderType
        )
        reminder.person = selectedPerson
        let repo = ReminderRepository(context: context)
        Task {
            try? repo.save(reminder)
            let nid = NotificationService.shared.scheduleReminder(reminder)
            reminder.notificationIDs = [nid]
            try? repo.save(reminder)
            await HapticService.shared.success()
            SoundService.shared.play(.transactionAdded)
            isLoading = false
            dismiss()
        }
    }
}
