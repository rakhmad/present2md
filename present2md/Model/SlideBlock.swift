public enum SlideBlock: Equatable {
    case text(String)
    case table([[String]])
    case imagePlaceholder(Int)
}
