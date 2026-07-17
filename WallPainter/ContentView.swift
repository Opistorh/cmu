import PDFKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Vision

struct ContentView: View {
    private enum Screen {
        case menu
        case wallScanner
        case wallElevations
    }

    @State private var currentScreen: Screen = .menu
    @State private var showDepthOverlay = true

    var body: some View {
        Group {
            switch currentScreen {
            case .menu:
                MainMenuView(
                    openWallScanner: { currentScreen = .wallScanner },
                    openWallElevations: { currentScreen = .wallElevations }
                )
            case .wallScanner:
                WallScannerScreen(
                    showDepthOverlay: $showDepthOverlay,
                    goBack: { currentScreen = .menu }
                )
            case .wallElevations:
                WallElevationsScreen(goBack: { currentScreen = .menu })
            }
        }
    }
}

private struct MainMenuView: View {
    let openWallScanner: () -> Void
    let openWallElevations: () -> Void

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
                        subtitle: "AR-режим с LiDAR depth overlay и подсветкой найденных стен.",
                        accent: Color(red: 0.45, green: 1.0, blue: 0.18)
                    )
                }
                .buttonStyle(.plain)

                Button(action: openWallElevations) {
                    MenuCard(
                        title: "Развёртки из PDF",
                        subtitle: "Находит в дизайн-проекте страницы с развёртками стен, показывает превью и собирает отдельный PDF.",
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

private struct WallElevationsScreen: View {
    @StateObject private var viewModel = WallElevationExtractorViewModel()
    @State private var isImporterPresented = false

    let goBack: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.09, blue: 0.12), Color(red: 0.14, green: 0.18, blue: 0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    actionPanel
                    statusPanel

                    if viewModel.hasProjectBoard {
                        projectBoardSection
                    }

                    if let exportURL = viewModel.exportURL {
                        exportSection(exportURL: exportURL)
                    }
                }
                .padding(24)
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleImport(result)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: goBack) {
                    Label("Menu", systemImage: "chevron.left")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black.opacity(0.75))

                Spacer()
            }

            Text("Развёртки стен из PDF")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Загрузите дизайн-проект. Приложение найдёт общий план, свяжет помещения с развёртками стен и соберёт удобную доску проекта.")
                .font(.title3)
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: { isImporterPresented = true }) {
                Label(viewModel.sourceFileName == nil ? "Выбрать PDF" : "Выбрать другой PDF", systemImage: "doc.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.08, green: 0.78, blue: 1.0))

            if let sourceFileName = viewModel.sourceFileName {
                Label(sourceFileName, systemImage: "doc.text")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isAnalyzing {
                ProgressView(value: viewModel.progress)
                    .tint(.cyan)
                Text(viewModel.progressTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(viewModel.progressDetails)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                Text(viewModel.summaryTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(viewModel.summaryMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var projectBoardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Карта проекта")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            if let plan = viewModel.planMatch {
                ProjectBoardView(plan: plan, roomBoards: viewModel.roomBoards)
                    .frame(minHeight: 680)
            } else {
                Text("Общий план не найден автоматически. Развёртки сгруппированы по помещениям ниже.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(viewModel.roomBoards) { board in
                    RoomBoardCard(board: board)
                }
            }
        }
    }

    private func exportSection(exportURL: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Готовый файл")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(exportURL.lastPathComponent)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(3)
                .minimumScaleFactor(0.75)
                .textSelection(.enabled)

            ShareLink(item: exportURL) {
                Label("Поделиться PDF", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.45, green: 1.0, blue: 0.18))

            PDFPreviewContainer(url: exportURL)
                .frame(height: 420)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

@MainActor
private final class WallElevationExtractorViewModel: ObservableObject {
    struct WallSegment: Identifiable {
        let id = UUID()
        let label: String
        let preview: UIImage
        let pageNumber: Int
        let sourceTitle: String
    }

    struct Match: Identifiable {
        let id = UUID()
        let pageNumber: Int
        let title: String
        let reason: String
        let preview: UIImage
        let roomName: String?
        let score: Int
        let wallSegments: [WallSegment]
    }

    struct RoomBoard: Identifiable {
        let id = UUID()
        let roomName: String
        let walls: [WallSegment]
    }

    @Published private(set) var sourceFileName: String?
    @Published private(set) var planMatch: Match?
    @Published private(set) var roomBoards: [RoomBoard] = []
    @Published private(set) var exportURL: URL?
    @Published private(set) var isAnalyzing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var progressTitle = "Файл ещё не выбран"
    @Published private(set) var progressDetails = "Выберите PDF проекта, чтобы извлечь развёртки стен."
    @Published private(set) var errorMessage: String?

    var hasProjectBoard: Bool {
        planMatch != nil || !roomBoards.isEmpty
    }

    var summaryTitle: String {
        if let sourceFileName {
            return "Файл: \(sourceFileName)"
        }
        return "Загрузите дизайн-проект"
    }

    var summaryMessage: String {
        if hasProjectBoard {
            let planText = planMatch == nil ? "без найденного общего плана" : "с найденным общим планом"
            let wallCount = roomBoards.reduce(into: 0) { $0 += $1.walls.count }
            return "Собрана карта проекта \(planText): \(roomBoards.count) помещений, \(wallCount) стеновых фрагментов."
        }

        if sourceFileName != nil {
            return "Если связь не построилась, проверьте, есть ли на листах подписи вроде «Обмерный план», «Развертка стен» и названия помещений. Для сканов приложение дополнительно использует OCR."
        }

        return "Во втором разделе теперь можно выбирать PDF, автоматически находить общий план и группировать развёртки по помещениям."
    }

    func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                errorMessage = "Выбор PDF был отменён."
                return
            }
            analyze(url: url)
        case let .failure(error):
            errorMessage = "Не удалось открыть PDF: \(error.localizedDescription)"
        }
    }

    func analyze(url: URL) {
        sourceFileName = url.lastPathComponent
        planMatch = nil
        roomBoards = []
        exportURL = nil
        errorMessage = nil
        isAnalyzing = true
        progress = 0
        progressTitle = "Сканирую страницы"
        progressDetails = "Подготавливаю PDF к анализу."

        Task {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let preparedURL = try makeSandboxCopy(for: url)
                guard let document = PDFDocument(url: preparedURL) else {
                    throw ExtractorError.invalidPDF
                }

                let totalPages = document.pageCount
                guard totalPages > 0 else {
                    throw ExtractorError.emptyPDF
                }

                var detectedPlanCandidates: [Match] = []
                var detectedElevations: [Match] = []
                let extractor = WallElevationDetector()

                for pageIndex in 0 ..< totalPages {
                    guard let page = document.page(at: pageIndex) else { continue }

                    progress = Double(pageIndex) / Double(totalPages)
                    progressTitle = "Анализ страницы \(pageIndex + 1) из \(totalPages)"
                    progressDetails = "Ищу подписи развёрток в тексте PDF и через OCR."

                    let analysis = try await extractor.analyze(page: page, pageNumber: pageIndex + 1)
                    if let analysis {
                        switch analysis.kind {
                        case .plan:
                            detectedPlanCandidates.append(analysis.match)
                        case .elevation:
                            detectedElevations.append(analysis.match)
                        case .other:
                            break
                        }
                    }
                }

                progress = 1
                progressTitle = "Формирую результат"
                progressDetails = "Собираю найденные страницы в отдельный PDF."

                planMatch = detectedPlanCandidates.sorted(by: { $0.score > $1.score }).first
                roomBoards = makeRoomBoards(from: detectedElevations)
                exportURL = try makeExportPDF(from: document, matches: detectedElevations, sourceURL: preparedURL)
                isAnalyzing = false
            } catch {
                isAnalyzing = false
                planMatch = nil
                roomBoards = []
                exportURL = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    private func makeRoomBoards(from elevations: [Match]) -> [RoomBoard] {
        let grouped = Dictionary(grouping: elevations) { match in
            match.roomName ?? "Помещение без названия"
        }

        return grouped
            .map { key, value in
                let walls = value
                    .sorted(by: { $0.pageNumber < $1.pageNumber })
                    .flatMap { match -> [WallSegment] in
                        if match.wallSegments.isEmpty {
                            return [
                                WallSegment(
                                    label: "Лист",
                                    preview: match.preview,
                                    pageNumber: match.pageNumber,
                                    sourceTitle: match.title
                                )
                            ]
                        }
                        return match.wallSegments
                    }

                return RoomBoard(
                    roomName: key,
                    walls: walls
                )
            }
            .sorted(by: { $0.roomName.localizedCaseInsensitiveCompare($1.roomName) == .orderedAscending })
    }

    private func makeSandboxCopy(for url: URL) throws -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }

    private func makeExportPDF(from document: PDFDocument, matches: [Match], sourceURL: URL) throws -> URL? {
        guard !matches.isEmpty else {
            return nil
        }

        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent + "-развертки-стен")
            .appendingPathExtension("pdf")

        if FileManager.default.fileExists(atPath: exportURL.path) {
            try FileManager.default.removeItem(at: exportURL)
        }

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 1, height: 1))
        let data = renderer.pdfData { context in
            for match in matches {
                guard let page = document.page(at: match.pageNumber - 1) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                context.beginPage(withBounds: bounds, pageInfo: [:])
                page.draw(with: .mediaBox, to: context.cgContext)
            }
        }

        try data.write(to: exportURL, options: .atomic)
        return exportURL
    }
}

