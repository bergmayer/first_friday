import Foundation

struct RadioStation: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let url: String
}

// Curated station list. URLs verified against the stations' own players in
// May 2026. BBC streams use direct Akamai HLS endpoints — they may serve
// reduced bitrates outside the UK but are accessible internationally.
enum CoolStations {
    static let all: [RadioStation] = [
        .init(id: "wfmu",      name: "WFMU",              url: "https://stream0.wfmu.org/freeform-128k"),
        .init(id: "kexp",      name: "KEXP",              url: "https://kexp-mp3-128.streamguys1.com/kexp128.mp3"),
        .init(id: "kcrw",      name: "KCRW",              url: "https://streams.kcrw.com/kcrw_mp3"),
        .init(id: "wprb",      name: "WPRB",              url: "https://wprb.streamguys1.com/listen.mp3"),
        .init(id: "wamu",      name: "WAMU",              url: "https://wamu.cdnstream1.com/wamu.mp3"),
        .init(id: "weta",      name: "WETA Classical",    url: "https://weta.streamguys1.com/wetaclassical-icy"),
        .init(id: "radio1190", name: "Radio 1190",        url: "http://kvcu.streamguys1.com/live"),
        .init(id: "nts",       name: "NTS Radio 1",       url: "https://stream-relay-geo.ntslive.net/stream"),
        .init(id: "nts2",      name: "NTS Radio 2",       url: "https://stream-relay-geo.ntslive.net/stream2"),
        .init(id: "bbcworld",  name: "BBC World Service", url: "https://as-hls-ww-live.akamaized.net/pool_87948813/live/ww/bbc_world_service/bbc_world_service.isml/bbc_world_service-audio%3d96000.norewind.m3u8"),
        .init(id: "bbc1",      name: "BBC Radio 1",       url: "https://as-hls-ww-live.akamaized.net/pool_01505109/live/ww/bbc_radio_one/bbc_radio_one.isml/bbc_radio_one-audio%3d96000.norewind.m3u8"),
        .init(id: "bbc2",      name: "BBC Radio 2",       url: "https://as-hls-ww-live.akamaized.net/pool_74208725/live/ww/bbc_radio_two/bbc_radio_two.isml/bbc_radio_two-audio%3d96000.norewind.m3u8"),
        .init(id: "bbc3",      name: "BBC Radio 3",       url: "https://as-hls-ww-live.akamaized.net/pool_23461179/live/ww/bbc_radio_three/bbc_radio_three.isml/bbc_radio_three-audio%3d96000.norewind.m3u8"),
        .init(id: "bbc4",      name: "BBC Radio 4",       url: "https://as-hls-ww-live.akamaized.net/pool_55057080/live/ww/bbc_radio_fourfm/bbc_radio_fourfm.isml/bbc_radio_fourfm-audio%3d96000.norewind.m3u8"),
    ]

    static func find(id: String) -> RadioStation? {
        all.first { $0.id == id }
    }
}
