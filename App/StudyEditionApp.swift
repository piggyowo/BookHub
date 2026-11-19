import SwiftUI

@main
struct StudyEditionApp: App {
    var body: some Scene { WindowGroup { Workspace() } }
}

private let paper = Color(red: 0.96, green: 0.93, blue: 0.89)
private let ink = Color(red: 0.10, green: 0.17, blue: 0.20)
private let blue = Color(red: 0.10, green: 0.25, blue: 0.32)
private let cream = Color(red: 1, green: 0.99, blue: 0.97)

private struct Workspace: View {
    private let library = BankLibrary(directory: URL.applicationSupportDirectory.appendingPathComponent("StudyEdition"))
    @State private var banks: [Bank] = []
    @State private var selected: Set<UUID> = []
    @State private var mode = QuizMode.practice
    @State private var order = DrawOrder.original
    @State private var amount = "3"
    @State private var session: QuizSession?
    @State private var showingFiles = false
    @State private var importing = false
    @State private var preview: Bank?
    @State private var error: String?
    @State private var storageAvailable = false
    @State private var confirmExit = false
    @FocusState private var editingAmount: Bool

    private var chosenBanks: [Bank] { banks.filter { selected.contains($0.id) } }
    private var available: Int { chosenBanks.reduce(0) { $0 + $1.questions.count } }
    private var validAmount: Int? {
        guard let n = Int(amount), n > 0, n <= available else { return nil }
        return n
    }

