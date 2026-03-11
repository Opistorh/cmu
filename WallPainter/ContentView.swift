import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack(alignment: .top) {
            ARWallScannerView()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 8) {
                Text("Wall Painter")
                    .font(.headline)
                Text("Наведите камеру на стены. Найденные вертикальные поверхности будут подсвечены.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
