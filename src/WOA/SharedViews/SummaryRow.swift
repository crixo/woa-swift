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
        return HStack(alignment: .center, spacing: AppDesignSystem.spacingMD) {
            Text(dateText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minWidth: LayoutMetrics.dateColumnMinWidth, alignment: .leading)
            
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(lineLimit)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        
        .padding(.vertical, AppDesignSystem.spacingSM)
        .padding(.horizontal, AppDesignSystem.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesignSystem.controlRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    SummaryRow(date: Date.now, text: "Some text")
}
