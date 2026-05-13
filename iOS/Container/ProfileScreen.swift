import SwiftUI
import UIKit

struct ProfileScreen: View {
    let scale: CGFloat
    let horizontalInset: CGFloat

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ProfileTopControls(scale: scale)
                    .padding(.top, 72 * scale)

                ProfileCard(scale: scale)
                    .padding(.top, 42 * scale)

                ProfileSectionTitle("Activity", scale: scale)
                    .padding(.top, 56 * scale)

                ProfileListCard(
                    rows: [
                        .init(icon: "chart.bar", title: "Typing Statistics"),
                        .init(icon: "flame", title: "Streak History"),
                        .init(icon: "clock", title: "Time Saved"),
                        .init(icon: "medal", title: "Achievements")
                    ],
                    scale: scale
                )
                .padding(.top, 17 * scale)

                ProfileSectionTitle("Account", scale: scale)
                    .padding(.top, 42 * scale)

                ProfileListCard(
                    rows: [
                        .init(icon: "person", title: "Personal Information"),
                        .init(icon: "crown", title: "Plan", trailing: "Bikey Pro"),
                        .init(icon: "gift", title: "Invite a Friend")
                    ],
                    scale: scale
                )
                .padding(.top, 17 * scale)

                Spacer(minLength: 178 * scale)
            }
            .padding(.horizontal, horizontalInset)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ProfileTopControls: View {
    let scale: CGFloat

    var body: some View {
        HStack {
            ProfileCircleButton(systemName: "chevron.left", scale: scale)

            Spacer()

            ProfileCircleButton(systemName: "gearshape", scale: scale)
        }
    }
}

private struct ProfileCircleButton: View {
    let systemName: String
    let scale: CGFloat

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.54))
            .frame(width: 68 * scale, height: 68 * scale)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 29 * scale, weight: .regular))
                    .foregroundStyle(Color(red: 0.230, green: 0.226, blue: 0.255))
            }
            .shadow(color: .black.opacity(0.045), radius: 12 * scale, x: 0, y: 6 * scale)
    }
}

private struct ProfileCard: View {
    let scale: CGFloat

    var body: some View {
        ZStack {
            ProfileCardBackground()

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 27 * scale) {
                    ProfilePortrait(scale: scale)
                        .frame(width: 112 * scale, height: 112 * scale)

                    VStack(alignment: .leading, spacing: 8 * scale) {
                        HStack(spacing: 12 * scale) {
                            Text("Kris Wu")
                                .font(.system(size: 40 * scale, weight: .regular, design: .rounded))
                                .foregroundStyle(.white)

                            Text("PRO")
                                .font(.system(size: 14 * scale, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.88))
                                .padding(.horizontal, 10 * scale)
                                .frame(height: 25 * scale)
                                .background(.white.opacity(0.18), in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(.white.opacity(0.45), lineWidth: max(1, 1 * scale))
                                }
                        }

                        Text("32,345 words typed\nwith Bikey")
                            .font(.system(size: 22 * scale, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineSpacing(5 * scale)
                    }

                    Spacer()
                }

                HStack(spacing: 0) {
                    ProfileStat(value: "158", label: "WPM", scale: scale)
                    ProfileStat(value: "10", label: "Hours Saved", scale: scale)
                    ProfileStat(value: "8", label: "Day Streak", scale: scale)
                }
                .padding(.top, 54 * scale)

                Rectangle()
                    .fill(.white.opacity(0.22))
                    .frame(height: max(1, 1 * scale))
                    .padding(.top, 38 * scale)

                HStack(alignment: .center, spacing: 0) {
                    HStack(spacing: 23 * scale) {
                        RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                            .fill(.white.opacity(0.20))
                            .frame(width: 58 * scale, height: 58 * scale)
                            .overlay {
                                Image(systemName: "keyboard")
                                    .font(.system(size: 29 * scale, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.88))
                            }

                        VStack(alignment: .leading, spacing: 8 * scale) {
                            Text("Bikey")
                                .font(.system(size: 31 * scale, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Type Japanese and English\nwithout switching.")
                                .font(.system(size: 20 * scale, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.76))
                                .lineSpacing(4 * scale)
                        }
                    }

                    Spacer()

                    QRPlaceholder(scale: scale)
                        .frame(width: 156 * scale, height: 156 * scale)
                }
                .padding(.top, 38 * scale)
            }
            .padding(.top, 42 * scale)
            .padding(.horizontal, 42 * scale)
            .padding(.bottom, 38 * scale)
        }
        .frame(height: 530 * scale)
        .clipShape(RoundedRectangle(cornerRadius: 42 * scale, style: .continuous))
        .shadow(color: AppColor.purple.opacity(0.18), radius: 26 * scale, x: 0, y: 16 * scale)
    }
}

private struct ProfileCardBackground: View {
    var body: some View {
        if let image = loadHeroImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .overlay(Color(red: 0.350, green: 0.250, blue: 0.680).opacity(0.34))
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
    }

    private func loadHeroImage() -> UIImage? {
        if let url = Bundle.main.url(forResource: "bg", withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            return image
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return UIImage(contentsOfFile: repoRoot.appendingPathComponent("public/bg.png").path)
    }
}

private struct ProfilePortrait: View {
    let scale: CGFloat

    var body: some View {
        Circle()
            .fill(.white)
            .overlay {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.930, green: 0.925, blue: 0.918))

                    Circle()
                        .fill(Color(red: 0.120, green: 0.122, blue: 0.132))
                        .frame(width: 47 * scale, height: 47 * scale)
                        .offset(y: 34 * scale)

                    Circle()
                        .fill(Color(red: 0.780, green: 0.700, blue: 0.640))
                        .frame(width: 38 * scale, height: 42 * scale)
                        .offset(y: -5 * scale)

                    RoundedRectangle(cornerRadius: 17 * scale, style: .continuous)
                        .fill(Color(red: 0.058, green: 0.060, blue: 0.067))
                        .frame(width: 56 * scale, height: 34 * scale)
                        .offset(y: -30 * scale)

                    Circle()
                        .fill(Color(red: 0.095, green: 0.097, blue: 0.105))
                        .frame(width: 78 * scale, height: 72 * scale)
                        .offset(y: 67 * scale)
                }
                .clipShape(Circle())
            }
    }
}

