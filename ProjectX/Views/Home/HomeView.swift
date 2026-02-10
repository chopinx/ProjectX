import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \GroceryTrip.date, order: .reverse) private var allTrips: [GroceryTrip]
    @Bindable var settings: AppSettings
    @State private var tripToDelete: GroceryTrip?

    init(settings: AppSettings) {
        self.settings = settings
    }

    private var trips: [GroceryTrip] {
        guard let profileId = settings.activeProfileId else { return allTrips }
        return allTrips.filter { $0.profile?.id == profileId }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No Trips Yet",
                        systemImage: "cart.badge.plus",
                        description: Text("Use the + button to add your first grocery trip")
                    )
                } else {
                    ForEach(trips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip, settings: settings)
                        } label: {
                            TripRow(trip: trip, title: tripTitle(for: trip))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                DispatchQueue.main.async { tripToDelete = trip }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileToolbarButton(settings: settings)
                }
            }
        }
        .deleteConfirmation("Delete Trip?", item: $tripToDelete, message: { trip in
            "Delete trip with \(trip.items.count) item\(trip.items.count == 1 ? "" : "s")? This cannot be undone."
        }) { trip in
            context.delete(trip)
            try? context.save()
        }
    }

    private func tripTitle(for trip: GroceryTrip) -> String {
        let dateStr = Self.dateFormatter.string(from: trip.date)
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
                Text(trip.totalSpent, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
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
