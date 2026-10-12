## 2026-10-12 | 任务：精简定制（服务与设置收敛、下线代码物理删除）

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->

**Links:** plan `docs/exec-plans/active/2026-10-12-custom-lite-edition.md`

### 执行上下文

- **Agent Name:** `ZCode`
- **Model:** `magpie/clinepass/cline-pass/deepseek-v4.1-flash`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

### 用户请求

在 Fork 上制作个人精简版：保留输入翻译、快捷键划词、鼠标自动划词与截图翻译；以 DeepSeek
为主并保留一个可配置地址/密钥/模型的 OpenAI 兼容接口；保留有道词典与系统词典、收藏、生词本、
内置 HTTP 服务；精简设置页，移除 Anki 与上游自动更新。

### 变更

第一阶段（收敛入口）：

- 服务注册表从 30 项收敛为 6 项：Apple Dictionary、有道、Apple、DeepSeek、内置 AI、
  自定义 OpenAI。
- 默认服务从「有道 + DeepL + 内置 AI」改为「有道 + DeepSeek」。
- `TTSServiceType` 只保留有道与 Apple，桥接与本地化同步收敛。
- 设置页从 8 个标签页减到 6 个：移除隐私与关于标签页，其内容并入通用页；通用页删除更新检查
  区块与语言检测优化选项；高级页删除 Beta 开关与 Anki 区块。
- 菜单栏移除版本号跳转与「检查更新」项，应用菜单移除「检查更新」命令，`MenuItemStore` 随之删除。
- `Info.plist` 移除 `SUFeedURL` 与 `SUPublicEDKey`，`SUEnableAutomaticChecks` 置为 false；
  Sparkle 控制器改为不启动。

第二阶段（物理删除，共 31,761 行删除 / 166 行新增）：

- 删除 21 个服务目录：Ali、AITool（润色与总结）、Baidu、Bing、Caiyun、Claude、ClaudeCode、
  CodexCLI、DeepL、Doubao、Gemini、GitHub Models、GitHubCopilot、Google、Groq、MiniMax、
  NiuTrans、Ollama、Tencent、Volcano、Zhipu，以及 Dictionary/MDict 与 `OpenAIService.swift`。
  保留 `BaseOpenAIService`、`StreamService` 等流式基础设施。
- 删除连带功能：AnkiConnect 与结果页 Anki 按钮、`AdvancedTabAnkiSection`、`PrivacyTab`、
  三个 CLI 服务的配置视图、Codex 运行时脚本与 `Prepare bundled Codex` 构建阶段、
  已下线服务的测试文件、`LanguageDetectOptimize` 与其扩展、无引用的 `ServiceAPIType.swift`、
  `AppPathManager+Codex.swift` 与 CLI 日志目录属性。
- 连带引用改造：`DetectManager` 改为系统语言检测单一来源；`ActionManager` 与
  `ShortcutAction`、`MenuBar` 移除润色链路；`StreamService+Configuration` 与 `LocalStorage`
  移除 Codex 分支；`APIKey`、`Defaults.Keys`、`ServiceConfigurationKey` 移除已下线服务、
  Anki、Beta 与语言检测优化配置；`EZResultView` 与 `EZSchemeParser` 移除对应钩子；
  `BuiltInAIService` 用本地 `BuiltInAIModel` 枚举替代已删除服务的模型枚举。
- 移除 Sparkle 依赖：`GlobalContext` 不再持有更新器，`MyConfiguration` 移除更新相关属性，
  Xcode 工程删除 SPM 包引用与 framework 链接。
- 工程文件通过 `xcodeproj` 库改写：移除 141 个文件引用、27 个分组与 1 个构建阶段，
  `project.pbxproj` 从 5571 行降至 4786 行。

### 设计意图

第一阶段以注册表收口代替删除文件，是因为当时缺少 Xcode、无法验证构建；先收口可在不触碰工程
文件的前提下达成界面精简，并让旧配置平滑降级。第二阶段在 Xcode 就绪后用 `xcodeproj` 改写工程
引用而非手改文本，并对每批删除重新构建，把工程损坏风险控制在可回退范围。

