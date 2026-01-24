import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \GroceryTrip.date, order: .reverse) private var trips: [GroceryTrip]

    @State private var showingNewTrip = false

    var body: some View {
        NavigationStack {
            List {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No Trips Yet",
                        systemImage: "cart.badge.plus",
                        description: Text("Tap + to add your first grocery trip")
                    )
                } else {
                    ForEach(trips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tripTitle(for: trip))
                                    .font(.headline)
                                HStack {
                                    Text("\(trip.items.count) item\(trip.items.count == 1 ? "" : "s")")
                                    Spacer()
                                    Text(String(format: "%.2f", trip.totalSpent))
                                        .fontWeight(.medium)
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteTrips)
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewTrip = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTrip) {
                NavigationStack {
                    TripDetailView(trip: nil)
                }
            }
        }
    }

    private func tripTitle(for trip: GroceryTrip) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: trip.date)
        if let store = trip.storeName, !store.isEmpty {
            return "\(store) - \(dateStr)"
        }
        return dateStr
    }

    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            context.delete(trips[index])
        }
        try? context.save()
    }
}
