import SwiftUI
import UIKit

enum AppTab: String, CaseIterable, Hashable {
    case home
    case phrases
    case keyboard
    case profile

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .phrases:
            return "Phrases"
        case .keyboard:
            return "Keyboard"
        case .profile:
            return "Profile"
        }
    }

    var iconName: String {
        switch self {
        case .home:
            return "house"
        case .phrases:
            return "book.closed"
        case .keyboard:
            return "keyboard"
        case .profile:
            return "person"
        }
    }
}

struct RootContainerView: View {
    @State private var selectedTab: AppTab = .home
    @StateObject private var stats = ConversionStats.shared
    @EnvironmentObject private var session: UserSession
    @Environment(\.scenePhase) private var scenePhase

    init(initialTab: AppTab = .home) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                LoadingSplash()
            case .signedOut:
                ContainerOnboardingScreen()
            case .signedIn:
                signedInBody
            }
        }
        .preferredColorScheme(.light)
        .onAppear { stats.refresh() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                stats.refresh()
            }
        }
    }

    private var signedInBody: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let scale = min(width / HomeDesign.designWidth, height / HomeDesign.designHeight)
            let horizontalInset = 62 * scale

            ZStack(alignment: .bottom) {
                AppColor.background
                    .ignoresSafeArea()

                Group {
                    switch selectedTab {
                    case .home:
                        HomeScreen(
                            scale: scale,
                            horizontalInset: horizontalInset,
                            viewportWidth: width,
                            stats: stats
                        )
                    case .phrases:
                        PlaceholderScreen(
                            title: "Phrases",
                            message: "Saved phrases will live here.",
                            iconName: "book.closed",
                            scale: scale,
                            horizontalInset: horizontalInset
                        )
                    case .keyboard:
                        PlaceholderScreen(
                            title: "Keyboard",
                            message: "Keyboard settings will live here.",
                            iconName: "keyboard",
                            scale: scale,
                            horizontalInset: horizontalInset
                        )
                    case .profile:
                        ProfileScreen(
                            scale: scale,
                            horizontalInset: horizontalInset
                        )
                    }
                }

                LiquidTabBar(selectedTab: $selectedTab, scale: scale)
                    .padding(.horizontal, horizontalInset)
                    .padding(.bottom, 30 * scale)
            }
        }
    }
}

private struct LoadingSplash: View {
    var body: some View {
        ZStack {
            AppColor.background
                .ignoresSafeArea()
            ProgressView()
                .tint(AppColor.purple)
        }
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let message: String
    let iconName: String
    let scale: CGFloat
    let horizontalInset: CGFloat

    var body: some View {
        VStack(spacing: 24 * scale) {
            Spacer()

            Circle()
                .fill(AppColor.lavender.opacity(0.85))
                .frame(width: 140 * scale, height: 140 * scale)
                .overlay {
                    Image(systemName: iconName)
                        .font(.system(size: 72 * scale, weight: .regular))
                        .foregroundStyle(AppColor.purple)
                }

            Text(title)
                .font(.system(size: 40 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColor.ink)

            Text(message)
                .font(.system(size: 26 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.softText)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, horizontalInset)
    }
}

private struct LiquidTabBar: View {
    @Binding var selectedTab: AppTab
    let scale: CGFloat

    @Namespace private var indicatorNamespace
    @State private var isMorphing = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    guard selectedTab != tab else { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                    morphIndicator()
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    VStack(spacing: 10 * scale) {
                        TabIcon(tab: tab, isSelected: selectedTab == tab, scale: scale)

                        Text(tab.title)
                            .font(.system(size: 22 * scale, weight: .regular, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .foregroundStyle(selectedTab == tab ? AppColor.purple : Color(red: 0.278, green: 0.280, blue: 0.318))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minWidth: tab == .home ? 174 * scale : 126 * scale)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(AppColor.lavender.opacity(0.84))
                                .overlay(
                                    Capsule()
                                        .stroke(.white.opacity(0.7), lineWidth: 1.2 * scale)
                                )
                                .matchedGeometryEffect(id: "liquidIndicator", in: indicatorNamespace)
                                .scaleEffect(x: isMorphing ? 1.18 : 1.0, y: isMorphing ? 0.86 : 1.0)
                                .shadow(color: AppColor.purple.opacity(0.11), radius: 8 * scale, x: 0, y: 2 * scale)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16 * scale)
        .frame(height: 136 * scale)
        .background(.white.opacity(0.92), in: Capsule())
        .shadow(color: .black.opacity(0.07), radius: 24 * scale, x: 0, y: 8 * scale)
    }

    private func morphIndicator() {
        withAnimation(.easeOut(duration: 0.14)) {
            isMorphing = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 140_000_000)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                isMorphing = false
            }
        }
    }
}

private struct TabIcon: View {
    let tab: AppTab
    let isSelected: Bool
    let scale: CGFloat

    var body: some View {
        Group {
            if tab == .profile {
                ProfileAvatar(scale: scale)
            } else {
                Image(systemName: tab.iconName)
                    .font(.system(size: tab == .keyboard ? 35 * scale : 38 * scale, weight: .regular))
                    .symbolVariant(isSelected ? .fill : .none)
            }
        }
    }
}

private struct ProfileAvatar: View {
    let scale: CGFloat

    var body: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 42 * scale, weight: .regular))
    }
}

