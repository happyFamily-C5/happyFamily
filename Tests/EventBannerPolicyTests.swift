import Testing
import Foundation
@testable import happyFamily

@Suite("Event banner policy")
struct EventBannerPolicyTests {
    private let pngMagic = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    private let jpegMagic = Data([0xFF, 0xD8, 0xFF, 0xE0])

    @Test func acceptsJpegAndPngWithinLimit() throws {
        #expect(try EventBannerPolicy.validate(nil) == ())
        #expect(try EventBannerPolicy.validate(Data()) == ())
        #expect(try EventBannerPolicy.validate(pngMagic) == ())
        #expect(try EventBannerPolicy.validate(jpegMagic) == ())
        #expect(EventBannerPolicy.isSupportedFormat(pngMagic))
        #expect(EventBannerPolicy.isSupportedFormat(jpegMagic))
    }

    @Test func rejectsUnsupportedFormat() {
        let heic = Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70])
        #expect(!EventBannerPolicy.isSupportedFormat(heic))
        #expect(throws: BackendError.self) {
            try EventBannerPolicy.validate(heic)
        }
    }

    @Test func rejectsOversizedImageWithoutRetry() {
        var oversized = jpegMagic
        oversized.append(Data(count: EventBannerPolicy.maximumBytes))
        #expect(oversized.count > EventBannerPolicy.maximumBytes)
        do {
            try EventBannerPolicy.validate(oversized)
            Issue.record("expected BANNER_TOO_LARGE")
        } catch let error as BackendError {
            guard case let .api(code, retryable, _, _) = error else {
                Issue.record("unexpected error: \(error)")
                return
            }
            #expect(code == "BANNER_TOO_LARGE")
            #expect(retryable == false)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }
}