保留 `builtInAI` 是因为「翻译并替换」直接构造 `BuiltInAIService`，且它是唯一无需密钥的 AI 服务。
删除润色链路而非保留空壳，是因为其服务已下线、注册表查找必然失败。`TTSServiceType` 与朗读
实现必须保持一致，否则朗读会取到空服务。古典中文检测原先叠了一层 `beta` 开关，该开关随 Beta
设置项一并移除，检测改由 `isClassicalChineseDetectionEnabled` 参数单独控制。

### 验证

- `git diff --check`：通过。
- `plutil -lint Easydict/App/Info.plist`：OK。
- `jq -e . Easydict/App/Localizable.xcstrings`：有效；新增引用的本地化 key 全部存在。
- `swiftc -parse`：9 个改动的 Swift 文件全部解析通过（仅语法，未做类型检查）。
- `rg` 引用检查：无 `checkUpdateItem`、`MenuItemStore`、`checkUpdaterViewModel`、
  `SettingTab.privacy/.about`、已删除 TTS 选项的残留引用。
- 未运行：`xcodebuild build`、`xcodebuild test`、应用内手工验证。（当时本机只有 Command Line
  Tools，缺少 Xcode 16+；后续安装 Xcode 27.0 并补做，结果见下。）
- `xcodebuild build`（Xcode 27.0，`-derivedDataPath` 指向 agent 专用目录）：**BUILD SUCCEEDED**，
  0 错误。SwiftFormat 与 SwiftLint 构建阶段未产生文件改动（构建后 `git status` 为空）。产物为
  `Easydict-debug.app`（128 MB，ad-hoc 签名）。
- `xcodebuild test`：453 个测试 / 47 个 suite，42 个 suite 通过，70 个问题。
- 基线对照（同一命令在原始提交 `ec8c87b` 的独立 worktree 与独立 DerivedData 上运行）：
  453 个测试 / 86 个问题，失败 suite 为 Apple OCR Engine Image Tests、
  GitHubCopilotService、Service Translation Validation。逐项结论：
  - OCR：两边均为 61 个问题，属 macOS 版本导致的系统 OCR 结果差异，与本次改动无关。
  - Service Translation Validation：基线失败 23 个服务（全部因缺少密钥、CLI 或 AppleScript
    超时），本分支只剩 4 个（Apple、BuiltInAI、CustomOpenAI、DeepSeek），失败数量下降是注册表
    收敛的直接结果。
  - GitHubCopilotService：CLI 未安装的 2 个问题基线同样存在。
  - 由本次改动引起的失败共 3 个，均为注册表断言：`ClaudeCodeServiceTests.factoryRegistration`、
    `CodexCLIServiceTests.factoryRegistration`、`GitHubCopilotServiceTests` 的注册表断言。这三个
    服务已被有意移出注册表，断言按新事实已不成立。
- 启动冒烟测试（第一阶段）：直接执行 `Easydict-debug.app` 二进制，进程稳定存活、无崩溃报告，
  运行日志不含 `Unsupported service type` 或断言错误；`com.izual.Easydict-debug` 域下三种窗口的
  服务列表均为 `(Youdao, DeepSeek)`，确认默认服务改动在运行期生效。
- 第二阶段构建：删除 31,761 行后 `xcodebuild build` 仍为 BUILD SUCCEEDED，0 错误。
- 第二阶段测试：211 个测试 / 28 个 suite，65 个问题，失败 suite 只剩 Apple OCR Engine Image
  Tests（61 个，与基线逐项相同）与 Service Translation Validation（4 个，剩余已注册服务缺少
  密钥）。第一阶段由改动引起的 3 个注册表断言失败已随测试文件删除消失。
- 引用扫描：从被删文件提取 236 个类型名后全库扫描，无残留引用；`plutil -lint` 与
  `xcodeproj` 重新解析工程文件均通过。
- 第二阶段启动冒烟测试：进程稳定、无错误日志与崩溃报告，服务列表仍为 `(Youdao, DeepSeek)`。
- 规模变化：应用 Swift 文件 371 → 256，测试 Swift 文件 56 → 36，源码文件合计 633 → 498；
  `Easydict-debug.app` 由 128 MB 降至 118 MB（Debug 构建）。
