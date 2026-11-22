# 附加 02 Wi-Fi 显示「网络连接受限」

## 现象

连着 Wi-Fi 能上网，但状态栏提示「网络连接受限」；部分应用（依赖
`NetworkCapabilities.NET_CAPABILITY_VALIDATED`）行为异常。

## 根因

Android 用 captive portal 探测判断网络是否「已验证」，默认地址是
`connectivitycheck.gstatic.com`，国内不可达 → 一直判为
`PARTIAL_CONNECTIVITY`。

## 修复

关掉探测，并把探测端点换成返回 204 的地址：

```sh
su
settings put global captive_portal_mode 0
settings put global captive_portal_use_https 0
settings put global captive_portal_http_url    http://connect.rom.miui.com/generate_204
settings put global captive_portal_https_url   https://connect.rom.miui.com/generate_204
```

`captive_portal_mode 0` = 完全禁用探测（最省事）；想保留探测能力就用 `1` + 上面的 URL。

## 验证

```sh
dumpsys connectivity | grep -i -e VALIDATED -e PARTIAL
```

修复前 `partial=1`，修复后 `partial=0`、`validated=N` 正常增长。

## 备注

- 禁用探测后，真正需要网页认证的公共 Wi-Fi 不会自动弹登录页，需手动打开浏览器。
- 想恢复默认：`settings delete global captive_portal_mode`。
