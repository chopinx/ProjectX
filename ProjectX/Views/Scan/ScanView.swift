import SwiftUI

struct ScanView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(.tertiary)

                VStack(spacing: 8) {
                    Text("Receipt Scanning")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Coming Soon")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text("In a future version, you'll be able to photograph grocery receipts and have AI extract all items automatically.\n\nFor now, add trips manually from the Home tab.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Scan")
        }
    }
}
