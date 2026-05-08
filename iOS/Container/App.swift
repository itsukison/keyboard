import SwiftUI
import UIKit

@main
struct BilingualKeyboardApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}

struct HomeView: View {
    private let designWidth: CGFloat = 863
    private let designHeight: CGFloat = 1822

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let scale = min(width / designWidth, height / designHeight)
            let horizontalInset = 50 * scale

            ZStack(alignment: .bottom) {
                AppColor.background
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        HeaderView(scale: scale)
                            .padding(.top, 36 * scale)

                        EnabledPill(scale: scale)
                            .padding(.top, 34 * scale)

                        HeroCard(scale: scale)
                            .padding(.top, 34 * scale)

                        PageDots(scale: scale)
                            .padding(.top, 30 * scale)

                        RecentHeader(scale: scale)
                            .padding(.top, 42 * scale)

                        VStack(spacing: 20 * scale) {
                            RecentConversionCard(
                                source: "kyouno meeting ha 3ji",
                                converted: "今日の meeting は 3時",
                                time: "4:15 p.m.",
                                scale: scale
                            )

                            RecentConversionCard(
                                source: "korekara we can go",
                                converted: "これから we can go",
                                time: "2:40 p.m.",
                                scale: scale
                            )
                        }
                        .padding(.top, 18 * scale)

                        Spacer(minLength: 170 * scale)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, horizontalInset)
                }
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 0)
                }

                BottomTabBar(scale: scale)
                    .padding(.horizontal, horizontalInset)
                    .padding(.bottom, 30 * scale)
            }
        }
        .preferredColorScheme(.light)
    }
}

private enum AppColor {
    static let background = Color(red: 0.982, green: 0.981, blue: 0.974)
    static let ink = Color(red: 0.155, green: 0.158, blue: 0.205)
    static let muted = Color(red: 0.514, green: 0.502, blue: 0.653)
    static let softText = Color(red: 0.636, green: 0.630, blue: 0.735)
    static let purple = Color(red: 0.341, green: 0.258, blue: 0.656)
    static let lavender = Color(red: 0.917, green: 0.900, blue: 0.973)
    static let paleLavender = Color(red: 0.950, green: 0.937, blue: 0.986)
}

private struct HeaderView: View {
    let scale: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 18 * scale) {
                BikeyMark(scale: scale)
                    .frame(width: 48 * scale, height: 68 * scale)

                Text("Bikey")
                    .font(.system(size: 47 * scale, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.ink)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 16 * scale)

            HStack(spacing: 16 * scale) {
                MetricPill(value: "12,480", label: "conversions", scale: scale)
                    .frame(width: 164 * scale, height: 98 * scale)

                MetricPill(value: "6", label: "day streak", scale: scale)
                    .frame(width: 146 * scale, height: 98 * scale)

                PowerToggle(scale: scale)
                    .frame(width: 90 * scale, height: 54 * scale)
                    .padding(.leading, 17 * scale)
            }
        }
        .frame(height: 104 * scale)
    }
}

private struct BikeyMark: View {
    let scale: CGFloat

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 10 * scale, y: 58 * scale))
                path.addLine(to: CGPoint(x: 10 * scale, y: 18 * scale))
                path.addCurve(
                    to: CGPoint(x: 34 * scale, y: 15 * scale),
                    control1: CGPoint(x: 12 * scale, y: 2 * scale),
                    control2: CGPoint(x: 33 * scale, y: 1 * scale)
                )
                path.addCurve(
                    to: CGPoint(x: 13 * scale, y: 35 * scale),
                    control1: CGPoint(x: 35 * scale, y: 29 * scale),
                    control2: CGPoint(x: 18 * scale, y: 29 * scale)
                )
                path.addLine(to: CGPoint(x: 38 * scale, y: 58 * scale))
            }
            .stroke(
                LinearGradient(
                    colors: [Color(red: 0.714, green: 0.606, blue: 0.910), AppColor.purple],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                ),
                style: StrokeStyle(lineWidth: 8 * scale, lineCap: .round, lineJoin: .round)
            )

            Circle()
                .fill(AppColor.background)
                .frame(width: 24 * scale, height: 24 * scale)
                .offset(x: 18 * scale, y: 12 * scale)
        }
    }
}