private struct ProfileStat: View {
    let value: String
    let label: String
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 11 * scale) {
            Text(value)
                .font(.system(size: 29 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 21 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct QRPlaceholder: View {
    let scale: CGFloat

    private let filledCells: Set<Int> = [
        0, 1, 2, 4, 7, 8, 9, 11, 14, 15, 16, 18, 20, 23,
        25, 28, 31, 33, 35, 37, 40, 43, 44, 46, 47, 49,
        51, 53, 56, 58, 60, 63, 64, 66, 68, 70, 73, 75,
        77, 78, 80, 82, 85, 88, 90, 92, 94, 96, 98, 100,
        103, 105, 107, 109, 111, 113, 116, 118, 119, 121,
        123, 126, 128, 130, 132, 134, 136, 139, 141, 143
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7 * scale, style: .continuous)
                .fill(.white.opacity(0.88))

            VStack(spacing: 5 * scale) {
                ForEach(0..<12, id: \.self) { row in
                    HStack(spacing: 5 * scale) {
                        ForEach(0..<12, id: \.self) { column in
                            let index = row * 12 + column
                            RoundedRectangle(cornerRadius: 1.4 * scale, style: .continuous)
                                .fill(filledCells.contains(index) ? AppColor.purple.opacity(0.76) : Color.clear)
                                .frame(width: 7 * scale, height: 7 * scale)
                        }
                    }
                }
            }

            QRCorner(scale: scale)
                .frame(width: 32 * scale, height: 32 * scale)
                .offset(x: -51 * scale, y: -51 * scale)

            QRCorner(scale: scale)
                .frame(width: 32 * scale, height: 32 * scale)
                .offset(x: 51 * scale, y: -51 * scale)

            QRCorner(scale: scale)
                .frame(width: 32 * scale, height: 32 * scale)
                .offset(x: -51 * scale, y: 51 * scale)
        }
    }
}

private struct QRCorner: View {
    let scale: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 3 * scale, style: .continuous)
            .stroke(AppColor.purple.opacity(0.76), lineWidth: 5 * scale)
            .background(
                RoundedRectangle(cornerRadius: 2 * scale, style: .continuous)
                    .fill(.white.opacity(0.75))
                    .padding(8 * scale)
            )
    }
}

private struct ProfileSectionTitle: View {
    let title: String
    let scale: CGFloat

    init(_ title: String, scale: CGFloat) {
        self.title = title
        self.scale = scale
    }

    var body: some View {
        Text(title)
            .font(.system(size: 27 * scale, weight: .regular, design: .rounded))
            .foregroundStyle(Color(red: 0.475, green: 0.468, blue: 0.512))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 22 * scale)
    }
}

private struct ProfileListCard: View {
    let rows: [ProfileRowModel]
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                ProfileListRow(model: row, scale: scale)

                if index < rows.count - 1 {
                    Divider()
                        .padding(.leading, 112 * scale)
                }
            }
        }
        .background(.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 31 * scale, style: .continuous))
        .shadow(color: .black.opacity(0.035), radius: 18 * scale, x: 0, y: 10 * scale)
    }
}

private struct ProfileRowModel {
    let icon: String
    let title: String
    let trailing: String?

    init(icon: String, title: String, trailing: String? = nil) {
        self.icon = icon
        self.title = title
        self.trailing = trailing
    }
}

private struct ProfileListRow: View {
    let model: ProfileRowModel
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 28 * scale) {
            Image(systemName: model.icon)
                .font(.system(size: 31 * scale, weight: .regular))
                .foregroundStyle(AppColor.purple.opacity(0.48))
                .frame(width: 40 * scale)

            Text(model.title)
                .font(.system(size: 27 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            if let trailing = model.trailing {
                Text(trailing)
                    .font(.system(size: 24 * scale, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.purple.opacity(0.74))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 24 * scale, weight: .regular))
                .foregroundStyle(Color.black.opacity(0.22))
        }
        .padding(.horizontal, 48 * scale)
        .frame(height: 82 * scale)
    }
}
