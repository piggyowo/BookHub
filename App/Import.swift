import Foundation
import PDFKit
import UniformTypeIdentifiers
import ZIPFoundation

private enum ImportFailure: LocalizedError {
    case unsupported, noPDFText, lockedPDF, badWord, textEncoding, tooLarge
    var errorDescription: String? {
        switch self {
        case .unsupported: return "请选择 TXT、PDF 或 Word（DOCX）文件。旧版 DOC 请先另存为 DOCX。"
        case .noPDFText: return "PDF 没有可提取的文字。扫描件请先做 OCR。"
        case .lockedPDF: return "PDF 已加密，请先解锁后再导入。"
        case .badWord: return "找不到可读取的 Word 正文。"
        case .textEncoding: return "此 TXT 编码暂不支持，请另存为 UTF-8。"
        case .tooLarge: return "导入文件不可超过 15 MB。"
        }
    }
}

enum DocumentImport {
    static let types: [UTType] = [.plainText, .pdf] + (UTType(filenameExtension: "docx").map { [$0] } ?? [])
    private static let limit = 15 * 1024 * 1024

    static func read(_ url: URL) throws -> Bank {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: limit + 1) ?? Data()
        guard data.count <= limit else { throw ImportFailure.tooLarge }
        let text: String
        switch url.pathExtension.lowercased() {
        case "txt", "text":
            if let decoded = String(data: data, encoding: .utf8) { text = decoded }
            else if (data.starts(with: [0xff, 0xfe]) || data.starts(with: [0xfe, 0xff])), let decoded = String(data: data, encoding: .utf16) { text = decoded }
            else { throw ImportFailure.textEncoding }
        case "pdf":
            guard let pdf = PDFDocument(data: data) else { throw ImportFailure.noPDFText }
            guard !pdf.isLocked else { throw ImportFailure.lockedPDF }
            var extracted = ""
            guard pdf.pageCount <= 2_000 else { throw ImportFailure.tooLarge }
            for index in 0..<pdf.pageCount {
                if let page = pdf.page(at: index)?.string { extracted += page + "\n" }
                guard extracted.utf8.count <= limit else { throw ImportFailure.tooLarge }
            }
            guard !extracted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ImportFailure.noPDFText }
            text = extracted
        case "docx":
            let archive = try Archive(data: data, accessMode: .read)
            guard let entry = archive["word/document.xml"] else { throw ImportFailure.badWord }
            guard entry.uncompressedSize <= UInt64(limit) else { throw ImportFailure.tooLarge }
            var xml = Data()
            _ = try archive.extract(entry) { chunk in
                guard xml.count + chunk.count <= limit else { throw ImportFailure.tooLarge }
                xml.append(chunk)
            }
            let parser = XMLParser(data: xml)
            let collector = WordText()
            parser.shouldProcessNamespaces = true
            parser.externalEntityResolvingPolicy = .never
            parser.delegate = collector
            guard parser.parse() else { throw parser.parserError ?? ImportFailure.badWord }
            text = collector.text
        default: throw ImportFailure.unsupported
        }
        return try BankParser.parse(text, name: url.deletingPathExtension().lastPathComponent)
    }
}

private final class WordText: NSObject, XMLParserDelegate {
    private let word = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    private var insideText = false
    var text = ""
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        guard namespaceURI == word else { return }
        if elementName == "t" { insideText = true }
        if elementName == "br" || elementName == "cr" { text += "\n" }
        if elementName == "tab" { text += " " }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if insideText { text += string } }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard namespaceURI == word else { return }
        if elementName == "t" { insideText = false }
        if elementName == "p" { text += "\n" }
    }
}