private struct MetricPill: View {
    let value: String
    let label: String
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 4 * scale) {
            Text(value)
                .font(.system(size: 30 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(.system(size: 22 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.softText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 31 * scale, style: .continuous))
        .shadow(color: .black.opacity(0.035), radius: 22 * scale, x: 0, y: 10 * scale)
    }
}

private struct PowerToggle: View {
    let scale: CGFloat

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [AppColor.purple, Color(red: 0.438, green: 0.305, blue: 0.764)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(alignment: .trailing) {
                Circle()
                    .fill(.white)
                    .frame(width: 42 * scale, height: 42 * scale)
                    .padding(.trailing, 6 * scale)
                    .shadow(color: .black.opacity(0.08), radius: 5 * scale, x: 0, y: 2 * scale)
            }
    }
}

private struct EnabledPill: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 20 * scale) {
            Circle()
                .fill(AppColor.lavender)
                .frame(width: 86 * scale, height: 86 * scale)
                .overlay {
                    Image(systemName: "keyboard")
                        .font(.system(size: 32 * scale, weight: .medium))
                        .foregroundStyle(AppColor.purple)
                }

            Text("Bikey keyboard enabled")
                .font(.system(size: 29 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 0)
        }
        .padding(.leading, 10 * scale)
        .padding(.trailing, 30 * scale)
        .frame(height: 102 * scale)
        .background(AppColor.paleLavender.opacity(0.92), in: Capsule())
    }
}

private struct HeroCard: View {
    let scale: CGFloat

    var body: some View {
        ZStack {
            HeroBackgroundImage()
                .frame(height: 512 * scale)

            VStack(alignment: .leading, spacing: 0) {
                Text("Type naturally in\ntwo languages")
                    .font(.system(size: 56 * scale, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.ink)
                    .lineSpacing(12 * scale)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Japanese + English, no\nkeyboard switching.")
                    .font(.system(size: 31 * scale, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.muted)
                    .lineSpacing(9 * scale)
                    .padding(.top, 30 * scale)

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 0) {
                    ConversionPreview(scale: scale)
                        .frame(width: 342 * scale, height: 104 * scale)

                    Spacer(minLength: 24 * scale)

                    Text("Try demo")
                        .font(.system(size: 29 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 223 * scale, height: 78 * scale)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.145, green: 0.144, blue: 0.160).opacity(0.94))
                        )
                        .shadow(color: .black.opacity(0.12), radius: 18 * scale, x: 0, y: 9 * scale)
                }
            }
            .padding(.top, 72 * scale)
            .padding(.horizontal, 56 * scale)
            .padding(.bottom, 58 * scale)
        }
        .frame(height: 512 * scale)
        .clipShape(RoundedRectangle(cornerRadius: 43 * scale, style: .continuous))
        .shadow(color: AppColor.purple.opacity(0.11), radius: 20 * scale, x: 0, y: 10 * scale)
    }
}

private struct HeroBackgroundImage: View {
    var body: some View {
        if let url = Bundle.main.url(forResource: "bg", withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.878, green: 0.854, blue: 0.958),
                    Color(red: 0.976, green: 0.966, blue: 0.993)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct ConversionPreview: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 20 * scale) {
            Text("kyou wa")
                .font(.system(size: 26 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Image(systemName: "arrow.right")
                .font(.system(size: 25 * scale, weight: .regular))
                .foregroundStyle(AppColor.softText)

            Text("今日は")
                .font(.system(size: 26 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 14 * scale)
                .frame(height: 58 * scale)
                .background(AppColor.lavender.opacity(0.75), in: RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(AppColor.purple)
                        .frame(width: max(1, 2 * scale), height: 32 * scale)
                        .padding(.trailing, 12 * scale)
                }
        }
        .padding(.horizontal, 26 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 31 * scale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 31 * scale, style: .continuous)
                .stroke(.white.opacity(0.96), lineWidth: 11 * scale)
        )
    }
}

private struct PageDots: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 20 * scale) {
            Circle()
                .fill(AppColor.ink)
                .frame(width: 14 * scale, height: 14 * scale)

            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Color.black.opacity(0.22))
                    .frame(width: 14 * scale, height: 14 * scale)
            }
        }
    }
}

