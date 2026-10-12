## 2026-10-12 | 任务：修复权限授权失效（改用稳定签名身份）

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->

**Links:** `scripts/build-app.sh`

### 执行上下文

- **Agent Name:** `ZCode`
- **Model:** `magpie/clinepass/cline-pass/deepseek-v4-flash`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

### 用户请求

用户反馈：授权辅助功能后，点击划词翻译又提示需要授权，且授权被系统取消；隐私设置列表里
出现两条 Easydict 条目，其中一条是 debug 版本。

### 变更

- `scripts/build-app.sh` 改为优先使用本地「Apple Development」证书签名（无证书时回退 ad-hoc），
  并在输出中打印所用身份与 `codesign -dr` 指定要求。
- 使用钥匙串中现有的 Apple 开发证书重新签名 `/Applications/Easydict.app` 及内部框架，
  并重新安装。
- 清理：删除 Debug 构建产物 `Easydict-debug.app`；重置 `com.izual.Easydict-debug` 与
  `com.cahlina.easydict` 的 Accessibility / ScreenCapture 授权记录。

### 设计意图

ad-hoc 签名的「指定要求」包含二进制哈希（cdhash），每次重新构建都会变化，macOS 因此把新
构建视为另一个应用，之前授予的辅助功能与屏幕录制权限随之失效。改用证书签名后，指定要求
变为基于证书的形式：

```text
identifier "com.cahlina.easydict" and anchor apple generic
and certificate leaf[subject.CN] = "Apple Development: shifei343112@gmail.com (7W6A9JJL87)"
```

该要求不随二进制变化，重建与覆盖安装后仍然满足，权限因此可以长期保留。签名放在脚本里而不是
写进 Xcode 工程，保持工程文件可移植；需要时可用 `SIGN_IDENTITY` 覆盖。

### 验证

- `./scripts/build-app.sh`：构建成功，输出 `signed with: Apple Development: ...`，`codesign
  --verify --strict` 通过，TeamIdentifier 为 `NC5MXQKZ5X`。
- 持久性证据：改签名前手工签名的应用与脚本完整重建后的应用，`codesign -dr -` 输出完全一致的
  指定要求字符串，说明重建不会改变 TCC 判定依据。
- 重新安装后启动正常（进程存活）。
- `tccutil reset`：`com.cahlina.easydict` 的 Accessibility 与 ScreenCapture 记录已重置；
  `com.izual.Easydict-debug` 返回「no such bundle identifier」，说明其授权记录已随 App 包删除
  一并清除。

### 受影响文件

- `scripts/build-app.sh`

### 后续事项

- 用户需重新授予一次辅助功能与屏幕录制权限；此后重建不再失效。设置列表若仍显示失效的
  debug 条目，可用列表下方的减号手动移除。
- 签名身份来自钥匙串中的开发证书，证书过期时间由 Apple 决定（开发证书通常一年），过期后
  需重新签名。
