public struct Slide: Equatable {
    public var title: String?
    public var blocks: [SlideBlock]

    public init(title: String? = nil, blocks: [SlideBlock] = []) {
        self.title = title
        self.blocks = blocks
    }
}