private struct RecentHeader: View {
    let scale: CGFloat

    var body: some View {
        HStack {
            Text("Recent conversions")
                .font(.system(size: 30 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(Color(red: 0.326, green: 0.330, blue: 0.384))
                .lineLimit(1)

            Spacer()

            Circle()
                .fill(.white.opacity(0.62))
                .frame(width: 76 * scale, height: 76 * scale)
                .overlay {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 29 * scale, weight: .regular))
                        .foregroundStyle(Color(red: 0.430, green: 0.424, blue: 0.500))
                }
                .shadow(color: .black.opacity(0.04), radius: 16 * scale, x: 0, y: 8 * scale)
        }
        .frame(height: 76 * scale)
        .padding(.horizontal, 18 * scale)
    }
}

private struct RecentConversionCard: View {
    let source: String
    let converted: String
    let time: String
    let scale: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Today")
                    .font(.system(size: 24 * scale, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.muted)

                Text(source)
                    .font(.system(size: 31 * scale, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.ink)
                    .padding(.top, 25 * scale)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(converted)
                    .font(.system(size: 31 * scale, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.muted)
                    .padding(.top, 17 * scale)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(time)
                    .font(.system(size: 24 * scale, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.softText)
                    .padding(.top, 25 * scale)
                    .lineLimit(1)
            }

            Spacer(minLength: 18 * scale)

            Circle()
                .fill(AppColor.lavender.opacity(0.78))
                .frame(width: 74 * scale, height: 74 * scale)
                .overlay {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 28 * scale, weight: .regular))
                        .foregroundStyle(AppColor.purple)
                }
        }
        .padding(.leading, 44 * scale)
        .padding(.trailing, 40 * scale)
        .frame(height: 256 * scale)
        .background(.white.opacity(0.87), in: RoundedRectangle(cornerRadius: 34 * scale, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 22 * scale, x: 0, y: 12 * scale)
    }
}

private struct BottomTabBar: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            TabButton(icon: "house", title: "Home", isSelected: true, scale: scale)
                .frame(width: 198 * scale)

            Spacer(minLength: 0)

            TabButton(icon: "book.closed", title: "Guide", isSelected: false, scale: scale)

            Spacer(minLength: 0)

            TabButton(icon: "play.circle", title: "Demo", isSelected: false, scale: scale)

            Spacer(minLength: 0)

            TabButton(icon: "gearshape", title: "Settings", isSelected: false, scale: scale)
        }
        .padding(.leading, 14 * scale)
        .padding(.trailing, 38 * scale)
        .frame(height: 136 * scale)
        .background(.white.opacity(0.92), in: Capsule())
        .shadow(color: .black.opacity(0.07), radius: 24 * scale, x: 0, y: 8 * scale)
    }
}

private struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 10 * scale) {
            Image(systemName: icon)
                .font(.system(size: 39 * scale, weight: .regular))
                .symbolVariant(isSelected ? .fill : .none)

            Text(title)
                .font(.system(size: 22 * scale, weight: .regular, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .foregroundStyle(isSelected ? AppColor.purple : Color(red: 0.278, green: 0.280, blue: 0.318))
        .frame(maxHeight: .infinity)
        .frame(minWidth: 92 * scale)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 38 * scale, style: .continuous)
                    .fill(AppColor.lavender.opacity(0.84))
            }
        }
    }
}
