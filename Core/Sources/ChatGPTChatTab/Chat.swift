import ChatService
import ComposableArchitecture
import Foundation
import OpenAIService
import Preferences
import Terminal

public struct DisplayedChatMessage: Equatable {
    public enum Role: Equatable {
        case user
        case assistant
        case tool
        case ignored
    }

    public struct Reference: Equatable {
        public typealias Kind = ChatMessage.Reference.Kind

        public var title: String
        public var subtitle: String
        public var uri: String
        public var startLine: Int?
        public var kind: Kind

        public init(
            title: String,
            subtitle: String,
            uri: String,
            startLine: Int?,
            kind: Kind
        ) {
            self.title = title
            self.subtitle = subtitle
            self.uri = uri
            self.startLine = startLine
            self.kind = kind
        }
    }

    public var id: String
    public var role: Role
    public var text: String
    public var references: [Reference] = []

    public init(id: String, role: Role, text: String, references: [Reference]) {
        self.id = id
        self.role = role
        self.text = text
        self.references = references
    }
}

private var isPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

struct Chat: ReducerProtocol {
    public typealias MessageID = String

    struct State: Equatable {
        var title: String = "Chat"
        @BindingState var typedMessage = ""
        var history: [DisplayedChatMessage] = []
        @BindingState var isReceivingMessage = false
        var chatMenu = ChatMenu.State()
        @BindingState var focusedField: Field?

        enum Field: String, Hashable {
            case textField
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)

        case appear
        case refresh
        case sendButtonTapped
        case returnButtonTapped
        case stopRespondingButtonTapped
        case clearButtonTap
        case deleteMessageButtonTapped(MessageID)
        case resendMessageButtonTapped(MessageID)
        case setAsExtraPromptButtonTapped(MessageID)
        case focusOnTextField
        case referenceClicked(DisplayedChatMessage.Reference)

        case observeChatService
        case observeHistoryChange
        case observeIsReceivingMessageChange
        case observeSystemPromptChange
        case observeExtraSystemPromptChange
        case observeDefaultScopesChange

        case historyChanged
        case isReceivingMessageChanged
        case systemPromptChanged
        case extraSystemPromptChanged
        case defaultScopesChanged

        case chatMenu(ChatMenu.Action)
    }

    let service: ChatService
    let id = UUID()

    enum CancelID: Hashable {
        case observeHistoryChange(UUID)
        case observeIsReceivingMessageChange(UUID)
        case observeSystemPromptChange(UUID)
        case observeExtraSystemPromptChange(UUID)
        case observeDefaultScopesChange(UUID)
        case sendMessage(UUID)
    }

    @Dependency(\.openURL) var openURL

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Scope(state: \.chatMenu, action: /Action.chatMenu) {
            ChatMenu(service: service)
        }

