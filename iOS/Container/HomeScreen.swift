import SwiftUI
import UIKit

enum HomeDesign {
    static let designWidth: CGFloat = 863
    static let designHeight: CGFloat = 1822
}

enum AppColor {
    static let background = Color(red: 0.984, green: 0.981, blue: 0.976)
    static let ink = Color(red: 0.129, green: 0.129, blue: 0.155)
    static let muted = Color(red: 0.469, green: 0.462, blue: 0.522)
    static let softText = Color(red: 0.636, green: 0.630, blue: 0.735)
    static let purple = Color(red: 0.341, green: 0.258, blue: 0.656)
    static let lavender = Color(red: 0.917, green: 0.900, blue: 0.973)
    static let paleLavender = Color(red: 0.950, green: 0.937, blue: 0.986)
    static let rule = Color(red: 0.805, green: 0.804, blue: 0.803)
}

struct HomeScreen: View {
    let scale: CGFloat
    let horizontalInset: CGFloat
    let viewportWidth: CGFloat
    @ObservedObject var stats: ConversionStats

    private let recentItems: [RecentConversion] = [
        .init(
            dayLabel: "Today",
            sourceText: "kyouno meeting ha 3ji",
            convertedText: "今日の meeting は 3時",
            timeText: "4:15 p.m."
        ),
        .init(
            dayLabel: "Today",
            sourceText: "korekara we can go",
            convertedText: "これから we can go",
            timeText: "2:40 p.m."
        )
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                HeaderView(scale: scale, stats: stats)
                    .padding(.top, 34 * scale)

                KeyboardEnabledBanner(scale: scale)
                    .padding(.top, 26 * scale)

                HeroCard(scale: scale)
                    .padding(.top, 22 * scale)

                PageDots(scale: scale)
                    .padding(.top, 18 * scale)

                RecentHeader(scale: scale)
                    .padding(.top, 30 * scale)

                VStack(spacing: 20 * scale) {
                    ForEach(recentItems) { item in
                        RecentConversionCard(item: item, scale: scale)
                    }
                }
                .padding(.top, 18 * scale)

                Spacer(minLength: 178 * scale)
            }
            .frame(width: max(0, viewportWidth - (horizontalInset * 2)))
            .padding(.horizontal, horizontalInset)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HeaderView: View {
    let scale: CGFloat
    @ObservedObject var stats: ConversionStats

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 14 * scale) {
                AppIconTile(scale: scale)
                    .frame(width: 56 * scale, height: 56 * scale)

                Text("Bikey")
                    .font(.system(size: 34 * scale, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.ink)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 16 * scale)

            StatsPill(scale: scale, stats: stats)
                .frame(width: 230 * scale, height: 86 * scale)

            PowerToggle(scale: scale)
                .frame(width: 94 * scale, height: 58 * scale)
                .padding(.leading, 14 * scale)
        }
        .frame(height: 88 * scale)
    }
}

private struct AppIconTile: View {
    let scale: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
            .fill(Color.white.opacity(0.9))
            .shadow(color: .black.opacity(0.05), radius: 12 * scale, x: 0, y: 6 * scale)
            .overlay {
                Group {
                    if let image = Self.loadIcon() {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 30 * scale, weight: .regular))
                            .foregroundStyle(AppColor.purple.opacity(0.72))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
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

private struct StatsPill: View {
    let scale: CGFloat
    @ObservedObject var stats: ConversionStats

    var body: some View {
        HStack(spacing: 0) {
            MetricColumn(value: stats.conversionsDisplay, label: "conversions", scale: scale)
                .frame(maxWidth: .infinity)

            Rectangle()
                .fill(AppColor.rule.opacity(0.62))
                .frame(width: max(1, 1 * scale), height: 36 * scale)

            MetricColumn(value: stats.streakDisplay, label: "day streak", scale: scale)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.76), in: Capsule())
        .shadow(color: .black.opacity(0.055), radius: 20 * scale, x: 0, y: 8 * scale)
    }
}

private struct MetricColumn: View {
    let value: String
    let label: String
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 1 * scale) {
            Text(value)
                .font(.system(size: 26 * scale, weight: .medium, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.system(size: 18 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(Color(red: 0.554, green: 0.548, blue: 0.604))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
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
                    .frame(width: 44 * scale, height: 44 * scale)
                    .padding(.trailing, 7 * scale)
                    .shadow(color: .black.opacity(0.08), radius: 5 * scale, x: 0, y: 2 * scale)
            }
    }
}

private struct KeyboardEnabledBanner: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 18 * scale) {
            RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                .fill(AppColor.paleLavender)
                .frame(width: 44 * scale, height: 44 * scale)
                .overlay {
                    Image(systemName: "keyboard")
                        .font(.system(size: 20 * scale, weight: .regular))
                        .foregroundStyle(AppColor.purple.opacity(0.76))
                }

