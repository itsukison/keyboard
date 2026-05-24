import KeyboardPreferences
import SwiftUI
import UIKit

struct ProfileScreen: View {
    @EnvironmentObject private var session: UserSession
    @ObservedObject private var stats = ConversionStats.shared
    @State private var compositionDisplayMode = KeyboardSettingsStore.readCompositionDisplayMode()
    @State private var lastConfirmedCompositionDisplayMode = KeyboardSettingsStore.readCompositionDisplayMode()
    @State private var showPersonalInfo = false
    @State private var phraseCount: Int = UserDictionaryStore.readEntries().count
    @State private var showSignOutConfirm = false
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ProfileTopControls()
                        .padding(.top, BikeyMetrics.Spacing.s)

                    ProfileCard(displayName: session.displayName, stats: stats, phraseCount: phraseCount)
                        .padding(.top, BikeyMetrics.Spacing.l - 4)

                    ProfileSectionTitle("Account")
                        .padding(.top, BikeyMetrics.Spacing.l + 2)

                    ProfileListCard(
                        rows: [
                            .init(
                                icon: "person",
                                title: "Personal Information",
                                action: { showPersonalInfo = true }
                            ),
                            .init(
                                icon: "character.cursor.ibeam",
                                title: "Language Mode",
                                toggle: .languageMode
                            ),
                            .init(icon: "crown", title: "Plan", trailing: "Bikey Pro"),
                            .init(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: "Sign Out",
                                action: { showSignOutConfirm = true }
                            )
                        ],
                        compositionDisplayMode: $compositionDisplayMode
                    )
                    .padding(.top, BikeyMetrics.Spacing.s)

                    ProfileSectionTitle("About")
                        .padding(.top, BikeyMetrics.Spacing.l + 2)

                    ProfileListCard(
                        rows: [
                            .init(
                                icon: "info.circle",
                                title: "About Bikey",
                                action: { showAbout = true }
                            )
                        ]
                    )
                    .padding(.top, BikeyMetrics.Spacing.s)

                    Spacer(minLength: 84)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset)
            .navigationDestination(isPresented: $showPersonalInfo) {
                PersonalInformationView(profile: session.profile)
            }
            .navigationDestination(isPresented: $showAbout) {
                AboutScreen()
            }
            .onAppear {
                syncCompositionDisplayModeFromProfile()
                phraseCount = UserDictionaryStore.readEntries().count
            }
            .onChange(of: session.profile) { _ in
                syncCompositionDisplayModeFromProfile()
                phraseCount = UserDictionaryStore.readEntries().count
            }
            .overlay {
                if showSignOutConfirm {
                    SignOutConfirmModal(
                        onCancel: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showSignOutConfirm = false
                            }
                        },
                        onConfirm: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                showSignOutConfirm = false
                            }
                            Task { await session.signOut() }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.18), value: showSignOutConfirm)
            .onChange(of: compositionDisplayMode) { newValue in
                guard newValue != lastConfirmedCompositionDisplayMode else {
                    KeyboardSettingsStore.writeCompositionDisplayMode(newValue)
                    return
                }
                KeyboardSettingsStore.writeCompositionDisplayMode(newValue)
                Task { @MainActor in
                    do {
                        try await session.updateCompositionDisplayMode(newValue)
                        lastConfirmedCompositionDisplayMode = newValue
                    } catch {
                        let rollback = lastConfirmedCompositionDisplayMode
                        KeyboardSettingsStore.writeCompositionDisplayMode(rollback)
                        compositionDisplayMode = rollback
                    }
                }
            }
        }
    }

    private func syncCompositionDisplayModeFromProfile() {
        let mode = session.profile?.compositionDisplayMode
            ?? KeyboardSettingsStore.readCompositionDisplayMode()
        lastConfirmedCompositionDisplayMode = mode
        compositionDisplayMode = mode
        KeyboardSettingsStore.writeCompositionDisplayMode(mode)
    }
}

