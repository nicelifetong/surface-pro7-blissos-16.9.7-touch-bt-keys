#!/system/bin/sh
# 把 KernelSU 的 modules.img 从 1 TiB 缩到 4 GiB
# 解决「存储显示 2TB / 已用 95%」（两个挂载点各算一份 0.9T 表观容量）
#
# 用法： su -c 'sh shrink-module-image.sh'
# 完成后重启，再删旧镜像： rm -f /data/adb/ksu/modules.img.old
#
# 不能用 `ksud module shrink`：它先跑 e2fsck -f，而镜像正被挂载使用会失败。

set -e
IMG=/data/adb/ksu/modules.img
NEW=/data/adb/ksu/modules-new.img
BAK=/data/local/tmp/ksu_backup

echo "== 当前 =="
ls -ls "$IMG"
df -h /system

echo "== 备份模块到 $BAK =="
rm -rf "$BAK"
mkdir -p "$BAK" /mnt/ksu_backup
mount -o ro,loop "$IMG" /mnt/ksu_backup 2>/dev/null || { echo "挂载现有镜像失败"; exit 1; }
cp -a /mnt/ksu_backup/. "$BAK"/ 2>/dev/null || true
umount /mnt/ksu_backup
echo "备份条目: $(ls -A "$BAK" | wc -l)"

echo "== 新建 4GiB 镜像 =="
rm -f "$NEW"
dd if=/dev/zero of="$NEW" bs=1M count=4096 2>/dev/null
mke2fs -t ext4 -F -b 4096 -m 0 "$NEW" >/dev/null 2>&1

echo "== 拷回模块 =="
mkdir -p /mnt/ksu_new
mount -o loop "$NEW" /mnt/ksu_new
cp -a "$BAK"/. /mnt/ksu_new/ 2>/dev/null || true
sync
umount /mnt/ksu_new

echo "== 替换 =="
mv "$IMG" "$IMG.old"
mv "$NEW" "$IMG"
chmod 600 "$IMG"
ls -ls "$IMG"

echo
echo "完成。现在重启，起来后执行："
echo "  rm -f /data/adb/ksu/modules.img.old"
echo "  df -h /system     # 应显示 3.8G"
