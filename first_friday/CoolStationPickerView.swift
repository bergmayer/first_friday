import SwiftUI

struct CoolStationPickerView: View {
    @Binding var selectedID: String
    @Binding var selectedName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if !selectedID.isEmpty {
                Section {
                    Button("Clear selection") {
                        selectedID = ""
                        selectedName = ""
                        dismiss()
                    }
                }
            }
            Section("Cool Stations") {
                ForEach(CoolStations.all) { station in
                    Button {
                        selectedID = station.id
                        selectedName = station.name
                        dismiss()
                    } label: {
                        HStack {
                            Text(station.name)
                            Spacer()
                            if station.id == selectedID {
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
