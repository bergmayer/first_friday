import Foundation

struct AppleMusicLiveStation: Identifiable, Hashable, Sendable {
    // MusicItemID raw value, e.g. "ra.978194965"
    let id: String
    let name: String
}

// The six headline Apple Music live stations. IDs marked uncertain may need
// updating; if a station fails to load the user can try a different one.
enum AppleMusicLiveStations {
    static let all: [AppleMusicLiveStation] = [
        .init(id: "ra.978194965",  name: "Apple Music 1"),
        .init(id: "ra.1232231840", name: "Apple Music Hits"),
        .init(id: "ra.1232231839", name: "Apple Music Country"),
        .init(id: "ra.1556093213", name: "Apple Music Classical"),     // uncertain
        .init(id: "ra.1591636980", name: "Apple Music Chill"),         // uncertain
        .init(id: "ra.1591635936", name: "Apple Music Club"),          // uncertain
    ]

    static func find(id: String) -> AppleMusicLiveStation? {
        all.first { $0.id == id }
    }
}
