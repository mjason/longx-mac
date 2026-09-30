# 网页控制 macOS 顶部栏（API v1）

从 LongX macOS 0.1.1 开始，原生不再读取网页 CSS、localStorage 或按路由推断颜色。网页通过 JS 主动设置原生窗口顶部栏背景与控件外观。不影响网页 DOM、Tab 或菜单。

## 调用

客户端在主页面 document-start 提供 `window.longxNative`：

```js
window.longxNative?.setChrome({
  background: '#15171c',
  theme: 'dark',
});
```

- `background`：必填，不透明的 `#RRGGBB`，大小写均可。不接受 CSS 变量、rgb() 或透明色。
- `theme`：必填，`light` / `dark` / `system`。控制原生顶部控件、服务器面板等原生界面的外观。`system` 让原生外观跟随 macOS；网页仍需发送当前实际背景色。
- 返回 `true` 表示消息已提交，不表示原生渲染已完成。字段不合法时返回 `false`，不修改原生状态。
- `window.longxNative.version` 为 `1`。普通浏览器中此对象不存在，使用可选链或特性检测。

网页应在首次挂载、路由/页签变化、主题变化和系统外观变化时主动调用。每台服务器维护独立的窗口样式状态，切换服务器时随缓存会话切换。新文档在提供配置前沿用该会话最近收到的状态；首次未提供时使用 macOS 默认外观。

## 导航刷新请求

客户端在 URL 变化、页面提交和加载完成后，触发 `longx:chrome-request` 事件。网页监听后重新发送自己的配置：

```js
function syncNativeChrome() {
  // 这两个值由网页自己的页面布局和主题状态决定。
  const background = appChrome.background;
  const theme = appChrome.theme; // 'light' | 'dark' | 'system'
  window.longxNative?.setChrome({ background, theme });
}
window.addEventListener('longx:chrome-request', syncNativeChrome);
syncNativeChrome();
// 在网页路由渲染完成、切换主题以及系统深浅色变化时也调用 syncNativeChrome。
// 组件卸载时：window.removeEventListener('longx:chrome-request', syncNativeChrome);
```

事件可能连续触发多次；处理函数应可重复调用。客户端不会在收到事件后自行取色。网页决定是否以及何时响应。

## 底层 WKWebView 消息

也可以直接发送以下 JSON，不依赖辅助函数：

```js
window.webkit?.messageHandlers?.longxChrome?.postMessage({
  version: 1,
  background: '#ffffff',
  theme: 'light',
});
```

原生仅接受主框架消息，并完整校验版本、颜色和主题；不合法的消息整体忽略。底层通道无返回值。旧的 `{frame, preference}` 消息不再接受。
