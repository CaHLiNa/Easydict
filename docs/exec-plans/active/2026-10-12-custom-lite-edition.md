# 定制精简版：服务与设置收敛

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->
<!-- 本模板只用于多步骤、跨模块或高风险的执行任务。 -->

- 状态：active
- 创建日期：2026-10-12
- 负责人：CaHLiNa
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `ZCode`
- **Model:** `magpie/clinepass/cline-pass/deepseek-v4.1-flash`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

## 背景

Easydict 面向通用用户维护了 30 个可注册服务、8 个设置标签页以及 AI 工具、Anki、HTTP
服务等附加集成。个人使用时这些入口造成设置页冗长和功能噪音，同时默认服务并不指向实际
使用的 AI 提供方。本任务在 Fork 上落地个人精简版，只保留日常入口。

## 目标与范围

- 目标结果：服务注册表收敛为 6 项；默认服务改为有道与 DeepSeek；设置页从 8 个标签页减到
  6 个；移除上游自动更新入口；移除 Anki 设置入口与 Beta 开关。
- 允许修改路径：`Easydict/Swift/Service/Model/`、`Easydict/Swift/View/`、
  `Easydict/Swift/Utility/GlobalContext.swift`、`Easydict/App/Info.plist`。
- 同任务 history：`docs/histories/2026-10/2026-10-12-custom-lite-edition.md`
- 用户限制：保留输入翻译、快捷键划词、鼠标自动划词、截图翻译；保留有道词典、系统词典；
  保留一个可配置地址/密钥/模型的兼容接口；保留收藏、生词本、内置 HTTP 服务；只精简设置页。
- 非目标：删除服务源文件与 Xcode 工程引用、移除 Sparkle 依赖、精简查询结果窗口与菜单栏
  功能项、改动发布与签名流程。
- 验收标准：设置页服务列表只出现保留的 6 项；默认窗口服务为有道 + DeepSeek；设置页不含
  更新、Beta、Anki、隐私独立标签页与关于独立标签页；应用不再触发上游更新检查。

## 工作计划

1. 收敛 `QueryServiceFactory` 服务注册表。
2. 调整 `LocalStorage` 默认服务。
3. 收敛 TTS 选项，清理朗读与语言检测的悬空选项。
4. 精简设置页标签页与通用、高级标签页区块。
5. 移除菜单栏与应用菜单的更新入口，隔离 Info.plist 的 appcast 配置。
6. 运行静态检查并提交。

## 第二阶段范围（物理删除，已完成）

用户明确要求删除代码而非仅从前端隐藏。删除对象与其工程引用一并移除：

- 服务源码：Ali、AITool（润色/总结）、Baidu、Bing、Caiyun、Claude、ClaudeCode、CodexCLI、
  DeepL、Doubao、Gemini、GitHub Models、GitHubCopilot、Google、Groq、MiniMax、NiuTrans、
  Ollama、Tencent、Volcano、Zhipu、Dictionary/MDict、OpenAI 的具体服务（保留
  BaseOpenAIService、StreamService 等流式基础设施）。
- 连带代码：AnkiConnect 功能与结果页 Anki 按钮、AdvancedTabAnkiSection、PrivacyTab；
  三个已下线 CLI 服务的配置视图；Codex 运行时脚本与 `Prepare bundled Codex` 构建阶段；
  已下线服务的测试文件（用户已授权）。
- 受影响调用点：DetectManager（语言检测改为 Apple 单一来源）、ActionManager（移除润色链路）、
  StreamService 与 StreamService+Configuration（移除 Codex 分支）、LocalStorage（移除 Codex
  配置迁移）、APIKey 与 Defaults 键（移除已下线服务与 Anki 配置）。
- 验证：每批删除后运行 `xcodebuild build`，全部完成后运行 `xcodebuild test` 并与第一阶段基线
  对照，最后重新做启动冒烟测试。
- 非目标：不改动保留下线的服务与功能行为；不重新设计查询流程；不改动 Pods 与仍有引用的
  SPM 依赖。

## 风险与决策

- 本机无 Xcode，无法运行 `xcodebuild`，因此本阶段改动只经过语法解析、plist、本地化 key 与
  引用检查，未经过类型检查与构建验证。物理删除服务文件因此推迟到下一阶段。
- 决策：注册表收敛而非删除文件。`LocalStorage` 对未注册类型返回 nil 并跳过，旧配置不会导致
  启动异常，先收口可以在不触碰 `project.pbxproj` 的前提下达到界面精简目标。
