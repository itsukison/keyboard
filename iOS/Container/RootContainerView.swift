import SwiftUI
import UIKit

enum AppTab: String, CaseIterable, Hashable {
    case home
    case dictionary
    case profile

    var title: String {
        switch self {
        case .home: return "Home"
        case .dictionary: return "Phrases"
        case .profile: return "Settings"
        }
    }

    var iconName: String {
        switch self {
        case .home: return "house"
        case .dictionary: return "book.closed"
        case .profile: return "person"
        }
    }
}

struct RootContainerView: View {
    @State private var selectedTab: AppTab = .home
    @StateObject private var stats = ConversionStats.shared
    @EnvironmentObject private var session: UserSession
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("pendingBikeyPostAuthOnboarding") private var pendingPostAuthOnboarding = false

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
                Task { try? await session.refreshUserDictionaryCache() }
            }
        }
    }

    @ViewBuilder
    private var signedInBody: some View {
        if pendingPostAuthOnboarding {
            PostAuthOnboardingFlow {
                selectedTab = .home
                pendingPostAuthOnboarding = false
            }
        } else {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    AppColor.background
                        .ignoresSafeArea()

                    Group {
                        switch selectedTab {
                        case .home:
                            HomeScreen()
                        case .dictionary:
                            DictionaryScreen()
                        case .profile:
                            ProfileScreen()
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    LiquidTabBar(selectedTab: $selectedTab)
                        .padding(.horizontal, BikeyMetrics.Sizing.screenHorizontalInset + 4)
                        .padding(.bottom, 4)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
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

private struct LiquidTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 0) {
                    tabRow
                }
            } else {
                tabRow
            }
        }
    }

    private var tabRow: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    guard !isSelected else { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    ZStack {
                        if isSelected {
                            TabSelectionHighlight()
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }

                        VStack(spacing: 4) {
                            TabIcon(tab: tab, isSelected: isSelected)
                            Text(tab.title)
                                .bikeyFont(11, weight: .regular, relativeTo: .caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)
                        }
                        .foregroundStyle(isSelected ? AppColor.ink : Color.black.opacity(0.72))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(height: 70)
        .bikeyInteractiveGlass(in: Capsule(), fallback: .white.opacity(0.92))
        .shadow(color: Color(red: 0.42, green: 0.42, blue: 0.44).opacity(0.20), radius: 18, x: 0, y: 8)
        .shadowIfLegacyChrome(color: .white.opacity(0.75), radius: 2, y: -1)
    }
}

private extension View {
    @ViewBuilder
    func shadowIfLegacyChrome(color: Color, radius: CGFloat, y: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            self.shadow(color: color, radius: radius, x: 0, y: y)
        }
    }
}

private struct TabSelectionHighlight: View {
    var body: some View {
        Capsule()
            .fill(.white.opacity(0.72))
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.86), lineWidth: 1)
            }
            .shadow(color: Color(red: 0.36, green: 0.36, blue: 0.38).opacity(0.28), radius: 15, x: 0, y: 8)
            .shadow(color: .white.opacity(0.92), radius: 4, x: 0, y: -1)
            .padding(.vertical, 2)
            .padding(.horizontal, 1)
    }
}

private struct TabIcon: View {
    let tab: AppTab
    let isSelected: Bool

    var body: some View {
        Group {
            if tab == .profile {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 20, weight: .regular))
            } else {
                Image(systemName: tab.iconName)
                    .font(.system(size: 18, weight: .regular))
                    .symbolVariant(isSelected ? .fill : .none)
            }
        }
    }
}
