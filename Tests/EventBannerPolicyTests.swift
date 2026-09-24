import Foundation
@testable import happyFamily
import ImageIO
import Testing
import UIKit

@Suite("Event banner policy")
@MainActor
struct EventBannerPolicyTests {
    @Test("Empty banners do not require an upload")
    func emptyBannersReturnNil() async throws {
        #expect(try await EventBannerPolicy.prepareForUpload(nil) == nil)
        #expect(try await EventBannerPolicy.prepareForUpload(Data()) == nil)
    }

    @Test("Exact 16:9 JPEG is uploaded unchanged")
    func compliantJPEGStaysUnchanged() async throws {
        let data = imageData(width: 320, height: 180, format: .jpeg)

        let prepared = try #require(await EventBannerPolicy.prepareForUpload(data))

        #expect(prepared.data == data)
        #expect(prepared.contentType == "image/jpeg")
        #expect(prepared.width == 320)
        #expect(prepared.height == 180)
    }

    @Test("Exact 16:9 PNG is uploaded unchanged")
    func compliantPNGStaysUnchanged() async throws {
        let data = imageData(width: 320, height: 180, format: .png)

        let prepared = try #require(await EventBannerPolicy.prepareForUpload(data))

        #expect(prepared.data == data)
        #expect(prepared.contentType == "image/png")
        #expect(prepared.width == 320)
        #expect(prepared.height == 180)
    }

    @Test("Portrait JPEG is center-cropped to 16:9")
    func portraitJPEGIsCropped() async throws {
        let data = imageData(width: 120, height: 240, format: .jpeg)

        let prepared = try #require(await EventBannerPolicy.prepareForUpload(data))

        #expect(prepared.contentType == "image/jpeg")
        #expect(isSixteenByNine(prepared))
        #expect(prepared.width > prepared.height)
        #expect(prepared.data != data)
    }

    @Test("Portrait PNG is converted and center-cropped to 16:9")
    func portraitPNGIsCropped() async throws {
        let data = imageData(width: 120, height: 240, format: .png)

        let prepared = try #require(await EventBannerPolicy.prepareForUpload(data))

        #expect(prepared.contentType == "image/jpeg")
        #expect(isSixteenByNine(prepared))
        #expect(prepared.width > prepared.height)
        #expect(prepared.data != data)
    }

    @Test("Landscape 4:3 is cropped without stretching")
    func landscapeFourByThreeIsCropped() async throws {
        let data = imageData(width: 240, height: 180, format: .jpeg)

        let prepared = try #require(await EventBannerPolicy.prepareForUpload(data))

        #expect(isSixteenByNine(prepared))
        #expect(prepared.width > prepared.height)
    }

    @Test("Prepared banners are idempotent")
    func preparedBannerIsNotReencoded() async throws {
        let source = imageData(width: 120, height: 240, format: .jpeg)
        let first = try #require(await EventBannerPolicy.prepareForUpload(source))
        let second = try #require(await EventBannerPolicy.prepareForUpload(first.data))

        #expect(second == first)
    }

    @Test("Images above the server dimension limit are resized")
    func oversizedDimensionsAreResized() async throws {
        let data = imageData(
            width: EventBannerPolicy.maximumDimension + 1,
            height: 8,
            format: .png
        )

        let prepared = try #require(await EventBannerPolicy.prepareForUpload(data))
        let dimensions = try #require(dimensions(of: prepared.data))

        #expect(prepared.contentType == "image/jpeg")
        #expect(dimensions.width <= EventBannerPolicy.maximumDimension)
        #expect(dimensions.height <= EventBannerPolicy.maximumDimension)
        #expect(dimensions.width > dimensions.height)
        #expect(prepared.data.count <= EventBannerPolicy.maximumBytes)
    }

    @Test("Malformed banners are rejected before a draft is queued")
    func malformedDataIsRejected() async {
        let malformed = Data([0x00, 0x01, 0x02, 0x03])

        await #expect(throws: BackendError.self) {
            try await EventBannerPolicy.prepareForUpload(malformed)
        }
    }

    @Test("Legacy validation still rejects files above the byte limit")
    func legacyValidationRejectsOversizedData() {
        var oversized = Data([0xFF, 0xD8, 0xFF, 0xE0])
        oversized.append(Data(count: EventBannerPolicy.maximumBytes))

        #expect(oversized.count > EventBannerPolicy.maximumBytes)
        #expect(throws: BackendError.self) {
            try EventBannerPolicy.validate(oversized)
        }
    }

    private enum ImageFormat {
        case jpeg
        case png
    }

    private func imageData(width: Int, height: Int, format: ImageFormat) -> Data {
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 1
        rendererFormat.opaque = true
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: rendererFormat
        ).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        switch format {
        case .jpeg:
            return image.jpegData(compressionQuality: 0.9)!
        case .png:
            return image.pngData()!
        }
    }

    private func dimensions(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            return nil
        }
        return (width, height)
    }

    private func isSixteenByNine(_ banner: PreparedEventBanner) -> Bool {
        banner.width * 9 == banner.height * 16
    }
}
