import SuggestionModel
import Foundation
import XcodeKit
import XPCShared

extension XCSourceEditorCommandInvocation {
    func mutateCompleteBuffer(modifications: [Modification], restoringSelections restore: Bool) {
        if restore {
            let selectionsRangesToRestore = buffer.selections
                .compactMap { $0 as? XCSourceTextRange }
            buffer.selections.removeAllObjects()
            buffer.lines.apply(modifications)
            for range in selectionsRangesToRestore {
                buffer.selections.add(range)
            }
        } else {
            buffer.lines.apply(modifications)
        }
    }

    func accept(_ updatedContent: UpdatedContent) {
        if let newSelection = updatedContent.newSelection {
            mutateCompleteBuffer(
                modifications: updatedContent.modifications,
                restoringSelections: false
            )
            buffer.selections.removeAllObjects()
            buffer.selections.add(XCSourceTextRange(
                start: .init(line: newSelection.start.line, column: newSelection.start.character),
                end: .init(line: newSelection.end.line, column: newSelection.end.character)
            ))
        } else {
            mutateCompleteBuffer(
                modifications: updatedContent.modifications,
                restoringSelections: true
            )
        }
    }
}

extension EditorContent {
    init(_ invocation: XCSourceEditorCommandInvocation) {
        let buffer = invocation.buffer
        self.init(
            content: buffer.completeBuffer,
            lines: buffer.lines as? [String] ?? [],
            uti: buffer.contentUTI,
            cursorPosition: ((buffer.selections.lastObject as? XCSourceTextRange)?.end).map {
                CursorPosition(line: $0.line, character: $0.column)
            } ?? CursorPosition(line: 0, character: 0),
            selections: buffer.selections.map {
                let sl = ($0 as? XCSourceTextRange)?.start.line ?? 0
                let sc = ($0 as? XCSourceTextRange)?.start.column ?? 0
                let el = ($0 as? XCSourceTextRange)?.end.line ?? 0
                let ec = ($0 as? XCSourceTextRange)?.end.column ?? 0
                
                return Selection(
                    start: CursorPosition( line: sl, character: sc ),
                    end: CursorPosition( line: el, character: ec )
                )
            },
            tabSize: buffer.tabWidth,
            indentSize: buffer.indentationWidth,
            usesTabsForIndentation: buffer.usesTabsForIndentation
        )
    }
}
