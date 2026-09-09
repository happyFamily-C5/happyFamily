import Foundation
import CoreLocation

struct AdminProfile {
    var companyName: String
    var companyAddress: String
    var phoneNumber: String
    var email: String
    var imageData: Data?

    /// Storage path of the workspace logo in the `workspace-logos` bucket,
    /// kept so an untouched logo is never rewritten (or wiped by "").
    var logoObjectPath: String?

    static let defaultProfile = AdminProfile(
        companyName: "EcoTouch Office",
        companyAddress: "Jl. Arjuna Utara No. 14D,\nTanjung Duren Selatan\nJakarta Barat",
        phoneNumber: "",
        email: "",
        imageData: nil,
        logoObjectPath: nil
    )
}

struct RegisterAccountDraft {
    let name: String
    let email: String
    let password: String
}
