import Foundation

enum EditEventEditor: Identifiable {
    case generalInfo
    case criteria
    case location
    case description
    
    var id: Self { self }
}
