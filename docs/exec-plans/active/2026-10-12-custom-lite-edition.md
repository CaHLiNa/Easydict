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
- **Environment:** `macOS 27.0.1 / Xcode Unknown`

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

## 验证

- `git diff --check`：通过。
- `plutil -lint Easydict/App/Info.plist`：OK。
- `jq -e . Easydict/App/Localizable.xcstrings`：JSON 有效；新引用的本地化 key 全部存在。
- `swiftc -parse <每个改动的 .swift>`：9 个文件全部解析通过（仅语法，不做类型检查）。
- `rg` 引用检查：无残留的 `checkUpdateItem`、`MenuItemStore`、`checkUpdaterViewModel`、
  `SettingTab.privacy/.about`、已删除的 TTS 选项引用。
- 未运行：`xcodebuild build`、`xcodebuild test`。本机只有 Command Line Tools，缺少 Xcode 16+，
  属环境阻塞，未作为通过记录。
- 未运行：应用内手工验证（输入翻译、快捷键划词、鼠标划词、截图翻译、设置页外观）。

## 完成条件

- 上述静态检查全部通过且无悬空引用。
- `docs/histories/2026-10/2026-10-12-custom-lite-edition.md` 记录结果与验证状态。
- 具备 Xcode 环境后补做 `xcodebuild build` 与应用内手工验证；两项通过后归档到
  `docs/exec-plans/completed/2026-10/`。在此之前计划保持 active，第二阶段的文件与依赖删除
  同属本计划后续工作。
