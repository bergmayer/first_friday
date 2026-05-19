import SwiftUI

struct AppleMusicLiveStationPickerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if !settings.appleMusicLiveStationID.isEmpty {
                Section {
                    Button("Clear selection") {
                        settings.appleMusicLiveStationID = ""
                        settings.appleMusicLiveStationName = ""
                        dismiss()
                    }
                }
            }
            Section("Apple Music Live Stations") {
                ForEach(AppleMusicLiveStations.all) { station in
                    Button {
                        settings.appleMusicLiveStationID = station.id
                        settings.appleMusicLiveStationName = station.name
                        dismiss()
                    } label: {
                        HStack {
                            Text(station.name)
                            Spacer()
                            if station.id == settings.appleMusicLiveStationID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Live Stations")
    }
}
