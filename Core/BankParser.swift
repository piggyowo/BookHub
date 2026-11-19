import Foundation

enum BankParser {
    enum Failure: LocalizedError {
        case empty, invalid(Int), tooLarge
        var errorDescription: String? {
            switch self {
            case .empty: return "没有识别到题目。每题请使用数字编号，并把答案写在选项下面。"
            case .invalid(let line): return "从第 \(line) 行开始的题目格式不完整：需要至少两个连续选项，以及一个有效的答案字母。"
            case .tooLarge: return "文件超过导入大小限制。"
            }
        }
    }
    private struct Draft {
        let line: Int
        var prompt: String
        var options: [String] = []
        var answer: Int?
        var explanation = ""
        var inExplanation = false
        func finish() throws -> Question {
            guard !prompt.isEmpty, options.count >= 2, let answer, options.indices.contains(answer),
                  options.allSatisfy({ !$0.isEmpty }) else { throw Failure.invalid(line) }
            return Question(prompt: prompt, options: options, answer: answer, explanation: explanation)
        }
    }
    static func parse(_ text: String, name: String) throws -> Bank {
        let patterns = try [#"^[0-9]+\s*[.．、)）]\s*(.*)$"#,
                            #"^([A-Ha-hＡ-Ｈａ-ｈ])\s*[.．、)）:：]\s*(.*)$"#,
                            #"^(?:参考答案|正确答案|答案)\s*[:：]\s*([A-Ha-hＡ-Ｈａ-ｈ])\s*[.。．]?$"#,
                            #"^(?:答案解析|解析)\s*[:：]\s*(.*)$"#].map { try NSRegularExpression(pattern: $0) }
        func match(_ index: Int, _ line: String) -> [String]? {
            let ns = line as NSString
            guard let result = patterns[index].firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
            return (1..<result.numberOfRanges).map { ns.substring(with: result.range(at: $0)) }
        }
        func optionIndex(_ string: String) -> Int? {
            let normalized = string.folding(options: [.widthInsensitive], locale: Locale(identifier: "en_US_POSIX")).uppercased()
            return Array("ABCDEFGH").firstIndex { String($0) == normalized }
        }
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\u{FEFF}", with: "").components(separatedBy: .newlines)
        var questions: [Question] = []
        var draft: Draft?
        for (offset, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if let m = match(0, line) {
                if let draft { questions.append(try draft.finish()) }
                draft = Draft(line: offset + 1, prompt: m[0])
            } else if var q = draft {
                if let m = match(1, line), !q.inExplanation {
                    guard q.answer == nil, optionIndex(m[0]) == q.options.count else { throw Failure.invalid(q.line) }
                    q.options.append(m[1])
                } else if let m = match(2, line), !q.inExplanation {
                    guard q.answer == nil else { throw Failure.invalid(q.line) }
                    q.answer = optionIndex(m[0])
                } else if let m = match(3, line) {
                    guard q.answer != nil else { throw Failure.invalid(q.line) }
                    q.inExplanation = true
                    q.explanation = m[0]
                } else if q.inExplanation {
                    q.explanation += (q.explanation.isEmpty ? "" : "\n") + line
                } else if q.answer == nil {
                    if !q.options.isEmpty { q.options[q.options.count - 1] += "\n" + line }
                    else { q.prompt += (q.prompt.isEmpty ? "" : "\n") + line }
                } else {
                    throw Failure.invalid(q.line)
                }
                draft = q
            }
        }
        if let draft { questions.append(try draft.finish()) }
        guard !questions.isEmpty else { throw Failure.empty }
        return Bank(name: name, questions: questions)
    }
}