private struct PersonalInformationView: View {
    let profile: UserSession.Profile?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.s + 2) {
                infoRow(label: "Name", value: profile?.displayName ?? "—")
                infoRow(label: "Email", value: profile?.email ?? "—")
                infoRow(
                    label: "Member since",
                    value: profile.map { Self.dateFormatter.string(from: $0.createdAt) } ?? "—"
                )
            }
            .padding(.horizontal, BikeyMetrics.Spacing.l - 4)
            .padding(.top, BikeyMetrics.Spacing.l - 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Personal Information")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .bikeyFont(11, weight: .regular, relativeTo: .footnote)
                .foregroundStyle(AppColor.muted)
            Text(value)
                .bikeyFont(15, weight: .regular, relativeTo: .body)
                .foregroundStyle(AppColor.ink)
        }
        .padding(.vertical, BikeyMetrics.Spacing.s - 1)
        .padding(.horizontal, BikeyMetrics.Spacing.m - 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct ProfileTopControls: View {
    var body: some View {
        Text("Profile")
            .bikeyFont(20, weight: .medium, relativeTo: .title3)
            .foregroundStyle(AppColor.ink)
            .frame(maxWidth: .infinity)
    }
}

private struct ProfileCard: View {
    let displayName: String
    @ObservedObject var stats: ConversionStats
    let phraseCount: Int

    var body: some View {
        ZStack {
            ProfileCardBackground()

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: BikeyMetrics.Spacing.m - 4) {
                    ProfilePortrait()
                        .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(displayName.isEmpty ? "Bikey user" : displayName)
                                .bikeyFont(20, weight: .regular, relativeTo: .title2)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.84)

                            Text("PRO")
                                .bikeyFont(8, weight: .bold, relativeTo: .caption2)
                                .foregroundStyle(.white.opacity(0.88))
                                .padding(.horizontal, 6)
                                .frame(height: 14)
                                .background(.white.opacity(0.18), in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(.white.opacity(0.45), lineWidth: 1)
                                }
                        }

                        Text("\(stats.conversionsDisplay) conversions\nwith Bikey")
                            .bikeyFont(12, weight: .regular, relativeTo: .caption)
                            .foregroundStyle(.white.opacity(0.82))
                            .lineSpacing(3)
                    }

                    Spacer()
                }

                HStack(spacing: 0) {
                    ProfileStat(value: stats.conversionsDisplay, label: "Conversions")
                    ProfileStat(value: "\(phraseCount)", label: "Phrases")
                    ProfileStat(value: stats.streakDisplay, label: "Day Streak")
                }
                .padding(.top, BikeyMetrics.Spacing.l + 1)

                Rectangle()
                    .fill(.white.opacity(0.22))
                    .frame(height: 1)
                    .padding(.top, BikeyMetrics.Spacing.m + 2)

                HStack(alignment: .center, spacing: 0) {
                    HStack(spacing: BikeyMetrics.Spacing.s + 3) {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(.white.opacity(0.20))
                            .frame(width: 27, height: 27)
                            .overlay {
                                Image(systemName: "keyboard")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.88))
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bikey")
                                .bikeyFont(16, weight: .semibold, relativeTo: .body)
                                .foregroundStyle(.white)

                            Text("Type Japanese and English\nwithout switching.")
                                .bikeyFont(11, weight: .regular, relativeTo: .footnote)
                                .foregroundStyle(.white.opacity(0.76))
                                .lineSpacing(3)
                        }
                    }

                    Spacer()
                }
                .padding(.top, BikeyMetrics.Spacing.m + 2)
            }
            .padding(.top, BikeyMetrics.Spacing.l - 4)
            .padding(.horizontal, BikeyMetrics.Spacing.l - 4)
            .padding(.bottom, BikeyMetrics.Spacing.m + 2)
        }
        .frame(height: 247)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppColor.purple.opacity(0.18), radius: 12, x: 0, y: 7)
    }
}

