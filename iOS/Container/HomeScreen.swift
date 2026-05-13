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

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                HeaderView(scale: scale)
                    .padding(.top, 36 * scale)

                HeroCard(scale: scale)
                    .padding(.top, 45 * scale)

                ExamplesHeader(scale: scale)
                    .padding(.top, 64 * scale)

                ExampleCard(scale: scale)
                    .padding(.top, 22 * scale)

                Spacer(minLength: 188 * scale)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalInset)
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 0)
        }
    }
}

private struct HeaderView: View {
    let scale: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(spacing: 22 * scale) {
                IconTile(systemName: "globe", scale: scale)
                    .frame(width: 72 * scale, height: 72 * scale)

                Text("Bikey")
                    .font(.system(size: 50 * scale, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.ink)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 16 * scale)

            StatsPill(scale: scale)
                .frame(width: 308 * scale, height: 88 * scale)

            PowerToggle(scale: scale)
                .frame(width: 100 * scale, height: 62 * scale)
                .padding(.leading, 22 * scale)
        }
        .frame(height: 92 * scale)
    }
}

private struct IconTile: View {
    let systemName: String
    let scale: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
            .fill(Color.white.opacity(0.78))
            .shadow(color: .black.opacity(0.09), radius: 16 * scale, x: 0, y: 8 * scale)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 38 * scale, weight: .regular))
                    .foregroundStyle(AppColor.purple.opacity(0.72))
            }
    }
}

private struct StatsPill: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            MetricColumn(value: "32,345", label: "words", scale: scale)
                .frame(maxWidth: .infinity)

            Rectangle()
                .fill(AppColor.rule.opacity(0.62))
                .frame(width: max(1, 1 * scale), height: 42 * scale)

            MetricColumn(value: "8", label: "day streak", scale: scale)
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
                .font(.system(size: 27 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.system(size: 20 * scale, weight: .regular, design: .rounded))
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
                    .frame(width: 48 * scale, height: 48 * scale)
                    .padding(.trailing, 7 * scale)
                    .shadow(color: .black.opacity(0.08), radius: 5 * scale, x: 0, y: 2 * scale)
            }
    }
}

private struct HeroCard: View {
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            HeroVisualArea(scale: scale)
                .frame(height: 460 * scale)

            HeroTextArea(scale: scale)
                .frame(height: 395 * scale)
        }
        .frame(height: 855 * scale)
        .clipShape(RoundedRectangle(cornerRadius: 45 * scale, style: .continuous))
        .shadow(color: .black.opacity(0.075), radius: 30 * scale, x: 0, y: 18 * scale)
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
        if let url = Bundle.main.url(forResource: "bg", withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceURL
            .deletingLastPathComponent() // Container
            .deletingLastPathComponent() // iOS
            .deletingLastPathComponent() // repo root
        return UIImage(contentsOfFile: repoRoot.appendingPathComponent("public/bg.png").path)
    }
}

private struct HeroVisualArea: View {
    let scale: CGFloat

    var body: some View {
        ZStack {
            HeroBackgroundImage()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 30 * scale) {
                TextInputBubble(scale: scale)
                    .frame(width: 480 * scale, height: 114 * scale)

                Image(systemName: "arrow.down")
                    .font(.system(size: 31 * scale, weight: .light))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.12), radius: 3 * scale, x: 0, y: 1 * scale)

                ConvertedBubble(scale: scale)
                    .frame(width: 506 * scale, height: 112 * scale)
            }
            .padding(.top, 22 * scale)
        }
    }
}

private struct TextInputBubble: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text("kyouno meeting ha 3ji")
                .font(.system(size: 33 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)

            Rectangle()
                .fill(AppColor.ink)
                .frame(width: max(1, 2 * scale), height: 42 * scale)
                .padding(.leading, 2 * scale)
        }
        .padding(.horizontal, 46 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.white.opacity(0.90), in: RoundedRectangle(cornerRadius: 28 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28 * scale, style: .continuous)
                .stroke(.white.opacity(0.86), lineWidth: 12 * scale)
        }
        .shadow(color: .black.opacity(0.08), radius: 18 * scale, x: 0, y: 8 * scale)
    }
}

private struct ConvertedBubble: View {
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 20 * scale) {
            Circle()
                .fill(AppColor.lavender.opacity(0.92))
                .frame(width: 54 * scale, height: 54 * scale)
                .overlay {
                    Image(systemName: "globe")
                        .font(.system(size: 30 * scale, weight: .regular))
                        .foregroundStyle(AppColor.purple.opacity(0.72))
                }

            Text("今日の meeting は 3時")
                .font(.system(size: 34 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 40 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.white.opacity(0.91), in: RoundedRectangle(cornerRadius: 28 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28 * scale, style: .continuous)
                .stroke(.white.opacity(0.86), lineWidth: 8 * scale)
        }
        .shadow(color: .black.opacity(0.08), radius: 18 * scale, x: 0, y: 8 * scale)
    }
}

private struct HeroTextArea: View {
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 18 * scale) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index == 0 ? AppColor.ink : AppColor.rule)
                        .frame(height: 9 * scale)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 44 * scale)

            Text("Type naturally in two languages")
                .font(.system(size: 41 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.top, 50 * scale)

            Text("Bikey understands whether you mean\nJapanese or English.")
                .font(.system(size: 27 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.muted)
                .lineSpacing(9 * scale)
                .padding(.top, 24 * scale)

            Spacer(minLength: 0)

            HStack {
                Spacer()

                Text("Try it")
                    .font(.system(size: 29 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 168 * scale, height: 80 * scale)
                    .background(Color(red: 0.145, green: 0.144, blue: 0.160).opacity(0.94), in: Capsule())
                    .shadow(color: .black.opacity(0.11), radius: 14 * scale, x: 0, y: 7 * scale)
            }
            .padding(.bottom, 36 * scale)
        }
        .padding(.horizontal, 42 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.89))
    }
}

private struct ExamplesHeader: View {
    let scale: CGFloat

    var body: some View {
        HStack {
            Text("Examples")
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
        .frame(height: 76 * scale)
        .padding(.horizontal, 18 * scale)
    }
}

private struct ExampleCard: View {
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Today")
                .font(.system(size: 25 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.muted)

            Text("今日のMTG、slidesだけ先に送るね")
                .font(.system(size: 34 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .padding(.top, 33 * scale)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("4:15 p.m.")
                .font(.system(size: 25 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.muted.opacity(0.78))
                .padding(.top, 28 * scale)
                .lineLimit(1)
        }
        .padding(.horizontal, 44 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 204 * scale)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 34 * scale, style: .continuous))
        .shadow(color: .black.opacity(0.045), radius: 22 * scale, x: 0, y: 12 * scale)
    }
}
