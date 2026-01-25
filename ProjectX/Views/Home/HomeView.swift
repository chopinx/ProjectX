import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scanFlowManager) private var flowManager
    @Query(sort: \GroceryTrip.date, order: .reverse) private var trips: [GroceryTrip]

    @State private var showingNewTrip = false
    @State private var showingAddOptions = false
    @State private var tripToDelete: GroceryTrip?

    var body: some View {
        NavigationStack {
            List {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No Trips Yet",
                        systemImage: "cart.badge.plus",
                        description: Text("Tap + to add your first grocery trip, or use Scan to import a receipt")
                    )
                } else {
                    ForEach(trips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip)
                        } label: {
                            TripRow(trip: trip, title: tripTitle(for: trip))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                tripToDelete = trip
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddOptions = true } label: {
                        Label("Add Trip", systemImage: "plus")
                    }
                }
            }
            .confirmationDialog("Add Trip", isPresented: $showingAddOptions, titleVisibility: .visible) {
                Button("Scan Receipt") { flowManager.requestScanForReceipt() }
                Button("Manual Entry") { showingNewTrip = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("How would you like to add a grocery trip?")
            }
            .sheet(isPresented: $showingNewTrip) {
                NavigationStack { TripDetailView(trip: nil) }
            }
            .deleteConfirmation("Delete Trip?", item: $tripToDelete, message: { trip in
                "This will permanently delete \"\(tripTitle(for: trip))\" and all its items."
            }) { trip in
                withAnimation { context.delete(trip) }
                try? context.save()
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

}

// MARK: - Trip Row

private struct TripRow: View {
    let trip: GroceryTrip
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            HStack {
                Text("\(trip.items.count) item\(trip.items.count == 1 ? "" : "s")")
                Spacer()
                Text(String(format: "%.2f", trip.totalSpent))
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // Show nutrition if any items have nutrition data
            if trip.itemsWithNutrition > 0 {
                NutritionSummaryRow(nutrition: trip.totalNutrition, isCompact: false)
            }
        }
    }
}
