import SwiftUI
import AppKit
import ParceliteCore

struct ContentView: View {
    @EnvironmentObject var store: TrackingStore
    @State private var newNumber = ""
    @State private var newLabel = ""
    @State private var showSettings = false
    @State private var showAdd = false
    @FocusState private var addFocused: Bool
    @State private var detectedClipboardNumber: String? = nil

    enum ListFilter {
        case active
        case archived
    }

    @State private var filter: ListFilter = .active
    @State private var searchText = ""


    private var filteredPackages: [Package] {
        store.packages.filter { p in
            let matchesFilter: Bool
            switch filter {
            case .active: matchesFilter = !p.isArchived
            case .archived: matchesFilter = p.isArchived
            }
            if !matchesFilter { return false }
            if searchText.isEmpty { return true }
            let query = searchText.lowercased()
            return p.label.lowercased().contains(query) || p.trackingNumber.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showSettings || store.apiKey.isEmpty {
                SettingsView().environmentObject(store)
                Divider()
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search label or tracking number...", text: $searchText)
                    .textFieldStyle(.plain)
                    .controlSize(.small)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))

            Picker("", selection: $filter) {
                Text("Active (\(store.packages.filter { !$0.isArchived }.count))").tag(ListFilter.active)
                Text("Archived (\(store.packages.filter { $0.isArchived }.count))").tag(ListFilter.archived)
            }
            .pickerStyle(.segmented)
            .controlSize(.small)

            if let clipboardNumber = detectedClipboardNumber {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Found tracking number in clipboard:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(clipboardNumber)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    Button("Add") {
                        store.add(label: "", trackingNumber: clipboardNumber)
                        withAnimation {
                            detectedClipboardNumber = nil
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    Button("Dismiss") {
                        withAnimation {
                            detectedClipboardNumber = nil
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
                .transition(.slide.combined(with: .opacity))
            }

            if filteredPackages.isEmpty {
                HStack {
                    Spacer()
                    Text(filter == .active ? "No active packages" : "No archived packages")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Spacer()
                }.padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(filteredPackages) { p in
                            PackageRow(package: p)
                        }
                    }
                }
            }

            if showAdd {
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    TextField("Label (optional)", text: $newLabel)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    HStack(spacing: 6) {
                        TextField("Tracking number", text: $newNumber)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                            .focused($addFocused)
                            .onSubmit(addCurrent)
                        Button("Add", action: addCurrent)
                            .controlSize(.small)
                            .disabled(TrackingStore.normalizedTrackingNumber(newNumber).isEmpty)
                    }
                    if let error = store.inputError {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }

            Divider()
            HStack(spacing: 10) {
                Button {
                    showAdd.toggle()
                    if showAdd { DispatchQueue.main.async { addFocused = true } }
                } label: {
                    Image(systemName: showAdd ? "minus.circle" : "plus.circle")
                }.buttonStyle(.borderless).help(showAdd ? "Hide add form" : "Add package")

                if store.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Button { Task { await store.refreshAll() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }.buttonStyle(.borderless).help("Refresh")
                }

                Button { showSettings.toggle() } label: {
                    Image(systemName: "gearshape")
                }.buttonStyle(.borderless).help("Settings")

                Button { NSApp.terminate(nil) } label: {
                    Image(systemName: "power")
                        .foregroundColor(.red)
                }.buttonStyle(.borderless).help("Quit")

                Spacer()
            }
            .font(.callout)
        }
        .padding(12)
        .frame(minWidth: 360, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity, alignment: .top)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkClipboard()
        }
    }

    private func addCurrent() {
        let result = store.add(label: newLabel, trackingNumber: newNumber)
        if case .added = result {
            newNumber = ""
            newLabel = ""
        }
    }

    private func checkClipboard() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else { return }
        let normalized = TrackingStore.normalizedTrackingNumber(clipboardString)
        guard TrackingStore.isValidTrackingNumber(normalized) else { return }

        // Check if already tracking this number
        let exists = store.packages.contains { p in
            TrackingStore.normalizedTrackingNumber(p.trackingNumber).caseInsensitiveCompare(normalized) == .orderedSame
        }

        if !exists {
            withAnimation {
                detectedClipboardNumber = normalized
            }
        }
    }
}

struct PackageRow: View {
    let package: Package
    @EnvironmentObject var store: TrackingStore
    @State private var expanded = false

    private var tint: Color {
        switch package.milestone {
        case .delivered: return .green
        case .exception, .failedAttempt: return .red
        case .outForDelivery, .availableForPickup: return .orange
        default: return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 6, height: 6)
                Text(package.label)
                    .font(.caption).fontWeight(.semibold).lineLimit(1)
                Text("·").foregroundStyle(.secondary).font(.caption2)
                Text(package.milestone.displayName)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 4)
                if let e = package.lastError {
                    Text(e).font(.caption2).foregroundStyle(.red).lineLimit(1)
                }
                Menu {
                    Button("Refresh") { Task { await store.refresh(package.id) } }
                    Button("Copy tracking number") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(package.trackingNumber, forType: .string)
                    }
                    if package.isArchived {
                        Button("Unarchive") { store.unarchive(package.id) }
                    } else {
                        Button("Archive") { store.archive(package.id) }
                    }
                    Button("Delete", role: .destructive) { store.remove(package.id) }
                } label: {
                    Image(systemName: "ellipsis").font(.caption2)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .frame(width: 14)
            }

            ProgressView(value: package.milestone.progress)
                .progressViewStyle(.linear)
                .tint(tint)
                .scaleEffect(x: 1, y: 0.7, anchor: .center)

            if expanded {
                Text(package.trackingNumber)
                    .font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                if let c = package.courier, !c.isEmpty {
                    Text(c).font(.caption2).foregroundStyle(.secondary)
                }
                if !package.events.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(package.events) { ev in
                            HStack(alignment: .top, spacing: 4) {
                                Text("•").foregroundStyle(.secondary).font(.caption2)
                                Text(ev.status).font(.caption2).lineLimit(1)
                                Spacer(minLength: 4)
                                if let dt = ev.datetime {
                                    Text(String(dt.prefix(16)).replacingOccurrences(of: "T", with: " "))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: TrackingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings").font(.caption).foregroundStyle(.secondary)
            Text("Ship24 API key").font(.caption2)
            SecureField("Bearer token", text: $store.apiKey)
                .textFieldStyle(.roundedBorder)
            Text("Create a Ship24 API key at ship24.com. Parcelite supports Ship24's carrier network, including InPost, DPD, DHL, GLS, Poczta Polska, Orlen Paczka, and many others.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
