# 06 蓝牙打不开（以及 KernelSU 模块不生效）

## 现象

BlissOS 16.9.7（Android 13）在部分机器上：

- 蓝牙开关点不动 / 打开后立刻自己关掉；
- KernelSU 里刷入的模块「开关是灰的」、刷了不生效。

16.9.6 一切正常，16.9.7 的 0911 / 1011 两个构建有这个问题。

## 根因

这两件事是**同一个原因**：内核命令行里缺了让 Android-x86 启用
`BTLINUX_HAL` 与自定义 vendor 数据的参数，导致：

- `libbt-vendor` 走不到 BlueZ/BtLinux HAL，`bluetooth@1.x` 起不来；
- 依赖 `DATA_CUSTOM` 的模块挂载/overlay 逻辑也没启用，KSU 模块看起来「刷了但没效果」。

## 修复（两步，缺一不可）

### 1. 改启动参数

在引导配置（rEFInd 的 `android.cfg`，或 GRUB 的 `android.cfg`）里，把内核参数补上：

```ini
linux $kd/kernel_a /kernel$SLOT $CMDLINE \
  stack_depot_disable=on cgroup_disable=pressure androidboot.mode=$MODE \
  syscall_hardening=off root=/dev/ram0 androidboot.slot_suffix=_a $src $@ \
  DATA_CUSTOM=1 BTLINUX_HAL=1 usbcore.autosuspend=-1
```

> 注意：网上流传的版本常写成 `usbcore.autosupend=-1`（少一个 s），
> 那样这个参数**不会生效**，正确拼写是 **`autosuspend`**。

rEFInd 的写法是在对应 `menuentry` 的 `options` 行里追加：

```ini
options "stack_depot_disable=on cgroup_disable=pressure syscall_hardening=off root=/dev/ram0 androidboot.slot_suffix=_a SRC=/android-2024-10-12 DATA_CUSTOM=1 BTLINUX_HAL=1 usbcore.autosuspend=-1"
```

改完**保存并核对首尾**：多一个字符（例如句首变成 `llinux`）就直接开不了机；漏一个引号同理。
文件必须是 UTF-8 **无 BOM**，否则 rEFInd/GRUB 会把 `menuentry` 读成乱码。

### 2. 刷入蓝牙修复模块

`blissos-intel-bt`（作者 logmilk / minimax-m3），适用于 Intel AX200 / AX201 / AX210 / 7265 等。
刷入后**重启**（不是热重载）。

本仓库不附带该模块的二进制，请从作者的发布页获取；它做的事是补上 Intel 蓝牙固件
（`ibt-*.sfi`）与 `btusb`/`btintel` 的加载顺序。

## 验证

```sh
# 蓝牙服务起来了
dumpsys bluetooth_manager | grep -i -e enabled -e state

# 固件加载成功（内核日志）
dmesg | grep -i -e bluetooth -e btintel -e firmware

# 参数确实进去了
cat /proc/cmdline | tr ' ' '\n' | grep -e BTLINUX_HAL -e DATA_CUSTOM -e autosuspend
```

`BTLINUX_HAL=1` 生效后，`/vendor/bin/hw/android.hardware.bluetooth@1.1-service.btlinux`
才能在开机时启动。

## 已知限制

- 16.9.7 的 1011 构建即使修好蓝牙，KSU 模块的开关在 UI 上**仍可能是灰的**——
  但实际卸载/挂载是生效的，用 `ls /data/adb/modules` 与 `ksud module list` 判断真实状态。
- 蓝牙打开后用一阵又自己关：多数是固件加载超时，重启一次可缓解；反复出现则换 0911 构建。
