# 附加 03 不要用 Windows 的 ext4 工具改 `/data`

这一条是**血泪教训**，单独写出来警示。

## 事故经过

为了给平板（Android-x86 的 frugal 安装，`/data` 是独立 ext4 分区）改几个文件，
把硬盘拆下来接到 Windows，用 **Paragon LinuxFS for Windows** 挂载分区，
在资源管理器里删了 `/data/adb/ksu/modules.img` 和 `/data/vendor/modules.blocklist`。

结果：**系统永久 bootloop** —— 开机闪一下锁屏就重启/关机。

## 为什么

Windows 没有 Linux 的 uid / SELinux 概念。Paragon 这类工具把 ext4 挂载成普通盘符，
写回时：

- `/data/data/*` 所有应用目录的属主被写成 **root(0)**；
- SELinux 扩展属性（`security.selinux`）在部分目录上丢失。

开机时 PackageManager 逐个报：

```
Package com.termux was user id 0 but is now user SharedUserSetting{...};
I am not changing its files so it will probably fail!
Package com.android.systemui was user id 0 but is now ...
Package com.android.settings was user id 0 but is now ...
```

所有应用的数据目录属主都不对，`system_server` 起不来 → 反复重启。

`/data/apex/active` 被清空、`persist.sys.boot.reason = reboot,apex-failed` 也是同一个原因。

## 症状判据

如果你已经这么干过，可以这样确认：

```sh
# 挂载后看 uiderrors.txt（在 /data/system/ 下）
grep 'was user id 0' /data/system/uiderrors.txt | head
# 或者看 dropbox 里的 SYSTEM_BOOT
```

## 唯一解法

**格式化 `/data`**（个人数据先备份 `/data/media`）。改属主是做不到的——
Android 不会替你修，它只会报错。

正确姿势：

- 需要改 `/data` 就在 **Android 里用 root 改**（`su -c`、Termux、MT 管理器）；
- 必须离线改时，用 **Linux 环境**（Live USB / WSL2 + `ext4` 直通、或 `debugfs`）
  并且挂载后立刻 `restorecon`-级别的修复，风险依旧很高；
- 任何涉及 `/data` 的操作前，先备份。

## 顺带：格式化 `/data` 也要讲究

Android-x86 的 initrd 依赖 **卷标 + UUID** 找分区，所以格式化时必须保留：

```sh
mke2fs -t ext4 -b 4096 -L BlissOS -U 813ec48b-d375-499d-8bb4-0ea69d2ccabe <分区>
```

（`-L` 卷标、`-U` UUID 都要和原来一致，否则开机会找不到 data 而卡住。）
在 Windows 下可以用 Paragon 自带的 `mke2fs.exe` 生成镜像再按分区偏移写入，
但**写之前务必确认偏移**，写错位置会毁掉整块盘。
