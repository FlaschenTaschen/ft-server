// PixelGridView.swift

import SwiftUI
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "PixelGridView")

struct PixelGridView: View {
    @Bindable var displayModel: DisplayModel
    @State private var pixelSize: CGFloat = 16
    @State private var isFullScreen: Bool = false
    @State private var showServerPanel: Bool = true

    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(pixelSize), spacing: 0), count: displayModel.gridWidth)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(.black)
                .ignoresSafeArea()

            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                LazyVGrid(columns: gridColumns, spacing: 0) {
                    ForEach(displayModel.pixelData, id: \.id) { pixelColor in
                        PixelView(pixelColor: pixelColor, size: pixelSize)
                    }
                }
                .padding(8)
            }
            .onGeometryChange(for: CGSize.self) { geo in
                geo.size
            } action: { size in
                let availableWidth = size.width - 16
                let availableHeight = size.height - 16
                pixelSize = min(
                    availableWidth / CGFloat(displayModel.gridWidth),
                    availableHeight / CGFloat(displayModel.gridHeight)
                )
            }
        }
        .overlay {
            if let error = displayModel.serverError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.body)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .controlBackground()
                .cornerRadius(8)
            }
        }
    }
}

struct PixelView: View {
    let pixelColor: PixelColor
    let size: CGFloat

    var body: some View {
        Rectangle()
            .fill(pixelColor.color)
            .frame(width: size, height: size)
            .border(.gray.opacity(0.3), width: 0.5)
    }
}

#Preview {
    let model = DisplayModel()
    PixelGridView(displayModel: model)
}