- 未运行：真机手工交互验证（输入翻译、划词、截图翻译的实际翻译效果）。

### 受影响文件

第一阶段：

- `Easydict/Swift/Service/Model/QueryServiceFactory.swift`
- `Easydict/Swift/Service/Model/Storage/LocalStorage.swift`
- `Easydict/Swift/Service/Model/TTSServiceType.swift`
- `Easydict/Swift/Utility/GlobalContext.swift`
- `Easydict/Swift/View/MenuItemView.swift`
- `Easydict/Swift/View/MenuView/MainMenuCommand.swift`
- `Easydict/Swift/View/SettingView/SettingView.swift`
- `Easydict/Swift/View/SettingView/Tabs/TabView/AdvancedTab.swift`
- `Easydict/Swift/View/SettingView/Tabs/TabView/GeneralTab.swift`
- `Easydict/App/Info.plist`

第二阶段（新增或改动的关键路径，完整清单见 `git show`）：

- 删除：`Easydict/Swift/Service/` 下 21 个服务目录、`Dictionary/MDict`、`OpenAIService.swift`、
  `Easydict/Swift/Feature/AnkiConnect/`、三个 CLI 服务配置视图、
  `AdvancedTabAnkiSection.swift`、`PrivacyTab.swift`、`LanguageDetectOptimizeExtensions.swift`、
  `ServiceAPIType.swift`、`AppPathManager+Codex.swift`、`scripts/codex-runtime/`、
  以及 20 个已下线服务的测试文件。
- 改动：`Easydict/Swift/Model/DetectManager.swift`、
  `Easydict/Swift/Feature/ActionManager/ActionManager.swift`、
  `Easydict/Swift/Service/OpenAI/StreamService+Configuration.swift`、
  `Easydict/Swift/Service/OpenAI/StreamService.swift`、
  `Easydict/Swift/Service/DeepSeek/DeepSeekService.swift`、
  `Easydict/Swift/Service/BuiltInAI/BuiltInAIService.swift`、
  `Easydict/Swift/Feature/DefaultAPIKeys/APIKey.swift`、
  `Easydict/Swift/Feature/Configuration/{Defaults.Keys+Extension,MyConfiguration,ServiceConfigurationKey,Configuration+UserData}.swift`、
  `Easydict/Swift/Feature/Shortcut/Model/ShortcutAction.swift`、
  `Easydict/Swift/Feature/Shortcut/View/KeyHolderWrapper.swift`、
  `Easydict/Swift/View/SettingView/Tabs/TabView/ServiceTabListViews.swift`、
  `Easydict/Swift/Utility/AppPathManager/AppPathManager+Logs.swift`、
  `Easydict/App/EasydictApp.swift`、
  `Easydict/objc/ViewController/View/WordResultView/EZWordResultView.m`、
  `Easydict/objc/ViewController/View/ResultView/EZResultView.m`、
  `Easydict/objc/Utility/EZLinkParser/EZSchemeParser.m`、
  `EasydictTests/Service/AppleLanguageDetectorTests.swift`、
  `Easydict.xcodeproj/project.pbxproj`、`Easydict/App/Info.plist`。
- 新增工具：`scripts/remove-xcode-paths.rb`（按清单批量移除工程文件引用与分组，可复用）。

### 后续事项

- 遗留清理：`Localizable.xcstrings` 中已下线服务与已移除设置项的文案 key 仍保留，属无害残留，
  需要时可用脚本按引用扫描清理。
- 行为变化：古典中文检测不再受已移除的 Beta 开关限制，改为由 `isClassicalChineseDetectionEnabled`
  参数控制（默认启用）；如需恢复旧行为可在调用处传 `enableClassicalChineseDetection: false`。
- 迁移提示：已保存的服务列表若包含已下线服务会被静默跳过；若某窗口的服务全被下线，需要到
  设置 → 服务重新添加。
- 未验证：真机手工交互（输入翻译、快捷键划词、鼠标划词、截图翻译）与设置页视觉确认。
- 分支 `custom/lite` 的提交尚未 push 到 Fork，按仓库规则需用户明确要求后执行。
