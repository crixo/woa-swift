import SwiftUI

struct SummaryRow: View {
    let date: Date?
    let text: String
    let lineLimit: Int
    
    init( date: Date?, text: String, lineLimit: Int = 2 ) {
        self.date = date
        self.text = text
        self.lineLimit = lineLimit
    }
    

    var body: some View {
        let dateText = date?.formatted(date: .abbreviated, time: .omitted) ?? "Date not available"
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AppDesignSystem.spacingMD) {
                Text(dateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: LayoutMetrics.dateColumnMinWidth, alignment: .leading)

                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(lineLimit)

                Spacer(minLength: AppDesignSystem.spacingSM)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: AppDesignSystem.spacingXS) {
                HStack {
                    Text(dateText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(lineLimit)
            }
        }
        .appSection()
    }
}

#Preview {
    SummaryRow(date: Date.now, text: "Some text")
}
