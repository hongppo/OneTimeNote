import SwiftUI

enum PageState: String, CaseIterable, Codable {
    case empty
    case writing
    case completed
    case torn
    
    var color: Color {
        switch self {
        case .empty: return Color(UIColor.systemGray4)
        case .writing: return .blue
        case .completed: return .green
        case .torn: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .empty: return "circle"
        case .writing: return "pencil.circle"
        case .completed: return "checkmark.circle.fill"
        case .torn: return "xmark.circle.fill"
        }
    }
    
    var title: String {
        switch self {
        case .empty: return "빈 페이지"
        case .writing: return "작성 중"
        case .completed: return "작성 완료"
        case .torn: return "찢어진 페이지"
        }
    }
}