- 决策：保留 `builtInAI`。`ActionManager` 的“翻译并替换”直接构造 `BuiltInAIService`，移除它
  会破坏该功能链，且它是唯一无需密钥的 AI 服务。
- 决策：`TTSServiceType` 只保留有道与 Apple。朗读通过注册表查找服务，删除选项必须与注册表
  保持一致，否则朗读会得到空服务。
- 决策：Sparkle 控制器改为不启动且移除 appcast 配置，避免无 feed 时向用户弹出错误；彻底解绑
  Sparkle 依赖留到下一阶段。
- 决策：Anki 仅移除设置入口与开关可达性，运行时代码保留，避免在未验证构建的情况下改动
  Objective-C 结果视图。

## 进度

- [x] 收敛服务注册表 30 → 6。
- [x] 默认服务改为有道 + DeepSeek。
- [x] TTS 选项与语言检测选项收敛。
- [x] 设置页 8 → 6 个标签页，通用页合并隐私与关于，高级页移除 Beta 与 Anki。
- [x] 更新入口与 appcast 隔离。
- [x] 静态检查与提交准备。
- [x] 构建、测试与启动冒烟测试（见“验证”）。
- [x] 第二阶段物理删除：服务与连带功能文件、工程引用、Codex 构建阶段、Sparkle 依赖，
  删除后构建与测试重新通过。

## 验证

- `git diff --check`：通过。
- `plutil -lint Easydict/App/Info.plist`：OK。
- `jq -e . Easydict/App/Localizable.xcstrings`：JSON 有效；新引用的本地化 key 全部存在。
- `swiftc -parse <每个改动的 .swift>`：9 个文件全部解析通过（仅语法，不做类型检查）。
- `rg` 引用检查：无残留的 `checkUpdateItem`、`MenuItemStore`、`checkUpdaterViewModel`、
  `SettingTab.privacy/.about`、已删除的 TTS 选项引用。
- 未运行（首次记录时）：`xcodebuild build`、`xcodebuild test` 与应用内手工验证，当时本机只有
  Command Line Tools。任务中期安装 Xcode 27.0 并完成首次启动组件安装后补做，结果如下。
- `xcodebuild build`：BUILD SUCCEEDED，0 错误；格式与 lint 构建阶段未改动文件；产物
  `Easydict-debug.app`。
- `xcodebuild test`：453 个测试 / 47 个 suite，42 个 suite 通过，70 个问题。
- 基线对照：原始提交 `ec8c87b` 同一命令为 86 个问题，失败 suite 为 OCR、GitHubCopilotService、
  Service Translation Validation；OCR 的 61 个问题两边相同，服务校验由 23 个降为 4 个。
  由本次改动引起的失败仅 3 个注册表断言，对应已下线服务。
- 启动冒烟测试：进程稳定、无崩溃报告、日志无未注册服务告警，默认服务列表为有道与 DeepSeek。
- 未运行：真机手工交互验证（输入翻译、划词、截图翻译的实际翻译效果）。
- 第二阶段构建与测试：删除 31,761 行后 `xcodebuild build` 仍为 BUILD SUCCEEDED；测试为
  211 个测试 / 28 个 suite / 65 个问题，失败仅剩 Apple OCR Engine Image Tests（61 个，与基线
  逐项相同）与 Service Translation Validation（4 个，剩余服务缺密钥）。
- 第二阶段引用扫描：从被删文件提取 236 个类型名后全库扫描无残留；`plutil -lint` 与
  `xcodeproj` 重新解析工程均通过。
- 第二阶段启动冒烟测试：进程稳定、无错误日志与崩溃报告，服务列表仍为 `(Youdao, DeepSeek)`。
- 规模：应用 Swift 文件 371 → 256，测试 Swift 文件 56 → 36，源码文件 633 → 498，
  Debug 产物 128 MB → 118 MB。

## 完成条件

- 上述静态检查全部通过且无悬空引用。
- `docs/histories/2026-10/2026-10-12-custom-lite-edition.md` 记录结果与验证状态。
- 第一阶段与第二阶段均构建通过；测试结果已按基线对照归因，无由本次改动引起的失败。
- 归档条件：真机手工交互验证通过后移动到 `docs/exec-plans/completed/2026-10/`；
  在此之前计划保持 active，用于跟踪遗留清理项。
