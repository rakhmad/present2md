import SwiftUI

struct TimeoutAlertView: View {
    let jobID: UUID
    @EnvironmentObject var coordinator: ConversionCoordinator

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Conversion is taking longer than expected.")
                .font(.headline)
            Text("Continue waiting or cancel this file?")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Cancel Conversion") {
                    coordinator.cancelJob(id: jobID)
                }
                .buttonStyle(.bordered)
                Button("Keep Waiting") {
                    coordinator.continueJob(id: jobID)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(minWidth: 320)
    }
}
