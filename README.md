# Bliss OS on Surface Pro 7+ 修复合集

适用于 **Microsoft Surface Pro 7+**（Intel THC 触控，`045E:0C1A`）安装
**BlissOS Surface 版**（Android 13 / 16.9.7，内核 `6.1.112-gloria-surface-xanmod1`；
15.9.2 / Android 12L 同样适用）。

每个问题都按 **现象 → 根因 → 修复 → 验证** 写，全部在实机上验证过。

## 问题一览

### 触控

| # | 现象 | 根因 | 修复 |
|---|------|------|------|
| 1 | 触屏被识别成**触控板**，划屏只移动鼠标 | `iptsd-find-hidraw` 是 bash 脚本，Android 的 `sh` 跑不了 → `iptsd_runner` 以 106 退出 → 只剩内核单点 HID 设备 | 自己拉起 `iptsd`（[docs/01](docs/01-触屏变触控板.md)） |
| 2 | 手势**时好时坏**、滑不动 | iptsd 每 70~120ms 判丢触点，`BTN_TOUCH` 疯狂 UP/DOWN | 放宽稳定性阈值（[docs/02](docs/02-触点抖动.md)） |
| 3 | 轻触**不灵敏** | 默认 `SizeMin`/`ActivationThreshold` 偏严 | 逐档调低（[docs/03](docs/03-轻触灵敏度.md)） |
| 4 | 写字时**手掌误触** | 未启用笔的防误触 | `DisableOnStylus = true`（[docs/04](docs/04-写字防误触.md)） |
| 5 | 摸着摸着**突然息屏** | Launcher3「双击休眠」手势被误触 | `pref_sleep_gesture=false`（[docs/05](docs/05-误触息屏.md)） |
| 8 | rEFInd 菜单**不能触摸**、报 `No mapping` 卡按键 | rEFInd 0.14.0 触摸有缺陷；扫卷失败要按键 | FydeOS 0.14.1 + `scanfor manual,firmware`（[docs/08](docs/08-rEFInd触摸与无键盘启动.md)） |

### 蓝牙 / 按键

| # | 现象 | 根因 | 修复 |
|---|------|------|------|
| 6 | 蓝牙**打不开**，KSU 模块「刷了不生效」 | 内核命令行缺 `BTLINUX_HAL` / `DATA_CUSTOM` | 补参数 + 蓝牙模块（[docs/06](docs/06-Bluetooth打不开.md)） |
| 7 | **音量键失灵**（电源键正常） | `soc_button_array` 抢 GPIO，`gpio_keys` 绑不上 `MSHW0040` | `deferred soc_button_array`（[docs/07](docs/07-音量键失灵.md)） |

### 附加（同类构建常见小问题）

- [存储显示 2T / 已用 95%](docs/extra/存储显示2T.md)
- [时间快 8 小时](docs/extra/时间快8小时.md)
- [Wi-Fi 显示「网络连接受限」](docs/extra/WiFi连接受限.md)
- ⚠️ **[不要用 Windows 的 ext4 工具改 `/data`](docs/extra/不要用Windows改data.md)** —— 会把应用目录属主改成 root，导致永久 bootloop

## 快速使用

```sh
# 1) 触控：拉起 iptsd（解决「触控板」）
su -c 'sh scripts/start-iptsd.sh'

# 2) 触控参数：装配置后重启 iptsd
su -c 'mkdir -p /data/vendor/iptsd.d && cp config/90-touch.conf /data/vendor/iptsd.d/'
su -c 'sh scripts/start-iptsd.sh restart'

# 3) 音量键：写入 blocklist 后重启（必须重启）
su -c 'cp config/modules.blocklist /data/vendor/modules.blocklist'

# 4) rEFInd 触摸（把 0.14.1 的 refind_x64.efi 放在脚本同目录）
su -c 'sh scripts/refind-touch.sh 8'

# 5) 存储 2T 显示
su -c 'sh scripts/shrink-module-image.sh'   # 之后重启并删 modules.img.old
```

做成 KernelSU 模块的话，把 `scripts/service.sh` 当 `service.sh`、
`scripts/post-fs-data.sh` 当 `post-fs-data.sh`，`config/90-touch.conf` 放 `config/` 下即可。

## 目录

```
config/   可直接使用的配置（iptsd 参数、blocklist、refind.conf 片段）
scripts/  start-iptsd.sh / service.sh / post-fs-data.sh / refind-touch.sh / shrink-module-image.sh
docs/     每个问题的详细分析
```

## 适用版本与已验证环境

| 项目 | 值 |
|---|---|
| 设备 | Surface Pro 7+（Intel THC `045E:0C1A`） |
| 系统 | BlissOS 16.9.7（Android 13, `TQ3A.230901.001.C1`）、15.9.2（Android 12L） |
| 内核 | `6.1.112-gloria-surface-xanmod1` |
| 存储 | 内置 NVMe / 外置 USB SSD 均可 |
| Root | KernelSU 1.0.1 |

> 2025-04 之后的构建已重写 iptsd 启动逻辑（`iptsd` service + `vendor.iptsd.device`），
> 触控部分可能开箱即用，不再需要第 1 条。

## 免责声明

改 ESP、改内核命令行、改 `/data` 都属于高风险操作，操作前请务必备份。
以上内容仅在本人设备上验证，不同批次构建行为可能有差异，后果自负。

## 参考

- BlissOS Surface 构建：<https://docs.blissos.org/knowledgebase/other-bliss-variant/surface-builds/>
- iptsd（linux-surface）：<https://github.com/linux-surface/iptsd>
- Bliss 触摸相关 issue：#47 / #103 / #109 / #114
- iptsd 脚本在 Android 上不可用：<https://github.com/linux-surface/iptsd/issues/184>
- 蓝牙修复模块作者：logmilk / minimax-m3
