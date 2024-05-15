import AppKit
import Client
import Foundation
import GitHubCopilotService
import SuggestionModel
import Workspace
import XCTest
import XPCShared

@testable import Service

func completion(text: String, range: CursorRange, uuid: String = "") -> CodeSuggestion {
    .init(id: uuid, text: text, position: range.start, range: range)
}

class MockSuggestionService: GitHubCopilotSuggestionServiceType {
    func terminate() async {
        fatalError()
    }

    func cancelRequest() async {
        fatalError()
    }

    func notifyOpenTextDocument(fileURL: URL, content: String) async throws {
        fatalError()
    }

    func notifyChangeTextDocument(fileURL: URL, content: String) async throws {
        fatalError()
    }

    func notifyCloseTextDocument(fileURL: URL) async throws {
        fatalError()
    }

    func notifySaveTextDocument(fileURL: URL) async throws {
        fatalError()
    }

    var completions = [CodeSuggestion]()
    var accepted: String?
    var rejected: [String] = []

    init(completions: [CodeSuggestion]) {
        self.completions = completions
    }

    func getCompletions(
        fileURL: URL,
        content: String,
        cursorPosition: SuggestionModel.CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool
    ) async throws -> [SuggestionModel.CodeSuggestion] {
        completions
    }

    func notifyAccepted(_ completion: CodeSuggestion) async {
        accepted = completion.id
    }

    func notifyRejected(_ completions: [CodeSuggestion]) async {
        rejected = completions.map(\.id)
    }
}