private struct ProjectBoardView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let plan: WallElevationExtractorViewModel.Match
    let roomBoards: [WallElevationExtractorViewModel.RoomBoard]

    var body: some View {
        Group {
            if horizontalSizeClass == .regular && roomBoards.count > 1 {
                let midpoint = Int(ceil(Double(roomBoards.count) / 2.0))
                let leftBoards = Array(roomBoards.prefix(midpoint))
                let rightBoards = Array(roomBoards.dropFirst(midpoint))

                HStack(alignment: .top, spacing: 18) {
                    boardColumn(leftBoards)
                        .frame(maxWidth: 280)

                    CentralPlanCard(plan: plan)
                        .frame(maxWidth: .infinity)

                    boardColumn(rightBoards)
                        .frame(maxWidth: 280)
                }
            } else {
                VStack(spacing: 18) {
                    CentralPlanCard(plan: plan)
                    boardColumn(roomBoards)
                }
            }
        }
    }

    private func boardColumn(_ boards: [WallElevationExtractorViewModel.RoomBoard]) -> some View {
        VStack(spacing: 16) {
            ForEach(boards) { board in
                RoomBoardCard(board: board)
            }
        }
    }
}

private struct CentralPlanCard: View {
    let plan: WallElevationExtractorViewModel.Match

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Общий план")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text("Страница \(plan.pageNumber)")
                .font(.subheadline)
                .foregroundStyle(.cyan)

