# 研题册 · iOS

Swift + SwiftUI，目标 iOS 16+。包含题库多选、顺序/随机抽题、自定义题量、练习逐题反馈、考试交卷判分和结果回顾。题库保存在本机。内置两份示例题库。

## 导入

支持 UTF‑8 TXT、带文字层的 PDF 和 DOCX；要求单选题逐题有编号、连续字母标注的选项和正确答案。支持可选解析；不支持扫描 OCR、旧版 DOC、Excel 或答案集中在文末的排版。识别后可预览并确认保存。

```text
1. 折纸最常用的材料是什么？
A. 纸
B. 钢板
答案：A
解析：纸张可以保留折痕。
```

## 测试与打包

- `swift test` 运行不依赖 SwiftUI 的题库解析、出题与判分测试。
- Mac 上安装 XcodeGen (`brew install xcodegen`)，在项目根目录执行 `xcodegen generate`，打开 `StudyEdition.xcodeproj`。
- 把这个项目放入 GitHub 仓库的默认分支后，在 Actions 的 `iOS unsigned IPA` 工作流中点 `Run workflow`。成功后从运行页面的 Artifacts 下载 `StudyEdition-iOS-unsigned`，解压得到 `.ipa`。
- IPA 面向 iPhone 真机，但未经签名，不能直接安装；需要后续签名。该流程不需要上传证书。
