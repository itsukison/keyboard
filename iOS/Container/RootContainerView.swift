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
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var isOnboardingPresented = false
    private let showsOnboardingOnLaunch: Bool

    init(initialTab: AppTab = .home, showsOnboardingOnLaunch: Bool = false) {
        _selectedTab = State(initialValue: initialTab)
        self.showsOnboardingOnLaunch = showsOnboardingOnLaunch
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let scale = min(width / HomeDesign.designWidth, height / HomeDesign.designHeight)
            let horizontalInset = 50 * scale

            ZStack(alignment: .bottom) {
                AppColor.background
                    .ignoresSafeArea()

                Group {
                    switch selectedTab {
                    case .home:
                        HomeScreen(scale: scale, horizontalInset: horizontalInset)
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
                            horizontalInset: horizontalInset,
                            onShowOnboarding: { isOnboardingPresented = true }
                        )
                    }
                }

                LiquidTabBar(selectedTab: $selectedTab, scale: scale)
                    .padding(.horizontal, horizontalInset)
                    .padding(.bottom, 30 * scale)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            if showsOnboardingOnLaunch && !hasSeenOnboarding {
                isOnboardingPresented = true
            }
        }
        .fullScreenCover(isPresented: $isOnboardingPresented) {
            ContainerOnboardingScreen {
                hasSeenOnboarding = true
                isOnboardingPresented = false
            }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
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
    let onGetStarted: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let canvasWidth = proxy.size.width
            let canvasHeight = proxy.size.height
            let scale = min(
                canvasWidth / OnboardingDesign.width,
                canvasHeight / OnboardingDesign.height
            )
            let xOffset = (canvasWidth - OnboardingDesign.width * scale) / 2
            let yOffset = (canvasHeight - OnboardingDesign.height * scale) / 2

            ZStack {
                ContainerOnboardingBackgroundImage()
                    .ignoresSafeArea()

                ZStack(alignment: .topLeading) {
                    HStack(spacing: 3 * scale) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11 * scale, weight: .medium))
                            .foregroundStyle(.white.opacity(0.94))
                        Text("Willow")
                            .font(.system(size: 13 * scale, weight: .regular))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .frame(width: 280 * scale, alignment: .leading)
                    .offset(x: xOffset + 54 * scale, y: yOffset + 323 * scale)

                    heroText(scale: scale)
                        .lineSpacing(0)
                        .frame(width: 300 * scale, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(x: xOffset + 54 * scale, y: yOffset + 357 * scale)

                    HStack(spacing: 5 * scale) {
                        Circle()
                            .fill(.white.opacity(0.96))
                            .frame(width: 5 * scale, height: 5 * scale)
                        Circle()
                            .fill(.white.opacity(0.50))
                            .frame(width: 5 * scale, height: 5 * scale)
                        Circle()
                            .fill(.white.opacity(0.50))
                            .frame(width: 5 * scale, height: 5 * scale)
                        Circle()
                            .fill(.white.opacity(0.50))
                            .frame(width: 5 * scale, height: 5 * scale)
                    }
                    .position(x: xOffset + 195 * scale, y: yOffset + 690 * scale)

                    Button(action: onGetStarted) {
                        Text("Get started")
                            .font(.system(size: 14 * scale, weight: .regular))
                            .foregroundStyle(Color(red: 0.151, green: 0.152, blue: 0.187))
                            .frame(width: 334 * scale, height: 51 * scale)
                            .background(.white.opacity(0.82), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .position(x: xOffset + 195 * scale, y: yOffset + 734 * scale)

                    HStack(spacing: 4 * scale) {
                        Text("Already have an account?")
                            .font(.system(size: 12 * scale, weight: .regular))
                            .foregroundStyle(Color.black.opacity(0.55))

                        Button(action: onGetStarted) {
                            Text("Sign In")
                                .font(.system(size: 12 * scale, weight: .semibold))
                                .foregroundStyle(Color(red: 0.129, green: 0.129, blue: 0.155).opacity(0.86))
                        }
                        .buttonStyle(.plain)
                    }
                    .position(x: xOffset + 195 * scale, y: yOffset + 790 * scale)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func heroText(scale: CGFloat) -> Text {
        let stop = Text("Stop typing.")
            .font(.system(size: 30 * scale, weight: .semibold))
            .foregroundColor(.white.opacity(0.98))
        let start = Text(" Start")
            .font(.system(size: 30 * scale, weight: .regular))
            .foregroundColor(.white.opacity(0.72))
        let talking = Text("\ntalking.")
            .font(.system(size: 30 * scale, weight: .semibold))
            .foregroundColor(.white.opacity(0.98))

        return stop + start + talking
    }
}

private struct ContainerOnboardingBackgroundImage: View {
    var body: some View {
        if let image = loadBackgroundImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.918, green: 0.891, blue: 0.964),
                    Color(red: 0.815, green: 0.742, blue: 0.934)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func loadBackgroundImage() -> UIImage? {
        if let url = Bundle.main.url(forResource: "onboardbg", withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return UIImage(contentsOfFile: repoRoot.appendingPathComponent("public/onboardbg.png").path)
    }
}
