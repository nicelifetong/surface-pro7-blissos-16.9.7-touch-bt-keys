# 08 rEFInd 菜单触摸 + 无键盘也能开机

## 现象

- rEFInd 启动菜单**点不动**（Surface 没键盘时根本没法选系统）；
- 有时菜单上方报错，然后卡在 `* Hit any key to continue *`，
  没接键盘 = 直接卡死开不了机。

```
Error: No mapping while scanning the EFI directory on SYSTEM
* Hit any key to continue *
```

## 根因（两个独立问题）

### 1. 触摸

rEFInd 0.14.0 自带的触摸支持在 Surface 上**不工作**，即使 `enable_touch` 打开也没反应。
FydeOS 定制的 0.14.1 构建修过这块（NEWS: *Fixes to touch/tablet support to improve reliability*），
换上去立即可用。

### 2. 卡在 Hit any key

rEFInd 默认会扫描**每个卷**的 `EFI` 目录。这块盘上除了启动用的 ESP，
还有 Windows 的 ESP（卷标 `SYSTEM`），扫描它时出现映射错误 → 提示按键继续。

（用 `dont_scan_volumes SYSTEM` 能消掉报错，但 Windows 项也会一起消失，不可取。）

## 修复

```sh
su -c 'sh /data/local/tmp/refind-touch.sh 8'
```

脚本会：

1. 按内容（`EFI/refind/refind_x64.efi` 存在）找 ESP，**不依赖卷标**
   ——有些机器 ESP 没有 label，按 `LABEL="ESP"` 找不到；
2. 备份原 `refind_x64.efi` → `.bak`、`refind.conf` → `.bak`；
3. 换成 FydeOS 0.14.1 的 `refind_x64.efi`（335,912 字节）；
4. 写入配置：

```ini
timeout 8
use_nvram false
scanfor manual,firmware
dont_scan_firmware rEFInd
enable_touch
```

关键在 **`scanfor manual,firmware`**：
不扫任何卷的 EFI 目录，只扫固件 NVRAM 条目。这样

- 不会再出现 `No mapping ... SYSTEM`，也就不会卡按键；
- Windows 仍然通过固件的 `Windows Boot Manager` 条目出现在菜单里（不依赖扫盘）。

## 验证

重启后：

- 菜单可以用手指点选；
- 8 秒自动进默认系统；
- 没有 `No mapping` 提示，不需要任何按键；
- Windows 项仍在（走固件条目）。

## 注意

- 换盘重装后 ESP 会变回 rEFInd 0.14.0，需要再跑一次脚本。
- 改 ESP 前脚本已自动备份 `.bak`；想回退就把 `.bak` 改回原名。
- `timeout` 传 0 表示不停留直接进默认项，传 `-1` 才是永久等待。