    var body: some View {
        NavigationStack {
            ZStack {
                paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let session {
                            if let result = session.result { results(result) }
                            else { quiz(session).id(session.index) }
                        } else { home }
                    }.frame(maxWidth: 620).padding(16).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(session?.mode.title ?? "研题册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if session != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("返回") {
                            if session?.result != nil { session = nil }
                            else { confirmExit = true }
                        }
                    }
                }
                if editingAmount {
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成") { editingAmount = false } }
                }
            }
        }
        .foregroundStyle(ink).tint(blue).preferredColorScheme(.light)
        .task {
            do {
                let saved = try library.load()
                banks = Self.samples + saved
                storageAvailable = true
            } catch {
                banks = Self.samples
                self.error = "无法读取本地题库。为避免覆盖原数据，暂时停用导入。\n" + error.localizedDescription
            }
            selected = Set(banks.map(\.id))
        }
        .fileImporter(isPresented: $showingFiles, allowedContentTypes: DocumentImport.types) { result in
            switch result {
            case .success(let url):
                importing = true
                Task { @MainActor in
                    let parsed = await Task.detached(priority: .userInitiated) { Result { try DocumentImport.read(url) } }.value
                    importing = false
                    switch parsed {
                    case .success(let bank): preview = bank
                    case .failure(let failure): error = failure.localizedDescription
                    }
                }
            case .failure(let failure): error = failure.localizedDescription
            }
        }
        .sheet(item: $preview) { bank in importReview(bank) }
        .alert("提示", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("知道了", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
        .confirmationDialog("退出本轮？本轮答案不会保存。", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("退出答题", role: .destructive) { session = nil }
            Button("继续答题", role: .cancel) {}
        }
    }

    private var home: some View {
        Group {
            VStack(alignment: .leading, spacing: 7) {
                Text("VOL. 01  /  STUDY WORKSPACE").font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(Color(red: 0.94, green: 0.81, blue: 0.63))
                Text("刷题工作台").font(.system(.largeTitle, design: .serif).weight(.bold)).accessibilityAddTraits(.isHeader)
                Text("选题库、定题量，开始这一轮。").font(.subheadline)
            }.foregroundStyle(cream).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(blue, in: RoundedRectangle(cornerRadius: 16))
            card {
                HStack {
                    heading("01  选择题库")
                    Spacer()
                    Button { showingFiles = true } label: { Label("导入题库", systemImage: "plus").padding(.vertical, 8) }
                        .disabled(importing || !storageAvailable)
                }
                if importing { ProgressView("正在读取题库…") }
                ForEach(banks) { bank in
                    Divider()
                    Button {
                        if selected.contains(bank.id) { selected.remove(bank.id) } else { selected.insert(bank.id) }
                    } label: {
                        HStack {
                            Text(bank.name).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(bank.questions.count) 题").font(.caption)
                            Image(systemName: selected.contains(bank.id) ? "checkmark.square.fill" : "square")
                                .accessibilityHidden(true)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityAddTraits(selected.contains(bank.id) ? [.isSelected] : [])
                }
                Button(selected.count == banks.count ? "取消全选" : "选择全部题库") {
                    selected = selected.count == banks.count ? [] : Set(banks.map(\.id))
                }.padding(.vertical, 8)
            }
            card {
                heading("02  组卷设置")
                Text("答题模式").font(.caption.bold())
                Picker("答题模式", selection: $mode) { ForEach(QuizMode.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                Text(mode == .practice ? "每提交一题，立即显示对错。" : "交卷后统一显示成绩和答案。").font(.caption)
                Text("出题顺序").font(.caption.bold())
                Picker("出题顺序", selection: $order) { ForEach(DrawOrder.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                Text("本次题量").font(.caption.bold())
                HStack {
                    TextField("自定义题量", text: $amount).keyboardType(.numberPad).textFieldStyle(.roundedBorder).focused($editingAmount)
                    Button("全部 \(available) 题") { amount = String(available) }.disabled(available == 0)
                }
                Text(available == 0 ? "请至少选择一个题库" : "已选 \(selected.count) 个题库 · 可出 1–\(available) 题").font(.caption)
            }
            primary("开始答题") {
                guard let validAmount else { return }
                editingAmount = false
                do { session = try QuizSession(banks: chosenBanks, order: order, mode: mode, count: validAmount) }
                catch { self.error = error.localizedDescription }
            }.disabled(validAmount == nil)
        }
    }

    private func quiz(_ round: QuizSession) -> some View {
        let question = round.current.question
        return VStack(alignment: .leading, spacing: 16) {
            HStack { Text(round.current.bank); Spacer(); Text("第 \(round.index + 1) / \(round.count) 题") }.font(.subheadline)
            ProgressView(value: Double(round.index + 1), total: Double(round.count))
            card {
                heading(question.prompt)
                ForEach(question.options.indices, id: \.self) { index in
                    let marked = round.feedback != nil && (index == question.answer || index == round.selection)
                    Button { session?.choose(index) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text(letter(index)).font(.subheadline.bold()).padding(5).background(paper, in: RoundedRectangle(cornerRadius: 5))
                            Text(question.options[index]).frame(maxWidth: .infinity, alignment: .leading)
                            if marked { Image(systemName: index == question.answer ? "checkmark.circle" : "xmark.circle") }
                        }.padding(10).frame(minHeight: 46).contentShape(Rectangle())
                            .background(marked ? (index == question.answer ? Color.green.opacity(0.14) : Color.red.opacity(0.13)) : round.selection == index ? blue.opacity(0.13) : paper, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).disabled(round.feedback != nil)
                        .accessibilityAddTraits(round.selection == index ? [.isSelected] : [])
                }
                if let feedback = round.feedback {
                    Divider()
                    Text("\(feedback.correct ? "回答正确" : "回答错误") · 正确答案 \(letter(question.answer))").font(.headline)
                    if !question.explanation.isEmpty { Text(question.explanation).font(.subheadline) }
                }
            }
            if round.mode == .exam && round.index > 0 { Button("上一题") { session?.previous() }.padding(.vertical, 8) }
            primary(round.mode == .practice && round.feedback == nil ? "提交答案" : round.isLast ? (round.mode == .exam ? "交卷" : "查看结果") : "下一题") {
                session?.advance()
            }.disabled(round.selection == nil)
        }
    }

    private func results(_ result: QuizSession.Result) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            card {
                heading("本轮成绩")
                Text("\(result.score) / 100 分").font(.system(.largeTitle, design: .serif).bold()).foregroundStyle(blue)
                Text("答对 \(result.hits) 题，共 \(result.reviews.count) 题")
            }
            card {
                heading("逐题回顾")
                ForEach(result.reviews) { row in
                    Divider()
                    Text("\(row.id + 1). \(row.correct ? "正确" : "错误") · \(row.entry.question.prompt)").font(.subheadline.bold())
                    Text("你的答案：\(letter(row.chosen)) · 正确答案：\(letter(row.entry.question.answer))").font(.caption)
                    if !row.entry.question.explanation.isEmpty { Text(row.entry.question.explanation).font(.footnote) }
                }
            }
            primary("返回工作台") { session = nil }
        }
    }

    private func importReview(_ bank: Bank) -> some View {
        NavigationStack {
            List {
                Section { Text("识别到 \(bank.questions.count) 道单选题，确认无误后保存。") }
                ForEach(bank.questions) { q in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(q.prompt).font(.headline)
                        ForEach(q.options.indices, id: \.self) { i in Text("\(letter(i)). \(q.options[i])") }
                        Text("答案：\(letter(q.answer))").font(.caption.bold())
                    }.padding(.vertical, 4)
                }
            }.navigationTitle(bank.name).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { preview = nil } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            let sampleIDs = Set(Self.samples.map(\.id))
                            do {
                                try library.save(banks.filter { !sampleIDs.contains($0.id) } + [bank])
                                banks.append(bank)
                                selected.insert(bank.id)
                                preview = nil
                            } catch { preview = nil; self.error = error.localizedDescription }
                        }
                    }
                }
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(.system(.title3, design: .serif).bold()).accessibilityAddTraits(.isHeader)
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content).padding(15).frame(maxWidth: .infinity, alignment: .leading)
            .background(cream, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(ink.opacity(0.10)))
    }
    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.headline).frame(maxWidth: .infinity, minHeight: 34) }
            .buttonStyle(.borderedProminent)
    }
    private func letter(_ option: Int) -> String { String(Array("ABCDEFGH")[option]) }

    private static let samples: [Bank] = [
        Bank(name: "材料与纹样（示例）", questions: [
            Question(prompt: "折纸最常用的材料是什么？", options: ["纸", "玻璃", "钢板"], answer: 0, explanation: "纸张容易折叠，也能保留折痕。"),
            Question(prompt: "同一纹样等距重复，最直接的视觉效果是什么？", options: ["透视", "规律的节奏", "随机分布"], answer: 1, explanation: "等距重复会形成视觉节奏。")
        ]),
        Bank(name: "传统工艺（示例）", questions: [
            Question(prompt: "编织中，纵向排列的一组线通常叫什么？", options: ["纬线", "经线", "接缝线"], answer: 1, explanation: "经线和横向穿过的纬线交织。"),
            Question(prompt: "把纸对折再剪，展开后通常得到什么？", options: ["轴对称图案", "立体模型", "渐变色"], answer: 0, explanation: "折线两侧形成镜像。")
        ])
    ]
}
