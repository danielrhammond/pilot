import Foundation

public struct ReplySummaryViewModel {

    public init(_ summary: ReplySummaryRow) {
        self.summary = summary
    }

    var title: String {
        return summary.replyCount == 1 ? "1 Reply" : "\(summary.replyCount) replies"
    }

    private var summary: ReplySummaryRow
}
