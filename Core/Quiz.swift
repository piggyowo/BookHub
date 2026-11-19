import Foundation

struct Question: Codable, Equatable, Identifiable {
    var id = UUID()
    let prompt: String
    let options: [String]
    let answer: Int
    let explanation: String
}

struct Bank: Codable, Equatable, Identifiable {
    var id = UUID()
    let name: String
    let questions: [Question]
}

enum QuizMode: String, CaseIterable { case practice, exam
    var title: String { self == .practice ? "练习模式" : "考试模式" }
}
enum DrawOrder: String, CaseIterable { case original, random
    var title: String { self == .original ? "题库顺序" : "随机抽题" }
}

struct QuizSession {
    struct Entry: Identifiable {
        let id: Int
        let bank: String
        let question: Question
    }
    struct Review: Identifiable {
        let entry: Entry
        let chosen: Int
        var id: Int { entry.id }
        var correct: Bool { chosen == entry.question.answer }
    }
    struct Result {
        let reviews: [Review]
        var hits: Int { reviews.filter(\.correct).count }
        var score: Int { Int((100 * Double(hits) / Double(reviews.count)).rounded()) }
    }
    enum Problem: LocalizedError { case invalidCount
        var errorDescription: String? { "请输入题库范围内的题量。" }
    }
    let mode: QuizMode
    private let entries: [Entry]
    private var choices: [Int?]
    private(set) var index = 0
    private(set) var result: Result?
    private var revealed = false
    var count: Int { entries.count }
    var current: Entry { entries[index] }
    var selection: Int? { choices[index] }
    var isLast: Bool { index == count - 1 }
    var feedback: Review? {
        guard revealed, let selection else { return nil }
        return Review(entry: current, chosen: selection)
    }

    init(banks: [Bank], order: DrawOrder, mode: QuizMode, count: Int) throws {
        let pool = banks.flatMap { bank in bank.questions.map { (bank.name, $0) } }
        guard count > 0, count <= pool.count else { throw Problem.invalidCount }
        let drawn = order == .random ? pool.shuffled() : pool
        self.mode = mode
        self.entries = drawn.prefix(count).enumerated().map { Entry(id: $0.offset, bank: $0.element.0, question: $0.element.1) }
        self.choices = Array(repeating: nil, count: count)
    }

    mutating func choose(_ option: Int) {
        guard result == nil, !revealed, current.question.options.indices.contains(option) else { return }
        choices[index] = option
    }
    mutating func previous() {
        guard result == nil, mode == .exam, index > 0 else { return }
        index -= 1
    }
    mutating func advance() {
        guard result == nil, selection != nil else { return }
        if mode == .practice && !revealed { revealed = true; return }
        if !isLast { index += 1; revealed = false; return }
        let reviews = zip(entries, choices).compactMap { entry, chosen in chosen.map { Review(entry: entry, chosen: $0) } }
        if reviews.count == count { result = Result(reviews: reviews) }
    }
}

struct BankLibrary {
    let directory: URL
    private var file: URL { directory.appendingPathComponent("banks.json") }
    func load() throws -> [Bank] {
        do { return try JSONDecoder().decode([Bank].self, from: Data(contentsOf: file)) }
        catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError { return [] }
    }
    func save(_ banks: [Bank]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(banks).write(to: file, options: .atomic)
    }
}