            Image(uiImage: plan.preview)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text(plan.title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(plan.reason)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.12), Color.cyan.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct RoomBoardCard: View {
    let board: WallElevationExtractorViewModel.RoomBoard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(board.roomName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(board.walls.count) стен")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                }

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(board.walls) { wall in
                        VStack(alignment: .leading, spacing: 8) {
                            Image(uiImage: wall.preview)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 118, height: 148)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Text(wall.label)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.cyan)

                            Text("стр. \(wall.pageNumber)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)

                            Text(wall.sourceTitle)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: 118, alignment: .leading)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct PDFPreviewContainer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView(frame: .zero)
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

private actor WallElevationDetector {
    struct OCRTextObservation {
        let text: String
        let normalizedText: String
        let boundingBox: CGRect
    }

    enum MatchKind {
        case plan
        case elevation
        case other
    }

    struct AnalyzedPage {
        let kind: MatchKind
        let match: WallElevationExtractorViewModel.Match
    }

    func analyze(page: PDFPage, pageNumber: Int) async throws -> AnalyzedPage? {
        let pageText = normalize(page.string)
        let preview = page.thumbnail(of: CGSize(width: 320, height: 420), for: .mediaBox)
        let ocrObservations = try await recognizeTextObservations(in: preview)
        let ocrText = ocrObservations.map(\.normalizedText).joined(separator: "\n")
        let combinedText = [pageText, normalize(ocrText)]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        let planScore = scoreForPlan(in: combinedText)
        let elevationScore = scoreForElevation(in: combinedText)

        let kind: MatchKind
        let score: Int

        if planScore >= max(elevationScore + 2, 5) {
            kind = .plan
            score = planScore
        } else if elevationScore >= 4 {
            kind = .elevation
            score = elevationScore
        } else {
            return nil
        }

        let defaultTitle = kind == .plan ? "Вероятный общий план" : "Вероятная развёртка стен"
        let title = extractTitle(from: combinedText) ?? defaultTitle
        let reason = makeReason(from: combinedText, score: score, kind: kind)
        let roomName = kind == .elevation ? extractRoomName(from: combinedText, fallbackTitle: title) : nil
        let segmentSourceImage = kind == .elevation
            ? page.thumbnail(of: CGSize(width: 1400, height: 1800), for: .mediaBox)
            : preview
        let wallSegments = kind == .elevation
            ? makeWallSegments(
                from: segmentSourceImage,
                observations: ocrObservations,
                pageNumber: pageNumber,
                sourceTitle: title
            )
            : []
        let match = WallElevationExtractorViewModel.Match(
            pageNumber: pageNumber,
            title: kind == .plan ? (extractPlanTitle(from: combinedText) ?? title) : title,
            reason: reason,
            preview: preview,
            roomName: roomName,
            score: score,
            wallSegments: wallSegments
        )
        return AnalyzedPage(kind: kind, match: match)
    }

    private func scoreForPlan(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        var score = 0

        if text.contains("обмерный план") || text.contains("общий план") {
            score += 7
        }

        if text.contains("план помещения") || text.contains("план квартиры") || text.contains("план пола") {
            score += 4
        }

        if text.contains("экспликация") {
            score += 2
        }

        if text.contains("размер") || text.contains("обмер") {
            score += 2
        }

        if text.contains("помещени") {
            score += 1
        }

        return score
    }

    private func scoreForElevation(in text: String) -> Int {
        guard !text.isEmpty else { return 0 }

        var score = 0

        if text.contains("развертка стен") || text.contains("развертки стен") {
            score += 6
        }

        if text.contains("развёртка стен") || text.contains("развёртки стен") {
            score += 6
        }

        if text.contains("развертк") || text.contains("развёртк") {
            score += 3
        }

        for keyword in ["стена 1", "стена 2", "стена 3", "стена 4"] where text.contains(keyword) {
            score += 2
        }

        if text.contains("elevation") || text.contains("wall elevation") {
            score += 3
        }

        return score
    }

    private func extractPlanTitle(from text: String) -> String? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.first(where: { $0.contains("план") || $0.contains("обмер") })?.capitalizedSentence
    }

    private func extractTitle(from text: String) -> String? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let line = lines.first(where: {
            $0.contains("развертк") || $0.contains("развёртк") || $0.contains("elevation")
        }) {
            return line.capitalizedSentence
        }

        return nil
    }

    private func extractRoomName(from text: String, fallbackTitle: String) -> String? {
        let titleSource = [fallbackTitle, text].joined(separator: "\n")

        for separator in [".", ":", "-", "—"] {
            if let range = titleSource.range(of: separator) {
                let candidate = String(titleSource[range.upperBound...])
                    .components(separatedBy: .newlines)
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? ""
                let cleaned = cleanupRoomName(candidate)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        let roomKeywords = [
            "кухня-гостиная", "кухня", "гостиная", "спальня", "детская", "детская 1",
            "детская 2", "санузел", "санузел гостевой", "гардеробная", "коридор",
            "прихожая", "кабинет", "кладовая", "постирочная", "холл", "лоджия",
            "ванная", "мастер-спальня", "мастер санузел"
        ]

        for keyword in roomKeywords where text.contains(keyword) {
            return cleanupRoomName(keyword)
        }

        return nil
    }

    private func cleanupRoomName(_ source: String) -> String {
        let fragmentsToRemove = [
            "развертка стен", "развертки стен", "развёртка стен", "развёртки стен",
            "развертка", "развёртка", "стена 1", "стена 2", "стена 3", "стена 4",
            "лист", "план", "помещение"
        ]

        var cleaned = source.lowercased()
        for fragment in fragmentsToRemove {
            cleaned = cleaned.replacingOccurrences(of: fragment, with: "")
        }

        cleaned = cleaned
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,:;/-—").union(.whitespacesAndNewlines))

        return cleaned.capitalizedSentence
    }

    private func makeReason(from text: String, score: Int, kind: MatchKind) -> String {
        var reasons: [String] = []

        switch kind {
        case .plan:
            if text.contains("обмерный план") || text.contains("общий план") {
                reasons.append("найдена явная подпись общего или обмерного плана")
            } else {
                reasons.append("страница похожа на общий план по текстовым признакам")
            }
        case .elevation:
            if text.contains("развертка стен") || text.contains("развертки стен") || text.contains("развёртка стен") || text.contains("развёртки стен") {
                reasons.append("найдена явная подпись «развёртка стен»")
            } else if text.contains("развертк") || text.contains("развёртк") {
                reasons.append("обнаружено слово «развёртка»")
            }
        case .other:
            break
        }

        let walls = ["стена 1", "стена 2", "стена 3", "стена 4"].filter { text.contains($0) }
        if !walls.isEmpty {
            reasons.append("есть маркировка \(walls.joined(separator: ", "))")
        }

        if reasons.isEmpty {
            reasons.append(kind == .plan ? "страница похожа на общий план" : "страница похожа на развёртку стен по текстовым признакам")
        }

        return reasons.joined(separator: ", ") + ". Оценка уверенности: \(score)."
    }

    private func makeWallSegments(from image: UIImage, observations: [OCRTextObservation], pageNumber: Int, sourceTitle: String) -> [WallElevationExtractorViewModel.WallSegment] {
        let markerSegments = makeWallSegmentsByMarkers(
            from: image,
            observations: observations,
            pageNumber: pageNumber,
            sourceTitle: sourceTitle
        )

        let layoutSegments = makeWallSegmentsByLayout(
            from: image,
            pageNumber: pageNumber,
            sourceTitle: sourceTitle
        )

        if layoutSegments.count > markerSegments.count {
            return layoutSegments
        }

        if !markerSegments.isEmpty {
            return markerSegments
        }

        return layoutSegments
    }

    private func makeWallSegmentsByMarkers(from image: UIImage, observations: [OCRTextObservation], pageNumber: Int, sourceTitle: String) -> [WallElevationExtractorViewModel.WallSegment] {
        let markers = observations
            .compactMap { observation -> (label: String, box: CGRect)? in
                guard let label = wallLabel(from: observation.normalizedText) else { return nil }
                return (label: label, box: observation.boundingBox)
            }
            .uniqueWallMarkers()

        guard !markers.isEmpty else {
            return []
        }

        let rows = makeRows(from: markers)
        let rowBounds = makeRowBounds(rows: rows)

        var segments: [WallElevationExtractorViewModel.WallSegment] = []

        for (rowIndex, row) in rows.enumerated() {
            let sortedRow = row.sorted { $0.box.midX < $1.box.midX }
            let horizontalBounds = makeHorizontalBounds(markers: sortedRow)
            let verticalBounds = rowBounds[rowIndex]

            for (markerIndex, marker) in sortedRow.enumerated() {
                let cropBox = normalizedCropRect(
                    markerBox: marker.box,
                    xBounds: horizontalBounds[markerIndex],
                    yBounds: verticalBounds
                )

                guard let cropped = crop(image: image, normalizedRect: cropBox) else {
                    continue
                }

                segments.append(
                    WallElevationExtractorViewModel.WallSegment(
                        label: marker.label.capitalizedSentence,
                        preview: cropped,
                        pageNumber: pageNumber,
                        sourceTitle: sourceTitle
                    )
                )
            }
        }

        return segments.sorted {
            if $0.label == $1.label {
                return $0.pageNumber < $1.pageNumber
            }
            return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
    }

    private func makeWallSegmentsByLayout(from image: UIImage, pageNumber: Int, sourceTitle: String) -> [WallElevationExtractorViewModel.WallSegment] {
        let boxes = detectWallBoxesByLayout(in: image)
        return boxes.enumerated().compactMap { index, rect in
            guard let cropped = crop(image: image, normalizedRect: rect) else {
                return nil
            }

            return WallElevationExtractorViewModel.WallSegment(
                label: "Стена \(index + 1)",
                preview: cropped,
                pageNumber: pageNumber,
                sourceTitle: sourceTitle
            )
        }
    }

    private func wallLabel(from text: String) -> String? {
        for number in 1 ... 8 {
            if text.contains("стена \(number)") || text.contains("стенa \(number)") || text.contains("wall \(number)") {
                return "Стена \(number)"
            }
        }

        return nil
    }

    private func makeRows(from markers: [(label: String, box: CGRect)]) -> [[(label: String, box: CGRect)]] {
        let sorted = markers.sorted { lhs, rhs in
            if abs(lhs.box.midY - rhs.box.midY) > 0.08 {
                return lhs.box.midY > rhs.box.midY
            }
            return lhs.box.midX < rhs.box.midX
        }

        var rows: [[(label: String, box: CGRect)]] = []
        for marker in sorted {
            if let lastIndex = rows.indices.last,
               let reference = rows[lastIndex].first,
               abs(reference.box.midY - marker.box.midY) < 0.10 {
                rows[lastIndex].append(marker)
            } else {
                rows.append([marker])
            }
        }
        return rows
    }

    private func makeRowBounds(rows: [[(label: String, box: CGRect)]]) -> [ClosedRange<CGFloat>] {
        let centers = rows.map { row in
            row.map { $0.box.midY }.reduce(0, +) / CGFloat(max(row.count, 1))
        }

        return centers.enumerated().map { index, centerY in
            let top: CGFloat
            let bottom: CGFloat

            if index == 0 {
                top = 1.0
            } else {
                top = min(1.0, (centers[index - 1] + centerY) / 2.0)
            }

            if index == centers.count - 1 {
                bottom = 0.0
            } else {
                bottom = max(0.0, (centerY + centers[index + 1]) / 2.0)
            }

            return bottom ... top
        }
    }

    private func makeHorizontalBounds(markers: [(label: String, box: CGRect)]) -> [ClosedRange<CGFloat>] {
        let centers = markers.map { $0.box.midX }

        return centers.enumerated().map { index, centerX in
            let left: CGFloat
            let right: CGFloat

            if index == 0 {
                left = 0.0
            } else {
                left = max(0.0, (centers[index - 1] + centerX) / 2.0)
            }

            if index == centers.count - 1 {
                right = 1.0
            } else {
                right = min(1.0, (centerX + centers[index + 1]) / 2.0)
            }

            return left ... right
        }
    }

    private func normalizedCropRect(markerBox: CGRect, xBounds: ClosedRange<CGFloat>, yBounds: ClosedRange<CGFloat>) -> CGRect {
        let paddingX = max(0.02, markerBox.width * 0.6)
        let paddingY = max(0.03, markerBox.height * 1.6)

        let minX = max(0.0, xBounds.lowerBound - paddingX)
        let maxX = min(1.0, xBounds.upperBound + paddingX)
        let minY = max(0.0, yBounds.lowerBound - paddingY)
        let maxY = min(1.0, yBounds.upperBound + paddingY)

        return CGRect(
            x: minX,
            y: minY,
            width: max(0.08, maxX - minX),
            height: max(0.08, maxY - minY)
        )
    }

    private func crop(image: UIImage, normalizedRect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let convertedRect = CGRect(
            x: normalizedRect.minX * width,
            y: (1.0 - normalizedRect.maxY) * height,
            width: normalizedRect.width * width,
            height: normalizedRect.height * height
        ).integral

        guard convertedRect.width > 1,
              convertedRect.height > 1,
              let cropped = cgImage.cropping(to: convertedRect.intersection(CGRect(x: 0, y: 0, width: width, height: height))) else {
            return nil
        }

        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    private func detectWallBoxesByLayout(in image: UIImage) -> [CGRect] {
        guard let cgImage = image.cgImage,
              let rgba = rgbaPixels(from: cgImage) else {
            return []
        }

        let width = cgImage.width
        let height = cgImage.height
        let gridWidth = 120
        let gridHeight = 160
        let roi = CGRect(x: 0.05, y: 0.08, width: 0.79, height: 0.82)

        var grid = [Bool](repeating: false, count: gridWidth * gridHeight)
        let cellPixelThreshold = 0.045

        for gy in 0 ..< gridHeight {
            for gx in 0 ..< gridWidth {
                let normalizedCell = CGRect(
                    x: roi.minX + (CGFloat(gx) / CGFloat(gridWidth)) * roi.width,
                    y: roi.minY + (CGFloat(gy) / CGFloat(gridHeight)) * roi.height,
                    width: roi.width / CGFloat(gridWidth),
                    height: roi.height / CGFloat(gridHeight)
                )

                let pixelRect = CGRect(
                    x: normalizedCell.minX * CGFloat(width),
                    y: normalizedCell.minY * CGFloat(height),
                    width: normalizedCell.width * CGFloat(width),
                    height: normalizedCell.height * CGFloat(height)
                ).integral

                let density = foregroundDensity(in: pixelRect, pixels: rgba, imageWidth: width, imageHeight: height)
                grid[gy * gridWidth + gx] = density >= cellPixelThreshold
            }
        }

        grid = dilate(grid: grid, width: gridWidth, height: gridHeight, radius: 1)
        grid = dilate(grid: grid, width: gridWidth, height: gridHeight, radius: 1)

        let components = connectedComponents(in: grid, width: gridWidth, height: gridHeight)
        let rects = components.compactMap { component -> CGRect? in
            guard component.count >= 18 else { return nil }

            let minX = component.map(\.x).min() ?? 0
            let maxX = component.map(\.x).max() ?? 0
            let minY = component.map(\.y).min() ?? 0
            let maxY = component.map(\.y).max() ?? 0

            let normalizedRect = CGRect(
                x: roi.minX + (CGFloat(minX) / CGFloat(gridWidth)) * roi.width,
                y: roi.minY + (CGFloat(minY) / CGFloat(gridHeight)) * roi.height,
                width: (CGFloat(maxX - minX + 1) / CGFloat(gridWidth)) * roi.width,
                height: (CGFloat(maxY - minY + 1) / CGFloat(gridHeight)) * roi.height
            )

            let padded = normalizedRect.insetBy(dx: -0.01, dy: -0.015).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard padded.width > 0.04,
                  padded.height > 0.10,
                  padded.maxX < 0.86 else {
                return nil
            }

            let area = padded.width * padded.height
            guard area > 0.025 else {
                return nil
            }

            let aspect = padded.width / max(padded.height, 0.001)

            if padded.minY < 0.22 && padded.maxX > 0.52 && aspect > 0.75 && aspect < 1.35 {
                return nil
            }

            if padded.minX < 0.16 && padded.minY < 0.22 && padded.width > 0.18 && padded.height < 0.20 {
                return nil
            }

            return padded
        }

        let sorted = sortLayoutRects(rects)
        return deduplicateOverlappingRects(sorted)
    }

    private func rgbaPixels(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private func foregroundDensity(in rect: CGRect, pixels: [UInt8], imageWidth: Int, imageHeight: Int) -> CGFloat {
        let minX = max(0, Int(rect.minX))
        let maxX = min(imageWidth - 1, Int(rect.maxX))
        let minY = max(0, Int(rect.minY))
        let maxY = min(imageHeight - 1, Int(rect.maxY))

        guard minX < maxX, minY < maxY else {
            return 0
        }

        var foreground = 0
        var total = 0

        for y in minY ... maxY {
            for x in minX ... maxX {
                let idx = (y * imageWidth + x) * 4
                let r = Int(pixels[idx])
                let g = Int(pixels[idx + 1])
                let b = Int(pixels[idx + 2])
                total += 1

                if min(r, min(g, b)) < 235 {
                    foreground += 1
                }
            }
        }

        guard total > 0 else { return 0 }
        return CGFloat(foreground) / CGFloat(total)
    }

    private func dilate(grid: [Bool], width: Int, height: Int, radius: Int) -> [Bool] {
        var result = grid

        for y in 0 ..< height {
            for x in 0 ..< width {
                let index = y * width + x
                if grid[index] {
                    result[index] = true
                    continue
                }

                var foundNeighbor = false
                for ny in max(0, y - radius) ... min(height - 1, y + radius) {
                    for nx in max(0, x - radius) ... min(width - 1, x + radius) {
                        if grid[ny * width + nx] {
                            foundNeighbor = true
                            break
                        }
                    }
                    if foundNeighbor { break }
                }
                result[index] = foundNeighbor
            }
        }

        return result
    }

    private func connectedComponents(in grid: [Bool], width: Int, height: Int) -> [[(x: Int, y: Int)]] {
        var visited = [Bool](repeating: false, count: grid.count)
        var components: [[(x: Int, y: Int)]] = []

        for y in 0 ..< height {
            for x in 0 ..< width {
                let start = y * width + x
                guard grid[start], !visited[start] else { continue }

                var queue = [(x: Int, y: Int)]()
                var component = [(x: Int, y: Int)]()
                queue.append((x, y))
                visited[start] = true

                var index = 0
                while index < queue.count {
                    let cell = queue[index]
                    index += 1
                    component.append(cell)

                    for ny in max(0, cell.y - 1) ... min(height - 1, cell.y + 1) {
                        for nx in max(0, cell.x - 1) ... min(width - 1, cell.x + 1) {
                            let neighbor = ny * width + nx
                            guard grid[neighbor], !visited[neighbor] else { continue }
                            visited[neighbor] = true
                            queue.append((nx, ny))
                        }
                    }
                }

                components.append(component)
            }
        }

        return components
    }

    private func sortLayoutRects(_ rects: [CGRect]) -> [CGRect] {
        rects.sorted { lhs, rhs in
            if abs(lhs.midY - rhs.midY) > 0.08 {
                return lhs.midY > rhs.midY
            }
            return lhs.minX < rhs.minX
        }
    }

    private func deduplicateOverlappingRects(_ rects: [CGRect]) -> [CGRect] {
        var result: [CGRect] = []

        for rect in rects {
            if let existingIndex = result.firstIndex(where: { intersectionRatio($0, rect) > 0.55 }) {
                let existing = result[existingIndex]
                let existingArea = existing.width * existing.height
                let newArea = rect.width * rect.height
                if newArea > existingArea {
                    result[existingIndex] = rect
                }
            } else {
                result.append(rect)
            }
        }

        return result
    }

    private func intersectionRatio(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        let minArea = min(lhs.width * lhs.height, rhs.width * rhs.height)
        guard minArea > 0 else { return 0 }
        return (intersection.width * intersection.height) / minArea
    }

    private func recognizeTextObservations(in image: UIImage) async throws -> [OCRTextObservation] {
        guard let cgImage = image.cgImage else {
            return []
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ru-RU", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        let observations = request.results ?? []
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }

            return OCRTextObservation(
                text: candidate.string,
                normalizedText: normalize(candidate.string),
                boundingBox: observation.boundingBox
            )
        }
    }

    private func normalize(_ text: String?) -> String {
        guard let text else { return "" }

        return text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
            .replacingOccurrences(of: "ё", with: "е")
            .lowercased()
    }
}

private enum ExtractorError: LocalizedError {
    case invalidPDF
    case emptyPDF

    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "Файл не удалось прочитать как PDF."
        case .emptyPDF:
            return "В PDF нет страниц для анализа."
        }
    }
}

private extension String {
    var capitalizedSentence: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}

private extension Array where Element == (label: String, box: CGRect) {
    func uniqueWallMarkers() -> [(label: String, box: CGRect)] {
        var bestByLabel: [String: (label: String, box: CGRect)] = [:]

        for marker in self {
            if let existing = bestByLabel[marker.label] {
                let existingArea = existing.box.width * existing.box.height
                let newArea = marker.box.width * marker.box.height
                if newArea > existingArea {
                    bestByLabel[marker.label] = marker
                }
            } else {
                bestByLabel[marker.label] = marker
            }
        }

        return bestByLabel.values.sorted { lhs, rhs in
            if abs(lhs.box.midY - rhs.box.midY) > 0.08 {
                return lhs.box.midY > rhs.box.midY
            }
            return lhs.box.midX < rhs.box.midX
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
