import KeyboardCore
import SwiftUI
import UIKit

struct ProfileScreen: View {
    let scale: CGFloat
    let horizontalInset: CGFloat
    let onShowOnboarding: () -> Void
    @State private var compositionDisplayMode = KeyboardSettingsStore.readCompositionDisplayMode()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ProfileTopControls(scale: scale)
                    .padding(.top, 72 * scale)

                ProfileCard(scale: scale)
                    .padding(.top, 42 * scale)

                ProfileSectionTitle("Account", scale: scale)
                    .padding(.top, 56 * scale)

                ProfileListCard(
                    rows: [
                        .init(icon: "person", title: "Personal Information"),
                        .init(
                            icon: "character.cursor.ibeam",
                            title: "Language Mode",
                            toggle: .languageMode
                        ),
                        .init(
                            icon: "sparkles",
                            title: "View Onboarding",
                            action: onShowOnboarding
                        ),
                        .init(icon: "crown", title: "Plan", trailing: "Bikey Pro"),
                        .init(icon: "gift", title: "Invite a Friend")
                    ],
                    compositionDisplayMode: $compositionDisplayMode,
                    scale: scale
                )
                .padding(.top, 17 * scale)

                Spacer(minLength: 178 * scale)
            }
            .padding(.horizontal, horizontalInset)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            compositionDisplayMode = KeyboardSettingsStore.readCompositionDisplayMode()
        }
        .onChange(of: compositionDisplayMode) { newValue in
            KeyboardSettingsStore.writeCompositionDisplayMode(newValue)
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
                                .font(.system(size: 44 * scale, weight: .regular, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.84)

                            Text("PRO")
                                .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.88))
                                .padding(.horizontal, 12 * scale)
                                .frame(height: 29 * scale)
                                .background(.white.opacity(0.18), in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(.white.opacity(0.45), lineWidth: max(1, 1 * scale))
                                }
                        }

                        Text("32,345 words typed\nwith Bikey")
                            .font(.system(size: 26 * scale, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineSpacing(7 * scale)
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
                                .font(.system(size: 34 * scale, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Type Japanese and English\nwithout switching.")
                                .font(.system(size: 24 * scale, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.76))
                                .lineSpacing(6 * scale)
                        }
                    }

                    Spacer()
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
            .fill(.white.opacity(0.92))
            .overlay {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 102 * scale, weight: .regular))
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
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 11 * scale) {
            Text(value)
                .font(.system(size: 32 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 24 * scale, weight: .regular, design: .rounded))
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
            .font(.system(size: 38 * scale, weight: .regular, design: .rounded))
            .foregroundStyle(Color(red: 0.475, green: 0.468, blue: 0.512))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 22 * scale)
    }
}

private struct ProfileListCard: View {
    let rows: [ProfileRowModel]
    var compositionDisplayMode: Binding<CompositionDisplayMode>? = nil
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                ProfileListRow(
                    model: row,
                    compositionDisplayMode: compositionDisplayMode,
                    scale: scale
                )

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
    let scale: CGFloat

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
        HStack(spacing: 28 * scale) {
            Image(systemName: model.icon)
                .font(.system(size: 35 * scale, weight: .regular))
                .foregroundStyle(AppColor.purple.opacity(0.48))
                .frame(width: 40 * scale)

            Text(model.title)
                .font(.system(size: 32 * scale, weight: .regular, design: .rounded))
                .foregroundStyle(AppColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            if model.toggle == .languageMode, compositionDisplayMode != nil {
                Toggle("", isOn: isJapaneseHeavy)
                    .labelsHidden()
                    .tint(AppColor.purple.opacity(0.82))
                    .scaleEffect(scale)
                    .frame(width: 52 * scale, height: 32 * scale)
            } else if let trailing = model.trailing {
                Text(trailing)
                    .font(.system(size: 30 * scale, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColor.purple.opacity(0.74))
            }

            if model.toggle == nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 26 * scale, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.22))
            }
        }
        .padding(.horizontal, 48 * scale)
        .frame(height: 102 * scale)
    }
}
