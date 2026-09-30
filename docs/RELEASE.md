# macOS Release

公开分发需要含私钥的 **Developer ID Application** 证书及 Apple 公证凭据。Apple Development 或 ad-hoc 签名不能替代此流程。

将公证凭据存入钥匙串（由 notarytool 交互输入，不在仓库、命令行参数或聊天中记录密码）：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun notarytool store-credentials LongX-notary
```

检查证书，然后运行：

```sh
security find-identity -v -p codesigning
LONGX_SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' \
LONGX_NOTARY_PROFILE='LongX-notary' ./scripts/release.sh
```

脚本先验证证书与公证凭据，再构建 arm64/x86_64 Universal Release，使用 Hardened Runtime 和安全时间戳签名，提交 Apple 公证、附加票据、检查 Gatekeeper，最后生成 ZIP 和 SHA-256 校验文件。仅成功后输出到 `dist/`；不会上传 GitHub 或创建公开 Release。临时 App 和构建目录位于 `/private/tmp`，结束时移除并注销应用记录，避免应用列表出现重复图标。

## GitHub Actions

仓库：`mjason/longx-mac`。推送 `v0.1.0` 这样的标签，或手动运行 Signed Release 并填已有标签，即可触发测试、Universal 构建、签名、公证和 GitHub Release 上传。标签版本必须与 `MARKETING_VERSION` 一致。没有有效签名和公证时流程会失败，不发布假签名版本。

需配置的 Repository Secrets：

- `DEVELOPER_ID_P12_BASE64`：含私钥的 Developer ID Application P12，以 Base64 编码。
- `DEVELOPER_ID_P12_PASSWORD`：P12 密码。
- `DEVELOPER_ID_IDENTITY`：证书名称或 SHA-1。
- `NOTARY_APPLE_ID`：公证 Apple ID。
- `NOTARY_TEAM_ID`：开发者 Team ID。
- `NOTARY_PASSWORD`：Apple 应用专用密码。

证书和私钥在临时钥匙串内导入，流程结束自动删除。私钥、P12、密码均不进入仓库或发布包。客户端通过 GitHub `releases/latest` 检查正式版本，每日自动检查及 LongX 菜单手动检查；只对含标准下载包的非草稿、非预发布版本提示更新，打开官方 Release 页面供用户下载，暂不在后台安装更新。

发布版本 0.1.0；Developer ID G2 Application 证书已于 2026-09-30 创建，有效期至 2031-09-17。