private struct ProfileCardBackground: View {
    var body: some View {
        ZStack {
            if let image = loadHeroImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.552, green: 0.458, blue: 0.795),
                        Color(red: 0.720, green: 0.656, blue: 0.895)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(
                colors: [.black.opacity(0.22), .black.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func loadHeroImage() -> UIImage? {
        if let url = Bundle.main.url(forResource: "gradient2", withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return UIImage(contentsOfFile: repoRoot.appendingPathComponent("public/gradient2.png").path)
    }
}

private struct ProfilePortrait: View {
    var body: some View {
        Circle()
            .fill(.white.opacity(0.92))
            .overlay {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundStyle(
                        Color(red: 0.230, green: 0.226, blue: 0.255).opacity(0.88),
                        Color(red: 0.930, green: 0.925, blue: 0.918)
                    )
            }
    }
}

private struct ProfileStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .bikeyFont(15, weight: .regular, relativeTo: .body)
                .foregroundStyle(.white)

            Text(label)
                .bikeyFont(11, weight: .regular, relativeTo: .footnote)
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .bikeyFont(18, weight: .regular, relativeTo: .headline)
            .foregroundStyle(Color(red: 0.475, green: 0.468, blue: 0.512))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, BikeyMetrics.Spacing.s + 2)
    }
}

private struct ProfileListCard: View {
    let rows: [ProfileRowModel]
    var compositionDisplayMode: Binding<CompositionDisplayMode>? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                ProfileListRow(
                    model: row,
                    compositionDisplayMode: compositionDisplayMode
                )

                if index < rows.count - 1 {
                    Divider()
                        .overlay(Color.black.opacity(0.035))
                        .padding(.leading, 56)
                        .padding(.trailing, BikeyMetrics.Spacing.m)
                }
            }
        }
        .background(.white.opacity(0.90), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 18, x: 0, y: 10)
    }
}

private struct ProfileRowModel {
    enum ToggleKind {
        case languageMode
    }

    let icon: String
    let title: String
    let trailing: String?
    let toggle: ToggleKind?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        trailing: String? = nil,
        toggle: ToggleKind? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
        self.toggle = toggle
        self.action = action
    }
}

private struct ProfileListRow: View {
    let model: ProfileRowModel
    var compositionDisplayMode: Binding<CompositionDisplayMode>?

    private var isJapaneseHeavy: Binding<Bool> {
        Binding(
            get: { compositionDisplayMode?.wrappedValue == .japaneseHeavyKana },
            set: { compositionDisplayMode?.wrappedValue = $0 ? .japaneseHeavyKana : .balancedRaw }
        )
    }

    var body: some View {
        if let action = model.action, model.toggle == nil {
            Button(action: action) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: BikeyMetrics.Spacing.m - 3) {
            Image(systemName: model.icon)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(AppColor.ink.opacity(0.86))
                .frame(width: 22)

            Text(model.title)
                .bikeyFont(15, weight: .regular, relativeTo: .body)
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            if model.toggle == .languageMode, compositionDisplayMode != nil {
                Toggle("", isOn: isJapaneseHeavy)
                    .labelsHidden()
                    .tint(AppColor.purple.opacity(0.82))
            } else if let trailing = model.trailing {
                Text(trailing)
                    .bikeyFont(14, weight: .regular, relativeTo: .body)
                    .foregroundStyle(AppColor.muted.opacity(0.82))
            }

            if model.toggle == nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.34))
            }
        }
        .padding(.horizontal, BikeyMetrics.Spacing.l - 1)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

private struct SignOutConfirmModal: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private let destructive = Color(red: 0.847, green: 0.306, blue: 0.345)

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.06))
                        .frame(width: 58, height: 58)
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(AppColor.ink)
                }
                .padding(.top, BikeyMetrics.Spacing.l + 2)

                Text("Sign out of Bikey?")
                    .bikeyFont(18, weight: .semibold, relativeTo: .headline)
                    .foregroundStyle(AppColor.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, BikeyMetrics.Spacing.m)

                Text("You'll need to sign in again to access your saved phrases and settings.")
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .padding(.horizontal, BikeyMetrics.Spacing.l)

                VStack(spacing: 8) {
                    Button(action: onConfirm) {
                        Text("Sign Out")
                            .bikeyFont(15, weight: .semibold, relativeTo: .body)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(destructive, in: Capsule())
                            .shadow(color: destructive.opacity(0.28), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)

                    Button(action: onCancel) {
                        Text("Cancel")
                            .bikeyFont(15, weight: .medium, relativeTo: .body)
                            .foregroundStyle(AppColor.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(.white, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppColor.rule.opacity(0.45), lineWidth: 0.6)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, BikeyMetrics.Spacing.m)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.m)
            }
            .frame(maxWidth: 320)
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 36, x: 0, y: 16)
            .padding(.horizontal, BikeyMetrics.Spacing.xl)
        }
    }
}
