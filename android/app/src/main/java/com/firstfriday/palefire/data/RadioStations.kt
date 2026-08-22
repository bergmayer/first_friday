package com.firstfriday.palefire.data

data class RadioStation(
    val id: String,
    val name: String,
    val url: String,
)

object RadioStations {
    val all = listOf(
        RadioStation("wfmu", "WFMU", "https://stream0.wfmu.org/freeform-128k"),
        RadioStation("kexp", "KEXP", "https://kexp-mp3-128.streamguys1.com/kexp128.mp3"),
        RadioStation("kcrw", "KCRW", "https://streams.kcrw.com/kcrw_mp3"),
        RadioStation("wprb", "WPRB", "https://wprb.streamguys1.com/listen.mp3"),
        RadioStation("wamu", "WAMU", "https://wamu.cdnstream1.com/wamu.mp3"),
        RadioStation("weta", "WETA Classical", "https://weta.streamguys1.com/wetaclassical-icy"),
        RadioStation("radio1190", "Radio 1190", "http://kvcu.streamguys1.com/live"),
        RadioStation("nts", "NTS Radio 1", "https://stream-relay-geo.ntslive.net/stream"),
        RadioStation("nts2", "NTS Radio 2", "https://stream-relay-geo.ntslive.net/stream2"),
        RadioStation(
            "bbcworld",
            "BBC World Service",
            "https://as-hls-ww-live.akamaized.net/pool_87948813/live/ww/bbc_world_service/bbc_world_service.isml/bbc_world_service-audio%3d96000.norewind.m3u8",
        ),
        RadioStation(
            "bbc1",
            "BBC Radio 1",
            "https://as-hls-ww-live.akamaized.net/pool_01505109/live/ww/bbc_radio_one/bbc_radio_one.isml/bbc_radio_one-audio%3d96000.norewind.m3u8",
        ),
        RadioStation(
            "bbc2",
            "BBC Radio 2",
            "https://as-hls-ww-live.akamaized.net/pool_74208725/live/ww/bbc_radio_two/bbc_radio_two.isml/bbc_radio_two-audio%3d96000.norewind.m3u8",
        ),
        RadioStation(
            "bbc3",
            "BBC Radio 3",
            "https://as-hls-ww-live.akamaized.net/pool_23461179/live/ww/bbc_radio_three/bbc_radio_three.isml/bbc_radio_three-audio%3d96000.norewind.m3u8",
        ),
        RadioStation(
            "bbc4",
            "BBC Radio 4",
            "https://as-hls-ww-live.akamaized.net/pool_55057080/live/ww/bbc_radio_fourfm/bbc_radio_fourfm.isml/bbc_radio_fourfm-audio%3d96000.norewind.m3u8",
        ),
    )

    fun find(id: String): RadioStation? = all.firstOrNull { it.id == id }
}
