import SwiftUI

struct CoolStationPickerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if !settings.coolStationID.isEmpty {
                Section {
                    Button("Clear selection") {
                        settings.coolStationID = ""
                        settings.coolStationName = ""
                        dismiss()
                    }
                }
            }
            Section("Cool Stations") {
                ForEach(CoolStations.all) { station in
                    Button {
                        settings.coolStationID = station.id
                        settings.coolStationName = station.name
                        dismiss()
                    } label: {
                        HStack {
                            Text(station.name)
                            Spacer()
                            if station.id == settings.coolStationID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Cool Stations")
    }
}
