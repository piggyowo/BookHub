import XCTest
@testable import StudyCore

final class StudyCoreTests: XCTestCase {
    func testPracticeRevealsOnSubmitAndLocksAnswer() throws {
        let bank = try BankParser.parse(Self.text, name: "示例")
        var session = try QuizSession(banks: [bank], order: .original, mode: .practice, count: 2)
        XCTAssertEqual(session.current.question.prompt, "哪种材料常用于折纸？")
        session.choose(0)
        XCTAssertNil(session.feedback)
        session.advance()
        XCTAssertEqual(session.feedback?.correct, true)
        session.choose(1)
        XCTAssertEqual(session.selection, 0)
        session.advance()
        XCTAssertEqual(session.index, 1)
        session.choose(1)
        session.advance()
        XCTAssertEqual(session.feedback?.correct, false)
        session.advance()
        XCTAssertEqual(session.result?.score, 50)
    }

    func testExamHidesFeedbackUntilSubmissionAndSupportsRevision() throws {
        let bank = try BankParser.parse(Self.text, name: "示例")
        var session = try QuizSession(banks: [bank], order: .original, mode: .exam, count: 2)
        session.choose(1)
        session.advance()
        XCTAssertNil(session.feedback)
        XCTAssertNil(session.result)
        session.previous()
        XCTAssertEqual(session.selection, 1)
        session.choose(0)
        session.advance()
        session.choose(0)
        session.advance()
        XCTAssertEqual(session.result?.score, 100)
    }

    func testMultipleBanksNoDuplicatePositionsAndRejectOversizedRequest() throws {
        let a = try BankParser.parse(Self.text, name: "甲")
        let b = try BankParser.parse(Self.text, name: "乙")
        var session = try QuizSession(banks: [a, b], order: .random, mode: .exam, count: 4)
        var identities = Set<UUID>()
        for _ in 0..<4 {
            identities.insert(session.current.question.id)
            session.choose(0)
            session.advance()
        }
        XCTAssertEqual(identities.count, 4)
        XCTAssertThrowsError(try QuizSession(banks: [a], order: .original, mode: .exam, count: 3))
    }

    func testMissingAnswerDoesNotSilentlyImport() throws {
        XCTAssertThrowsError(try BankParser.parse("1. 题干\nA. 甲\nB. 乙", name: "缺答案"))
    }

    func testParserHandlesPDFLikeWrappedLinesAndWindowsNewlines() throws {
        let text = "1．题目第一行\r\n第二行\r\nＡ．选项甲\r\nＢ．选项乙\r\n答案：Ｂ\r\n解析：说明\r\n补充"
        let bank = try BankParser.parse(text, name: "样本")
        XCTAssertEqual(bank.questions.first?.prompt, "题目第一行\n第二行")
        XCTAssertEqual(bank.questions.first?.answer, 1)
        XCTAssertEqual(bank.questions.first?.explanation, "说明\n补充")
    }

    func testLibraryRoundTripsLocally() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = BankLibrary(directory: folder)
        let bank = try BankParser.parse(Self.text, name: "留存")
        try store.save([bank])
        XCTAssertEqual(try store.load(), [bank])
    }

    private static let text = """
    1. 哪种材料常用于折纸？
    A. 纸
    B. 钢板
    答案：A
    解析：纸能保留折痕。

    2. 编织中通常用什么？
    A. 线
    B. 石头
    答案：A
    """
}
