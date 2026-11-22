#!/system/bin/sh
# 让 rEFInd 菜单支持触摸，并且不再卡在 "Hit any key to continue"
#
# 用法：
#   su -c 'sh refind-touch.sh [timeout秒]'
#
# 需要把 FydeOS 0.14.1 的 refind_x64.efi 放在脚本同目录（或设置 REFIND_NEW 环境变量）。
# 获取方式见 docs/08-rEFInd触摸与无键盘启动.md。
#
# 脚本会：按内容找 ESP → 备份 → 替换 efi → 写配置 → sync

SECS="${1:-8}"
NEW="${REFIND_NEW:-$(dirname "$0")/refind_x64.efi}"

[ -f "$NEW" ] || { echo "缺少 refind_x64.efi（0.14.1-fydeos），请放在 $NEW"; exit 1; }

# 按「存在 EFI/refind/refind_x64.efi」找 ESP，不依赖卷标
ESP=""
for d in /dev/block/nvme0n1p1 /dev/block/nvme0n1p2 /dev/block/nvme0n1p3 \
         /dev/block/nvme0n1p4 /dev/block/nvme0n1p5 \
         /dev/block/sda1 /dev/block/sdb1 /dev/block/sdc1 /dev/block/sdd1; do
    [ -b "$d" ] || continue
    mkdir -p /mnt/esp_probe
    mount -t vfat "$d" /mnt/esp_probe 2>/dev/null || continue
    if [ -f /mnt/esp_probe/EFI/refind/refind_x64.efi ]; then
        ESP="$d"
        umount /mnt/esp_probe 2>/dev/null
        break
    fi
    umount /mnt/esp_probe 2>/dev/null
done
[ -z "$ESP" ] && { echo "没找到带 rEFInd 的 ESP"; exit 1; }
echo "ESP: $ESP"

mkdir -p /mnt/esp
mount -t vfat "$ESP" /mnt/esp 2>/dev/null || { echo "挂载失败"; exit 1; }
R=/mnt/esp/EFI/refind

cp "$R/refind_x64.efi" "$R/refind_x64.efi.bak" 2>/dev/null
cp "$NEW" "$R/refind_x64.efi"

F="$R/refind.conf"
cp "$F" "$F.bak" 2>/dev/null
sed -i "s/^timeout .*/timeout $SECS/" "$F"
sed -i '/^enable_touch/d; /^scanfor /d; /^dont_scan_firmware/d; /^dont_scan_volumes/d' "$F"
sed -i '/^use_nvram/a enable_touch' "$F"
sed -i '/^use_nvram/a scanfor manual,firmware' "$F"
sed -i '/^scanfor /a dont_scan_firmware rEFInd' "$F"
sync

echo "== 已应用 =="
grep -E '^timeout|^use_nvram|^enable_touch|^scanfor|^dont_scan' "$F"
ls -l "$R/refind_x64.efi"
umount /mnt/esp
echo "重启后测试触摸；回退：把 .bak 改回原名"