            Text("Bikey keyboard enabled")
                .font(.system(size: 29 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink.opacity(0.9))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26 * scale)
        .frame(height: 86 * scale)
        .background(AppColor.paleLavender.opacity(0.72), in: RoundedRectangle(cornerRadius: 30 * scale, style: .continuous))
    }
}

private struct HeroCard: View {
    let scale: CGFloat

    var body: some View {
        ZStack {
            HeroBackgroundImage()
                .scaleEffect(1.12)
                .overlay(Color.white.opacity(0.30))

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 14 * scale) {
                        Text("Type naturally in\ntwo languages")
                            .font(.system(size: 62 * scale, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColor.ink.opacity(0.94))
                            .lineSpacing(4 * scale)

                        Text("Japanese + English, no\nkeyboard switching.")
                            .font(.system(size: 33 * scale, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColor.muted)
                            .lineSpacing(8 * scale)
                    }

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 24 * scale) {
                    ConversionPreviewPill(scale: scale)
                        .frame(height: 150 * scale)

                    Spacer(minLength: 0)

                    Text("Try demo")
                        .font(.system(size: 34 * scale, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 200 * scale, height: 86 * scale)
                        .background(Color(red: 0.151, green: 0.152, blue: 0.187), in: Capsule())
                }
            }
            .padding(.horizontal, 48 * scale)
            .padding(.vertical, 44 * scale)
        }
        .frame(height: 540 * scale)
        .clipShape(RoundedRectangle(cornerRadius: 40 * scale, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 22 * scale, x: 0, y: 10 * scale)
    }
}

private struct ConversionPreviewPill: View {
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * scale) {
            Text("kyouno meeting ha 3ji")
                .font(.system(size: 31 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            HStack(spacing: 10 * scale) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 20 * scale, weight: .regular))
                    .foregroundStyle(AppColor.softText)

                Text("今日の meeting は 3時")
                    .font(.system(size: 31 * scale, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
        }
        .padding(.horizontal, 22 * scale)
        .padding(.vertical, 22 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 28 * scale, style: .continuous))
    }
}

private struct PageDots: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 15 * scale) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index == 0 ? AppColor.ink.opacity(0.9) : AppColor.rule)
                    .frame(width: 10 * scale, height: 10 * scale)
            }
        }
    }
}

private struct HeroBackgroundImage: View {
    var body: some View {
        if let image = loadHeroImage() {
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

    private func loadHeroImage() -> UIImage? {
        if let url = Bundle.main.url(forResource: "background", withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceURL
            .deletingLastPathComponent() // Container
            .deletingLastPathComponent() // iOS
            .deletingLastPathComponent() // repo root
        return UIImage(contentsOfFile: repoRoot.appendingPathComponent("public/background.png").path)
    }
}

private struct RecentHeader: View {
    let scale: CGFloat

    var body: some View {
        HStack {
            Text("Recent conversions")
                .font(.system(size: 32 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(Color(red: 0.445, green: 0.438, blue: 0.489))
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
        .frame(height: 70 * scale)
        .padding(.horizontal, 10 * scale)
    }
}

private struct RecentConversion: Identifiable {
    let id = UUID()
    let dayLabel: String
    let sourceText: String
    let convertedText: String
    let timeText: String
}

private struct RecentConversionCard: View {
    let item: RecentConversion
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 20 * scale) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.dayLabel)
                        .font(.system(size: 24 * scale, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColor.muted)

                    Text(item.sourceText)
                        .font(.system(size: 43 * scale, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColor.ink)
                        .padding(.top, 20 * scale)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(item.convertedText)
                        .font(.system(size: 38 * scale, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColor.softText)
                        .padding(.top, 14 * scale)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(item.timeText)
                        .font(.system(size: 27 * scale, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColor.muted.opacity(0.8))
                        .padding(.top, 22 * scale)
                }

                Spacer(minLength: 0)

                Circle()
                    .fill(AppColor.paleLavender.opacity(0.86))
                    .frame(width: 64 * scale, height: 64 * scale)
                    .overlay {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 27 * scale, weight: .regular))
                            .foregroundStyle(AppColor.purple.opacity(0.54))
                    }
                    .padding(.top, 44 * scale)
            }
        }
        .padding(.horizontal, 34 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 270 * scale)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 36 * scale, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 20 * scale, x: 0, y: 10 * scale)
    }
}
