import SnapshotTesting
import SwiftUI
import XCTest

@testable import BilingualKeyboard

final class HomeSnapshotTests: XCTestCase {
    private let referenceSize = CGSize(width: HomeDesign.designWidth, height: HomeDesign.designHeight)

    func testHomeSnapshotBaseline() {
        let image = renderRootView(selectedTab: .home)
        assertSnapshot(of: image, as: .image(precision: 0.95, perceptualPrecision: 0.94), named: "home-baseline")
    }

    func testHomeMatchesProvidedReference() throws {
        let rendered = renderRootView(selectedTab: .home)
        let reference = try loadReferenceImage(path: "reference/newhome.png")
            .resized(to: referenceSize)
        let diff = normalizedPixelDifference(lhs: rendered, rhs: reference)
        XCTAssertLessThanOrEqual(
            diff,
            0.22,
            "Home screen drifted from reference/newhome.png. Normalized difference: \(diff)"
        )
    }

    func testProfileSnapshotBaseline() {
        let image = renderFullRootView(selectedTab: .profile)
        assertSnapshot(of: image, as: .image(precision: 0.95, perceptualPrecision: 0.94), named: "profile-baseline")
    }

    func testProfileMatchesProvidedReference() throws {
        let rendered = renderFullRootView(selectedTab: .profile)
        let reference = try loadReferenceImage(path: "reference/profile.png")
            .resized(to: referenceSize)
        let diff = normalizedPixelDifference(lhs: rendered, rhs: reference)
        XCTAssertLessThanOrEqual(
            diff,
            0.25,
            "Profile screen drifted from reference/profile.png. Normalized difference: \(diff)"
        )
    }

    private func renderRootView(selectedTab: AppTab) -> UIImage {
        let root = RootContainerViewForTests(initialTab: selectedTab)
            .frame(width: referenceSize.width, height: referenceSize.height)
            .preferredColorScheme(.light)
        let controller = UIHostingController(rootView: root)
        controller.view.bounds = CGRect(origin: .zero, size: referenceSize)
        controller.view.backgroundColor = .clear

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: referenceSize, format: format)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    private func renderFullRootView(selectedTab: AppTab) -> UIImage {
        let root = RootContainerView(initialTab: selectedTab)
            .frame(width: referenceSize.width, height: referenceSize.height)
            .preferredColorScheme(.light)
        let controller = UIHostingController(rootView: root)
        controller.view.bounds = CGRect(origin: .zero, size: referenceSize)
        controller.view.backgroundColor = .clear

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: referenceSize, format: format)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    private func loadReferenceImage(path: String) throws -> UIImage {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent() // ContainerTests
            .deletingLastPathComponent() // iOS
            .deletingLastPathComponent() // repo root
        let imageURL = repoRoot.appendingPathComponent(path)

        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            throw NSError(domain: "HomeSnapshotTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unable to load \(path)."
            ])
        }
        return image
    }

    private func normalizedPixelDifference(lhs: UIImage, rhs: UIImage) -> Double {
        guard let lhsData = lhs.rgbaBytes, let rhsData = rhs.rgbaBytes, lhsData.count == rhsData.count else {
            return 1
        }

        var totalDifference: Double = 0
        for index in 0..<lhsData.count {
            let lhsValue = Double(lhsData[index])
            let rhsValue = Double(rhsData[index])
            totalDifference += abs(lhsValue - rhsValue) / 255.0
        }
        return totalDifference / Double(lhsData.count)
    }
}

private struct RootContainerViewForTests: View {
    let initialTab: AppTab

    var body: some View {
        RootContainerViewTestHarness(initialTab: initialTab)
    }
}

private struct RootContainerViewTestHarness: View {
    let initialTab: AppTab
    @State private var selectedTab: AppTab

    init(initialTab: AppTab) {
        self.initialTab = initialTab
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
                    case .phrases, .keyboard, .profile:
                        Color.clear
                    }
                }
            }
        }
    }
}

private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    var rgbaBytes: [UInt8]? {
        guard let cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let count = width * height * bytesPerPixel

        var buffer = [UInt8](repeating: 0, count: count)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &buffer,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