private enum OnboardingDesign {
    static let width: CGFloat = 390
    static let height: CGFloat = 844
}

private struct ContainerOnboardingScreen: View {
    @State private var debugAutoNav = ProcessInfo.processInfo.environment["BIKEY_AUTONAV"]
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let scale = min(
                    proxy.size.width / OnboardingDesign.width,
                    proxy.size.height / OnboardingDesign.height
                )

                ZStack {
                    OnboardingBackground()
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        Spacer(minLength: 64 * scale)

                        WelcomeAppIcon(scale: scale)
                            .frame(width: 132 * scale, height: 132 * scale)

                        Text("Bikey")
                            .font(.system(size: 44 * scale, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColor.ink)
                            .padding(.top, 28 * scale)

                        Text("Type Japanese and English\nwithout switching keyboards.")
                            .font(.system(size: 17 * scale, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColor.muted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4 * scale)
                            .padding(.top, 14 * scale)

                        WelcomePreviewCard(scale: scale)
                            .padding(.top, 42 * scale)
                            .padding(.horizontal, 32 * scale)

                        Spacer(minLength: 32 * scale)

                        VStack(spacing: 14 * scale) {
                            NavigationLink {
                                SignUpForm()
                            } label: {
                                OnboardingPrimaryButtonLabel(title: "Create account", scale: scale)
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                SignInForm()
                            } label: {
                                HStack(spacing: 5 * scale) {
                                    Text("Already have an account?")
                                        .foregroundStyle(AppColor.muted)
                                    Text("Sign in")
                                        .foregroundStyle(AppColor.purple)
                                        .fontWeight(.semibold)
                                }
                                .font(.system(size: 14 * scale, weight: .regular, design: .rounded))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 28 * scale)
                        .padding(.bottom, 36 * scale)
                    }
                }
                .navigationDestination(isPresented: Binding(
                    get: { debugAutoNav == "signup" },
                    set: { if !$0 { debugAutoNav = nil } }
                )) {
                    SignUpForm()
                }
                .navigationDestination(isPresented: Binding(
                    get: { debugAutoNav == "signin" },
                    set: { if !$0 { debugAutoNav = nil } }
                )) {
                    SignInForm()
                }
            }
            .preferredColorScheme(.light)
        }
    }
}

struct OnboardingPrimaryButtonLabel: View {
    let title: String
    let scale: CGFloat
    var isLoading: Bool = false
    var isEnabled: Bool = true

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(title)
                    .font(.system(size: 17 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56 * scale)
        .background(
            LinearGradient(
                colors: isEnabled
                    ? [AppColor.purple, Color(red: 0.438, green: 0.305, blue: 0.764)]
                    : [AppColor.purple.opacity(0.45), Color(red: 0.438, green: 0.305, blue: 0.764).opacity(0.45)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: Capsule()
        )
        .shadow(color: AppColor.purple.opacity(isEnabled ? 0.28 : 0.0), radius: 18 * scale, x: 0, y: 10 * scale)
    }
}

private struct WelcomeAppIcon: View {
    let scale: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 30 * scale, style: .continuous)
            .fill(Color.white)
            .shadow(color: AppColor.purple.opacity(0.18), radius: 26 * scale, x: 0, y: 16 * scale)
            .overlay {
                Group {
                    if let image = Self.loadIcon() {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 64 * scale, weight: .regular))
                            .foregroundStyle(AppColor.purple.opacity(0.72))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 30 * scale, style: .continuous))
            }
    }

    private static func loadIcon() -> UIImage? {
        if let url = Bundle.main.url(forResource: "newapp", withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        let sourceURL = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return UIImage(contentsOfFile: repoRoot.appendingPathComponent("public/newapp.png").path)
    }
}

private struct WelcomePreviewCard: View {
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            Text("kyouno meeting ha 3ji")
                .font(.system(size: 16 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8 * scale) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 12 * scale, weight: .regular))
                    .foregroundStyle(AppColor.softText)

                Text("今日の meeting は 3時")
                    .font(.system(size: 16 * scale, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 22 * scale)
        .padding(.vertical, 20 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                .fill(.white)
        )
        .shadow(color: .black.opacity(0.05), radius: 18 * scale, x: 0, y: 10 * scale)
    }
}

struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            AppColor.background
            LinearGradient(
                colors: [
                    AppColor.lavender.opacity(0.55),
                    AppColor.background.opacity(0)
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}
