import SwiftUI

struct DropZoneView: View {
    var isTargeted: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "arrow.down.doc")
                .font(.system(size: 28))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
            Text("Drop a link to download")
                .font(.headline)
                .foregroundStyle(isTargeted ? Color.accentColor : Color.primary)
            Text("Video, audio, galleries, streams, or direct files")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [6, 4])
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }
}