        Reduce { state, action in
            switch action {
            case .appear:
                return .run { send in
                    if isPreview { return }
                    await send(.observeChatService)
                    await send(.historyChanged)
                    await send(.isReceivingMessageChanged)
                    await send(.systemPromptChanged)
                    await send(.extraSystemPromptChanged)
                    await send(.focusOnTextField)
                    await send(.refresh)
                }

            case .refresh:
                return .run { send in
                    await send(.chatMenu(.refresh))
                }

            case .sendButtonTapped:
                guard !state.typedMessage.isEmpty else { return .none }
                let message = state.typedMessage
                state.typedMessage = ""
                return .run { _ in
                    try await service.send(content: message)
                }.cancellable(id: CancelID.sendMessage(id))

            case .returnButtonTapped:
                state.typedMessage += "\n"
                return .none

            case .stopRespondingButtonTapped:
                return .merge(
                    .run { _ in
                        await service.stopReceivingMessage()
                    },
                    .cancel(id: CancelID.sendMessage(id))
                )

            case .clearButtonTap:
                return .run { _ in
                    await service.clearHistory()
                }

            case let .deleteMessageButtonTapped(id):
                return .run { _ in
                    await service.deleteMessage(id: id)
                }

            case let .resendMessageButtonTapped(id):
                return .run { _ in
                    try await service.resendMessage(id: id)
                }

            case let .setAsExtraPromptButtonTapped(id):
                return .run { _ in
                    await service.setMessageAsExtraPrompt(id: id)
                }

            case let .referenceClicked(reference):
                let fileURL = URL(fileURLWithPath: reference.uri)
                return .run { _ in
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let terminal = Terminal()
                        do {
                            _ = try await terminal.runCommand(
                                "/bin/bash",
                                arguments: [
                                    "-c",
                                    "xed -l \(reference.startLine ?? 0) \"\(reference.uri)\"",
                                ],
                                environment: [:]
                            )
                        } catch {
                            print(error)
                        }
                    } else if let url = URL(string: reference.uri), url.scheme != nil {
                        await openURL(url)
                    }
                }

            case .focusOnTextField:
                state.focusedField = .textField
                return .none

            case .observeChatService:
                return .run { send in
                    await send(.observeHistoryChange)
                    await send(.observeIsReceivingMessageChange)
                    await send(.observeSystemPromptChange)
                    await send(.observeExtraSystemPromptChange)
                    await send(.observeDefaultScopesChange)
                }

            case .observeHistoryChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$chatHistory.sink { _ in
                            continuation.yield()
                        }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        await send(.historyChanged)
                    }
                }.cancellable(id: CancelID.observeHistoryChange(id), cancelInFlight: true)

            case .observeIsReceivingMessageChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$isReceivingMessage
                            .sink { _ in
                                continuation.yield()
                            }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        await send(.isReceivingMessageChanged)
                    }
                }.cancellable(
                    id: CancelID.observeIsReceivingMessageChange(id),
                    cancelInFlight: true
                )

            case .observeSystemPromptChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$systemPrompt.sink { _ in
                            continuation.yield()
                        }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        await send(.systemPromptChanged)
                    }
                }.cancellable(id: CancelID.observeSystemPromptChange(id), cancelInFlight: true)

            case .observeExtraSystemPromptChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$extraSystemPrompt
                            .sink { _ in
                                continuation.yield()
                            }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        await send(.extraSystemPromptChanged)
                    }
                }.cancellable(id: CancelID.observeExtraSystemPromptChange(id), cancelInFlight: true)

            case .observeDefaultScopesChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$defaultScopes
                            .sink { _ in
                                continuation.yield()
                            }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        await send(.defaultScopesChanged)
                    }
                }.cancellable(id: CancelID.observeDefaultScopesChange(id), cancelInFlight: true)

            case .historyChanged:
                state.history = service.chatHistory.flatMap { message in
                    var all = [DisplayedChatMessage]()
                    all.append(.init(
                        id: message.id,
                        role: {
                            switch message.role {
                            case .system: return .ignored
                            case .user: return .user
                            case .assistant:
                                if let text = message.summary ?? message.content,
                                   !text.isEmpty
                                {
                                    return .assistant
                                }
                                return .ignored
                            }
                        }(),
                        text: message.summary ?? message.content ?? "",
                        references: message.references.map {
                            .init(
                                title: $0.title,
                                subtitle: $0.subTitle,
                                uri: $0.uri,
                                startLine: $0.startLine,
                                kind: $0.kind
                            )
                        }
                    ))

                    for call in message.toolCalls ?? [] {
                        all.append(.init(
                            id: message.id + call.id,
                            role: .tool,
                            text: call.response.summary ?? call.response.content,
                            references: []
                        ))
                    }

                    return all
                }

                state.title = {
                    let defaultTitle = "Chat"
                    guard let lastMessageText = state.history
                        .filter({ $0.role == .assistant || $0.role == .user })
                        .last?
                        .text else { return defaultTitle }
                    if lastMessageText.isEmpty { return defaultTitle }
                    let trimmed = lastMessageText
                        .trimmingCharacters(in: .punctuationCharacters)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.starts(with: "```") {
                        return "Code Block"
                    } else {
                        return trimmed
                    }
                }()
                return .none

            case .isReceivingMessageChanged:
                state.isReceivingMessage = service.isReceivingMessage
                return .none

            case .systemPromptChanged:
                state.chatMenu.systemPrompt = service.systemPrompt
                return .none

            case .extraSystemPromptChanged:
                state.chatMenu.extraSystemPrompt = service.extraSystemPrompt
                return .none

            case .defaultScopesChanged:
                state.chatMenu.defaultScopes = service.defaultScopes
                return .none

            case .binding:
                return .none

            case .chatMenu:
                return .none
            }
        }
    }
}

struct ChatMenu: ReducerProtocol {
    struct State: Equatable {
        var systemPrompt: String = ""
        var extraSystemPrompt: String = ""
        var temperatureOverride: Double? = nil
        var chatModelIdOverride: String? = nil
        var defaultScopes: Set<ChatService.Scope> = []
    }

    enum Action: Equatable {
        case appear
        case refresh
        case resetPromptButtonTapped
        case temperatureOverrideSelected(Double?)
        case chatModelIdOverrideSelected(String?)
        case customCommandButtonTapped(CustomCommand)
        case resetDefaultScopesButtonTapped
        case toggleScope(ChatService.Scope)
    }

    let service: ChatService

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .appear:
                return .run {
                    await $0(.refresh)
                }

            case .refresh:
                state.temperatureOverride = service.configuration.overriding.temperature
                state.chatModelIdOverride = service.configuration.overriding.modelId
                return .none

            case .resetPromptButtonTapped:
                return .run { _ in
                    await service.resetPrompt()
                }
            case let .temperatureOverrideSelected(temperature):
                state.temperatureOverride = temperature
                return .run { _ in
                    service.configuration.overriding.temperature = temperature
                }
            case let .chatModelIdOverrideSelected(chatModelId):
                state.chatModelIdOverride = chatModelId
                return .run { _ in
                    service.configuration.overriding.modelId = chatModelId
                }
            case let .customCommandButtonTapped(command):
                return .run { _ in
                    try await service.handleCustomCommand(command)
                }

            case .resetDefaultScopesButtonTapped:
                return .run { _ in
                    service.resetDefaultScopes()
                }
            case let .toggleScope(scope):
                return .run { _ in
                    service.defaultScopes.formSymmetricDifference([scope])
                }
            }
        }
    }
}

