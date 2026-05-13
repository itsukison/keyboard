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

    init(initialTab: AppTab = .home) {
        _selectedTab = State(initialValue: initialTab)
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
                        ProfileScreen(scale: scale, horizontalInset: horizontalInset)
                    }
                }

                LiquidTabBar(selectedTab: $selectedTab, scale: scale)
                    .padding(.horizontal, horizontalInset)
                    .padding(.bottom, 30 * scale)
            }
        }
        .preferredColorScheme(.light)
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
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.885, green: 0.858, blue: 0.826),
                        Color(red: 0.121, green: 0.124, blue: 0.132)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 42 * scale, height: 42 * scale)
            .overlay(alignment: .top) {
                Circle()
                    .fill(Color(red: 0.875, green: 0.805, blue: 0.746))
                    .frame(width: 18 * scale, height: 18 * scale)
                    .offset(y: 7 * scale)
            }
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(Color(red: 0.103, green: 0.106, blue: 0.114))
                    .frame(width: 30 * scale, height: 20 * scale)
                    .offset(y: -4 * scale)
            }
    }
}
