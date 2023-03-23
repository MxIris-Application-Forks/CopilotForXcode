import SwiftUI

@MainActor
final class SuggestionPanelViewModel: ObservableObject {
    struct Suggestion: Equatable {
        var startLineIndex: Int
        var code: [NSAttributedString]
        var suggestionCount: Int
        var currentSuggestionIndex: Int

        static let empty = Suggestion(
            startLineIndex: 0,
            code: [],
            suggestionCount: 0,
            currentSuggestionIndex: 0
        )
    }

    struct Chat: Equatable {
        struct ChatMessage: Equatable {
            var id: String
            var isUser: Bool
            var text: String
        }

        var history: [ChatMessage]
        var isReceivingMessage: Bool
    }

    enum Content: Equatable {
        case empty
        case suggestion(Suggestion)
        case chat(Chat)
        case error(String)
    }

    @Published var content: Content
    @Published var isPanelDisplayed: Bool
    @Published var alignTopToAnchor = false
    @Published var colorScheme: ColorScheme

    var onAcceptButtonTapped: (() -> Void)?
    var onRejectButtonTapped: (() -> Void)?
    var onPreviousButtonTapped: (() -> Void)?
    var onNextButtonTapped: (() -> Void)?

    public init(
        content: Content = .empty,
        isPanelDisplayed: Bool = false,
        colorScheme: ColorScheme = .dark,
        onAcceptButtonTapped: (() -> Void)? = nil,
        onRejectButtonTapped: (() -> Void)? = nil,
        onPreviousButtonTapped: (() -> Void)? = nil,
        onNextButtonTapped: (() -> Void)? = nil
    ) {
        self.content = content
        self.isPanelDisplayed = isPanelDisplayed
        self.colorScheme = colorScheme
        self.onAcceptButtonTapped = onAcceptButtonTapped
        self.onRejectButtonTapped = onRejectButtonTapped
        self.onPreviousButtonTapped = onPreviousButtonTapped
        self.onNextButtonTapped = onNextButtonTapped
    }
}

struct SuggestionPanelView: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel

    var body: some View {
        VStack {
            if !viewModel.alignTopToAnchor {
                Spacer()
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            ZStack(alignment: .topLeading) {
                switch viewModel.content {
                case .empty:
                    EmptyView()
                case let .suggestion(suggestion):
                    CodeBlockSuggestionPanel(viewModel: viewModel, suggestion: suggestion)
                case let .error(description):
                    ErrorPanel(viewModel: viewModel, description: description)
                case let .chat(chat):
                    ChatPanel(viewModel: viewModel, chat: chat)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: Style.panelHeight)
            .fixedSize(horizontal: false, vertical: true)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.3), style: .init(lineWidth: 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.white.opacity(0.2), style: .init(lineWidth: 1))
                    .padding(1)
            )
            .allowsHitTesting(viewModel.isPanelDisplayed && viewModel.content != .empty)
            .preferredColorScheme(viewModel.colorScheme)

            if viewModel.alignTopToAnchor {
                Spacer()
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
        .opacity({
            guard viewModel.isPanelDisplayed else { return 0 }
            guard viewModel.content != .empty else { return 0 }
            return 1
        }())
        .animation(.easeInOut(duration: 0.2), value: viewModel.content)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isPanelDisplayed)
    }
}

struct CommandButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.8 : 1))
                    .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.2), style: .init(lineWidth: 1))
            }
    }
}

// MARK: - Previews

struct SuggestionPanelView_Dark_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            content: .suggestion(.init(
                startLineIndex: 8,
                code: highlighted(
                    code: """
                    LazyVGrid(columns: [GridItem(.fixed(30)), GridItem(.flexible())]) {
                    ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in // lkjaskldjalksjdlkasjdlkajslkdjas
                        Text(viewModel.suggestion[index])
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    """,
                    language: "swift",
                    brightMode: false
                ),
                suggestionCount: 2,
                currentSuggestionIndex: 0
            )),
            isPanelDisplayed: true,
            colorScheme: .dark
        ))
        .frame(width: 450, height: 400)
        .background {
            HStack {
                Color.red
                Color.green
                Color.blue
            }
        }
    }
}

struct SuggestionPanelView_Bright_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            content: .suggestion(.init(
                startLineIndex: 8,
                code: highlighted(
                    code: """
                    LazyVGrid(columns: [GridItem(.fixed(30)), GridItem(.flexible())]) {
                    ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in // lkjaskldjalksjdlkasjdlkajslkdjas
                        Text(viewModel.suggestion[index])
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    """,
                    language: "swift",
                    brightMode: true
                ),
                suggestionCount: 2,
                currentSuggestionIndex: 0
            )),
            isPanelDisplayed: true,
            colorScheme: .light
        ))
        .frame(width: 450, height: 400)
        .background {
            HStack {
                Color.red
                Color.green
                Color.blue
            }
        }
    }
}

struct SuggestionPanelView_Dark_Objc_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            content: .suggestion(.init(
                startLineIndex: 8,
                code: highlighted(
                    code: """
                    - (void)addSubview:(UIView *)view {
                        [self addSubview:view];
                    }
                    """,
                    language: "objective-c",
                    brightMode: false
                ),
                suggestionCount: 2,
                currentSuggestionIndex: 0
            )),
            isPanelDisplayed: true,
            colorScheme: .dark
        ))
        .frame(width: 450, height: 400)
        .background {
            HStack {
                Color.red
                Color.green
                Color.blue
            }
        }
    }
}

struct SuggestionPanelView_Bright_Objc_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            content: .suggestion(.init(
                startLineIndex: 8,
                code: highlighted(
                    code: """
                    - (void)addSubview:(UIView *)view {
                        [self addSubview:view];
                    }
                    """,
                    language: "objective-c",
                    brightMode: true
                ),
                suggestionCount: 2,
                currentSuggestionIndex: 0
            )),
            isPanelDisplayed: true,
            colorScheme: .light
        ))
        .frame(width: 450, height: 400)
        .background {
            HStack {
                Color.red
                Color.green
                Color.blue
            }
        }
    }
}

struct SuggestionPanelView_Error_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            content: .error("This is an error\nerror"),
            isPanelDisplayed: true
        ))
        .frame(width: 450, height: 200)
    }
}
