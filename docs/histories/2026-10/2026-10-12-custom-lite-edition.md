## 2026-10-12 | 任务：收敛服务注册表与设置页，隔离上游更新

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->

**Links:** plan `docs/exec-plans/active/2026-10-12-custom-lite-edition.md`

### 执行上下文

- **Agent Name:** `ZCode`
- **Model:** `magpie/clinepass/cline-pass/deepseek-v4.1-flash`
- **Environment:** `macOS 27.0.1 / Xcode Unknown`

### 用户请求

在 Fork 上制作个人精简版：保留输入翻译、快捷键划词、鼠标自动划词与截图翻译；以 DeepSeek
为主并保留一个可配置地址/密钥/模型的 OpenAI 兼容接口；保留有道词典与系统词典、收藏、生词本、
内置 HTTP 服务；精简设置页，移除 Anki 与上游自动更新。

### 变更

- 服务注册表从 30 项收敛为 6 项：Apple Dictionary、有道、Apple、DeepSeek、内置 AI、
  自定义 OpenAI。
- 默认服务从「有道 + DeepL + 内置 AI」改为「有道 + DeepSeek」。
- `TTSServiceType` 只保留有道与 Apple，桥接与本地化同步收敛。
- 设置页从 8 个标签页减到 6 个：移除隐私与关于标签页，其内容并入通用页；通用页删除更新检查
  区块与语言检测优化选项；高级页删除 Beta 开关与 Anki 区块。
- 菜单栏移除版本号跳转与「检查更新」项，应用菜单移除「检查更新」命令，`MenuItemStore` 随之删除。
- `Info.plist` 移除 `SUFeedURL` 与 `SUPublicEDKey`，`SUEnableAutomaticChecks` 置为 false；
  Sparkle 控制器改为不启动。

### 设计意图

以注册表收口代替删除文件：`LocalStorage` 对未注册类型返回 nil 并跳过，旧配置不会导致启动异常，
且不必改动 `project.pbxproj`，在本机缺少 Xcode 的情况下把风险控制在可回退范围。保留
`builtInAI` 是因为「翻译并替换」直接构造 `BuiltInAIService`；朗读选项与服务注册表必须一致，
否则朗读会取到空服务。Anki 只断开设置入口，Objective-C 结果视图保持不动。

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
- 启动冒烟测试：直接执行 `Easydict-debug.app` 二进制，进程稳定存活、无崩溃报告，运行日志不含
  `Unsupported service type` 或断言错误；`com.izual.Easydict-debug` 域下三种窗口的服务列表均为
  `(Youdao, DeepSeek)`，确认默认服务改动在运行期生效。
- 未运行：真机手工交互验证（输入翻译、划词、截图翻译的实际翻译效果）。

### 受影响文件

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

### 后续事项

- 待决：三个注册表断言（`ClaudeCodeServiceTests`、`CodexCLIServiceTests`、
  `GitHubCopilotServiceTests`）随服务下线而失败。按仓库规则，测试文件的修改需要用户明确授权，
  故未在本轮改动；建议在第二阶段删除这三个已下线服务的测试文件并同步测试 target 引用。
- 第二阶段：物理删除已下线服务的源文件与 `project.pbxproj` 引用、移除 Codex 运行时构建阶段、
  彻底解绑 Sparkle、删除 Anki 运行时代码。
- 润色与总结服务已从注册表移除，但 `ActionManager` 仍会为「润色并替换」直接构造
  `PolishingService`；若不使用润色功能，可在第二阶段一并移除该菜单项与快捷键。
- 迁移限制：已保存的服务列表若只包含已下线服务（例如只有 DeepL），该窗口会显示为空列表，
  需要到设置 → 服务重新添加；未注册类型会被 `LocalStorage` 静默跳过，不会影响启动。
- 迁移限制：若此前手动开启过 Anki，`enableAnkiConnect` 仍为 true，结果页 Anki 按钮因未改动
  Objective-C 结果视图而继续显示；需要时可手动关闭该 UserDefaults 值。
- 清理项：`PrivacyTab.swift`、`AdvancedTabAnkiSection.swift`、`LanguageDetectOptimize` 的
  选项扩展与相关本地化 key 已不再被引用，留待第二阶段一并处理。
