# LongX for macOS

SwiftUI + WKWebView 的原生 LongX 客户端，macOS 15 或更高版本。默认服务器为 https://longx.diz.plus:7443。

## 开发与运行

打开 `LongX.xcodeproj`，选择 LongX scheme 后运行。工程已经生成，不需要先安装依赖。

```sh
./scripts/build.sh
open build/Build/Products/Release/LongX.app
```

`project.yml` 是 XcodeGen 工程配置源；修改目标或文件布局后可运行 `xcodegen generate`。开发构建使用本机 ad-hoc 签名。正式发布使用 `scripts/release.sh`，完成 Developer ID 签名、公证和打包；步骤见 [docs/RELEASE.md](docs/RELEASE.md)。

## 液态玻璃

macOS 26 及以上使用系统原生 Liquid Glass：覆盖网页的弹出服务器面板、系统玻璃工具栏、玻璃添加按钮、玻璃弹窗操作按钮及错误提示浮层。服务器面板由工具栏按钮打开，切换后自动收起，点击面板外或按 Escape 关闭；面板通过 overlay 显示，不改变 WKWebView 尺寸。macOS 15–25 回退为系统材质与标准按钮；保留系统的降低透明度和辅助功能行为。

顶部背景及深浅主题由网页 JS 主动通过 `window.longxNative.setChrome` 设置；原生不读取 CSS、localStorage 或根据路由判断外观。导航时只发送刷新请求，网页决定响应值。接口和接入示例见 [docs/WEB-CHROME-API.md](docs/WEB-CHROME-API.md)。网页 Tab 保留上游原样；客户端不注入 CSS，不修改网页布局或 Tab 样式。

## 语言

原生界面支持简体中文与英语，默认跟随 macOS 应用语言。可在系统设置 → 通用 → 语言与地区 → 应用程序中为 LongX 指定语言，重新启动后生效。菜单、服务器管理、工具栏提示、错误提示和原生确认按钮均已本地化；自定义服务器名称和网页内容保持各自的设置。翻译资源位于 `LongX/en.lproj` 和 `LongX/zh-Hans.lproj`，未支持的语言回退到英语。

## 服务器管理

工具栏打开服务器面板，添加、选择服务器，点击服务器旁的“…”菜单编辑名称和地址，右键也可编辑或移除。地址支持 HTTPS / HTTP，省略协议默认 HTTPS。服务器列表和上次选择持久保存。

每条服务器配置拥有独立、持久的 WKWebsiteDataStore，隔离 Cookie、登录和 localStorage。已访问服务器的 WKWebView 保持挂载在同一个窗口容器中，切换只改变显隐和输入焦点，保留输入、滚动与网页连接；首次访问才创建和加载，不提前打开未访问的服务器。仅移除配置或修改地址时卸载对应视图。后台网页由 WebKit 调度，因此不保证操作系统始终让后台连接活跃。修改地址重建该实例；仅改名不重载。移除服务器会请求删除对应本地网站数据，不影响服务器内容。

## 快捷键

| 快捷键 | 行为 |
| --- | --- |
| ⌘⌥1–9 | 切换前九台服务器 |
| ⌘⌥N | 添加服务器 |
| ⌘⌥, | 编辑当前服务器 |
| ⌘R | 重新加载当前服务器 |
| ⌘⇧W | 关闭客户端窗口 |
| ⌘Q | 退出客户端 |
| ⌘K / ⌘T / ⌘W / ⌘S / ⌘1–4 | 交给 LongX 网页的命令面板、会话、页签、文件和工具窗口 |
| ⌘⇧T / ⌘⌥←→ / Ctrl+Tab | 交给网页页签操作 |

通过 document-start 脚本设置 `data-app-window`，启用上游现有的客户端快捷键。普通编辑快捷键、中文输入法和系统快捷键保留系统处理。不注册原生 shell bridge；命令面板、选择器、输入弹窗、任务/监控和 Space 菜单均由网页处理，网页样式保留上游原样。

包含文件选择上传、下载保存、JS 弹窗、导航失败重试、外链系统浏览器打开。TLS 证书按系统标准校验。

## 上游与后续文档

`vendor/longx` 是 https://github.com/mjason/longx 的 Git submodule，已 clone；后续可直接读取上游源码和文档。克隆客户端时使用 `git clone --recurse-submodules`，或执行 `git submodule update --init`。

Sparkle 许可证见 `docs/SPARKLE-LICENSE`。

Logo 和图标来自上游 `priv/static/images/logo-mark.png` 与 `priv/static/icons/icon-512.png`。上游许可证副本见 `docs/UPSTREAM-LICENSE`。客户端需求、方案和后续文档放在本项目 `docs/` 中。

## 发布与更新

代码仓库：[mjason/longx-mac](https://github.com/mjason/longx-mac)。GitHub Actions 在版本标签上运行测试、Universal 构建、Developer ID 签名、Apple 公证及发布 ZIP；配置说明见 [docs/RELEASE.md](docs/RELEASE.md)。

LongX 通过 Sparkle 在 App 内自动检查、下载、验证并安装更新，默认每天检查，后台准备更新后在退出时安装；手动「检查更新…」可选择安装并重启。GitHub Actions 同时发布签名的 `appcast.xml` 和更新 ZIP。下载包及订阅文件使用 Ed25519 签名，安装包保留 Developer ID 签名和 Apple 公证。更新不发送服务器配置，Sparkle 系统信息收集默认关闭。0.1.2 及更早版本需要一次升级到 0.1.3，之后可直接在 App 内更新。

## 验证

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project LongX.xcodeproj -scheme LongX -destination 'platform=macOS' \
  -derivedDataPath build CODE_SIGN_IDENTITY=- test
```

单元测试覆盖地址验证、配置持久化、选中服务器恢复、移除后的回退、WKWebView 复用与地址变化失效。实际界面已检查默认服务器加载、⌘K 命令面板、添加服务器、⌘⌥1/2 切换和搜索输入保留、⌘W 不关闭窗口以及移除临时配置。尚未实测附件上传下载、复杂 OAuth 流程及后台长期连接。

窗口保留系统缩放、最小化和填充命令；缩放使用最大可用尺寸，标题栏双击遵循 macOS 的双击设置。
