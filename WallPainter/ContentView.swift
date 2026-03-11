import SwiftUI

struct ContentView: View {
    private enum Screen {
        case menu
        case wallScanner
        case placeholder
    }

    @State private var currentScreen: Screen = .menu
    @State private var showDepthOverlay = true

    var body: some View {
        Group {
            switch currentScreen {
            case .menu:
                MainMenuView(
                    openWallScanner: { currentScreen = .wallScanner },
                    openPlaceholder: { currentScreen = .placeholder }
                )
            case .wallScanner:
                WallScannerScreen(
                    showDepthOverlay: $showDepthOverlay,
                    goBack: { currentScreen = .menu }
                )
            case .placeholder:
                PlaceholderScreen(goBack: { currentScreen = .menu })
            }
        }
    }
}

private struct MainMenuView: View {
    let openWallScanner: () -> Void
    let openPlaceholder: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.16, blue: 0.22), Color(red: 0.03, green: 0.08, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Spacer()

                Text("Wall Painter")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Выберите режим работы.")
                    .font(.title3)
                    .foregroundStyle(Color.white.opacity(0.75))

                Button(action: openWallScanner) {
                    MenuCard(
                        title: "Сканер стен",
                        subtitle: "Текущий AR-режим с LiDAR depth overlay и подсветкой найденных стен.",
                        accent: Color(red: 0.45, green: 1.0, blue: 0.18)
                    )
                }
                .buttonStyle(.plain)

                Button(action: openPlaceholder) {
                    MenuCard(
                        title: "Второй режим",
                        subtitle: "Пока пустой экран-заглушка. Дальше наполним его отдельно.",
                        accent: Color(red: 0.08, green: 0.78, blue: 1.0)
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(24)
        }
    }
}

private struct MenuCard: View {
    let title: String
    let subtitle: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Circle()
                    .fill(accent)
                    .frame(width: 14, height: 14)
            }

            Text(subtitle)
                .font(.body)
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accent.opacity(0.5), lineWidth: 1)
        )
    }
}

private struct WallScannerScreen: View {
    @Binding var showDepthOverlay: Bool
    let goBack: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ARWallScannerView(showDepthOverlay: $showDepthOverlay)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: goBack) {
                        Label("Menu", systemImage: "chevron.left")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black.opacity(0.75))

                    Spacer()

                    Toggle("LiDAR depth", isOn: $showDepthOverlay)
                        .labelsHidden()
                }

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

private struct PlaceholderScreen: View {
    let goBack: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.09, blue: 0.12), Color(red: 0.14, green: 0.18, blue: 0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button(action: goBack) {
                        Label("Menu", systemImage: "chevron.left")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black.opacity(0.75))

                    Spacer()
                }

                Spacer()

                Text("Второй режим")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Пока это пустой экран. Здесь будет следующий режим приложения.")
                    .font(.title3)
                    .foregroundStyle(Color.white.opacity(0.78))

                Spacer()
            }
            .padding(24)
        }
    }
}

#Preview {
    ContentView()
}
