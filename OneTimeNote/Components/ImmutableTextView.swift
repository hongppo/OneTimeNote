import SwiftUI
import UIKit

struct ImmutableTextView: UIViewRepresentable {
    @Binding var text: String
    let isEditable: Bool
    let maxCharacters: Int
    var onTextChange: ((String) -> Void)?
    var onCharacterLimitReached: (() -> Void)?
    
    func makeUIView(context: Context) -> UITextView {
        let textView = ImmutableUITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = UIColor.secondarySystemBackground
        
        // 키보드 설정 - 자동완성, 맞춤법 검사 비활성화
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        
        // 기본 설정
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // 텍스트가 다른 경우에만 업데이트 (무한 루프 방지)
        if uiView.text != text {
            uiView.text = text
            context.coordinator.resetWithText(text)
        }
        
        uiView.isEditable = isEditable
        
        // 편집 불가능한 상태 시각화
        if !isEditable {
            uiView.backgroundColor = UIColor.tertiarySystemBackground
            uiView.alpha = 0.8
        } else {
            uiView.backgroundColor = UIColor.secondarySystemBackground
            uiView.alpha = 1.0
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Custom UITextView subclass
    class ImmutableUITextView: UITextView {
        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
            // 복사는 허용, 붙여넣기와 잘라내기는 금지
            if action == #selector(copy(_:)) {
                return super.canPerformAction(action, withSender: sender)
            } else if action == #selector(paste(_:)) || action == #selector(cut(_:)) {
                return false
            }
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: ImmutableTextView
        private var confirmedText: String = ""
        private var currentInputStart: Int = 0
        private var isKoreanComposing: Bool = false
        private var lastKoreanComposingBase: String = ""
        
        // 삭제 처리를 위한 변수들
        private var isProcessingDelete: Bool = false
        private var expectedTextAfterDelete: String = ""
        private var preservedLastCharacter: String = ""
        private var deleteStartPosition: Int = 0
        
        init(_ parent: ImmutableTextView) {
            self.parent = parent
            super.init()
        }
        
        func resetWithText(_ text: String) {
            confirmedText = text
            currentInputStart = text.count
        }
        
        func textViewDidChange(_ textView: UITextView) {
            let currentText = textView.text ?? ""
            
            // 삭제 처리 중인 경우
            if isProcessingDelete {
                // 예상한 텍스트와 다른 경우 (한글 재조합 등)
                if currentText != expectedTextAfterDelete {
                    // 마지막 글자가 변경된 경우 원복
                    if !preservedLastCharacter.isEmpty && currentText.count > deleteStartPosition {
                        let currentLastChar = String(currentText.suffix(currentText.count - deleteStartPosition))
                        if currentLastChar != preservedLastCharacter {
                            // 원래 텍스트로 복원
                            textView.text = expectedTextAfterDelete
                            
                            // 커서 위치 조정
                            if let position = textView.position(from: textView.beginningOfDocument, offset: expectedTextAfterDelete.count) {
                                textView.selectedTextRange = textView.textRange(from: position, to: position)
                            }
                        }
                    }
                }
                isProcessingDelete = false
                expectedTextAfterDelete = ""
                preservedLastCharacter = ""
            }
            
            // 글자 수 제한 체크
            if currentText.count > parent.maxCharacters {
                textView.text = String(currentText.prefix(parent.maxCharacters))
                parent.onCharacterLimitReached?()
                
                // 햅틱 피드백
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                return
            }
            
            parent.text = currentText
            parent.onTextChange?(currentText)
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // 편집 불가능한 경우
            guard parent.isEditable else { return false }
            
            let currentText = textView.text ?? ""
            let nsString = currentText as NSString
            
            // 1. 글자 수 제한 체크
            let newLength = nsString.length - range.length + text.count
            if newLength > parent.maxCharacters && !text.isEmpty {
                parent.onCharacterLimitReached?()
                return false
            }
            
            // 2. 한글 조합 상태 확인
            let hasMarkedText = textView.markedTextRange != nil
            
            // 3. 백스페이스/삭제 처리
            if text.isEmpty && range.length > 0 {
                // 한글 조합 중이면 조합 중인 글자만 삭제 허용
                if hasMarkedText {
                    return true
                }
                
                // Swift String으로 변환하여 Character 단위 처리
                let swiftString = currentText as String
                
                // Character 배열로 변환
                let characters = Array(swiftString)
                
                // NSRange를 String.Index로 변환
                guard let rangeStart = Range(range, in: swiftString)?.lowerBound else { return false }
                let charIndex = swiftString.distance(from: swiftString.startIndex, to: rangeStart)
                
                // 삭제하려는 위치가 현재 입력 시작점보다 앞이면 차단
                if charIndex < currentInputStart {
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                    return false
                }
                
                // 마지막 Character 삭제만 허용
                if charIndex == characters.count - 1 {
                    // 삭제할 문자가 한글인지 확인
                    let lastChar = characters[charIndex]
                    let isKorean = isKoreanCharacter(String(lastChar))
                    
                    // 한글이면 전체 음절을 삭제하도록 range 조정
                    if isKorean {
                        // Character 단위로 삭제하기 위해 정확한 범위 계산
                        let charToDelete = String(lastChar)
                        let utf16Count = charToDelete.utf16.count
                        let adjustedRange = NSRange(location: range.location - (utf16Count - range.length), length: utf16Count)
                        
                        // 조정된 범위로 삭제 처리
                        isProcessingDelete = true
                        expectedTextAfterDelete = nsString.replacingCharacters(in: adjustedRange, with: "")
                        deleteStartPosition = max(0, charIndex - 1)
                        
                        // 삭제 후 남을 마지막 글자 보존
                        if charIndex > 0 {
                            preservedLastCharacter = String(characters[charIndex - 1])
                        }
                        
                        // 수동으로 텍스트 업데이트
                        textView.text = expectedTextAfterDelete
                        
                        // 커서 위치 조정
                        if let position = textView.position(from: textView.beginningOfDocument, offset: expectedTextAfterDelete.utf16.count) {
                            textView.selectedTextRange = textView.textRange(from: position, to: position)
                        }
                        
                        // currentInputStart 업데이트
                        DispatchQueue.main.async {
                            self.currentInputStart = charIndex
                        }
                        
                        return false // 수동으로 처리했으므로 false 반환
                    } else {
                        // 한글이 아닌 경우 기존 처리
                        isProcessingDelete = true
                        expectedTextAfterDelete = nsString.replacingCharacters(in: range, with: "")
                        deleteStartPosition = max(0, charIndex - 1)
                        
                        if charIndex > 0 {
                            preservedLastCharacter = String(characters[charIndex - 1])
                        }
                        
                        DispatchQueue.main.async {
                            self.currentInputStart = charIndex
                        }
                        
                        return true
                    }
                } else {
                    // 그 외의 삭제는 차단
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                    return false
                }
            }
            
            // 4. 새로운 입력 처리
            if !text.isEmpty {
                // 중간 삽입 방지
                if range.location < currentText.count {
                    // 커서를 끝으로 이동
                    if let endPosition = textView.position(from: textView.endOfDocument, offset: 0) {
                        textView.selectedTextRange = textView.textRange(from: endPosition, to: endPosition)
                    }
                    return false
                }
                
                // 한글 조합 시작/진행 중
                if hasMarkedText {
                    isKoreanComposing = true
                    if lastKoreanComposingBase.isEmpty {
                        lastKoreanComposingBase = currentText
                    }
                    return true
                }
                
                // 한글 조합이 끝났거나 일반 문자 입력
                if isKoreanComposing && !hasMarkedText {
                    // 한글 조합 완료 - 이전 텍스트 모두 확정
                    isKoreanComposing = false
                    confirmedText = currentText
                    currentInputStart = Array(currentText).count
                    lastKoreanComposingBase = ""
                }
                
                // 스페이스나 엔터 입력 시 - 현재까지 모든 텍스트 확정
                if text == " " || text == "\n" {
                    DispatchQueue.main.async {
                        let newText = nsString.replacingCharacters(in: range, with: text)
                        self.confirmedText = newText
                        self.currentInputStart = Array(newText).count
                    }
                    return true
                }
                
                // 일반 문자 입력
                if !isKoreanCharacter(text) {
                    // 영어/숫자/기호 입력 - 이전 모든 텍스트 확정
                    DispatchQueue.main.async {
                        self.confirmedText = currentText
                        self.currentInputStart = Array(currentText).count
                    }
                }
            }
            
            return true
        }
        
        // 한글 문자 확인
        private func isKoreanCharacter(_ text: String) -> Bool {
            for scalar in text.unicodeScalars {
                // 한글 음절 범위 (가-힣)
                if (0xAC00...0xD7A3).contains(scalar.value) {
                    return true
                }
                // 한글 자모 범위 (ㄱ-ㅎ, ㅏ-ㅣ)
                if (0x1100...0x11FF).contains(scalar.value) ||
                   (0x3130...0x318F).contains(scalar.value) ||
                   (0xA960...0xA97F).contains(scalar.value) ||
                   (0xD7B0...0xD7FF).contains(scalar.value) {
                    return true
                }
            }
            return false
        }
        
        // 텍스트 선택 변경
        func textViewDidChangeSelection(_ textView: UITextView) {
            // 삭제 처리 중에는 커서 이동 처리 스킵
            if isProcessingDelete {
                return
            }
            
            // 커서가 확정된 텍스트 영역으로 이동하려 하면 차단
            if let selectedRange = textView.selectedTextRange {
                let cursorPosition = textView.offset(from: textView.beginningOfDocument, to: selectedRange.start)
                
                // Character 단위로 위치 계산
                let text = textView.text ?? ""
                let charPosition = Array(text).count - Array(text.utf16).count + cursorPosition
                
                // 확정된 영역에 커서가 있으면 끝으로 이동
                if charPosition < currentInputStart && parent.isEditable {
                    if let endPosition = textView.position(from: textView.endOfDocument, offset: 0) {
                        textView.selectedTextRange = textView.textRange(from: endPosition, to: endPosition)
                    }
                }
            }
        }
        
        // 편집 시작
        func textViewDidBeginEditing(_ textView: UITextView) {
            // 편집 시작 시 현재 텍스트를 모두 확정
            confirmedText = textView.text ?? ""
            currentInputStart = Array(confirmedText).count
        }
        
        // 편집 종료
        func textViewDidEndEditing(_ textView: UITextView) {
            // 편집 종료 시 모든 텍스트 확정
            confirmedText = textView.text ?? ""
            currentInputStart = Array(confirmedText).count
            isKoreanComposing = false
            lastKoreanComposingBase = ""
            isProcessingDelete = false
        }
    }
}
