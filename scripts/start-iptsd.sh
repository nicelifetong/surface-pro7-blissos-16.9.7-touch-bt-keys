#!/system/bin/sh
# 启动 iptsd（Surface Pro 7+ / Intel THC 045E:0C1A）
#
# 背景：这批 BlissOS 构建里 /system/vendor/bin/iptsd-find-hidraw 是 bash 脚本，
# Android 的 sh 跑不了，导致 iptsd_runner 以 106 退出，触屏退化成「触控板」。
# 这里绕过它，自己找 hidraw 并拉起 iptsd。
#
# 用法： su -c 'sh start-iptsd.sh'
#        su -c 'sh start-iptsd.sh restart'

LOG=/data/local/tmp/iptsd-fix.log
DEVFILE=/data/local/tmp/iptsd.dev

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# 暂停标记：存在则跳过（做校准等操作时可临时 touch 这个文件）
[ -f /data/local/tmp/iptsd.pause ] && exit 0

# 找 iptsd
IPTSD=""
for p in /system/vendor/bin/iptsd /vendor/bin/iptsd /system/bin/iptsd; do
    [ -x "$p" ] && IPTSD="$p" && break
done
CHECK=""
for p in /system/vendor/bin/iptsd-check-device /vendor/bin/iptsd-check-device; do
    [ -x "$p" ] && CHECK="$p" && break
done
[ -z "$IPTSD" ] && { log "iptsd not found"; exit 1; }

# 已经在跑就不重复启动
if pidof iptsd >/dev/null 2>&1; then
    [ "$1" = "restart" ] || exit 0
    killall -9 iptsd 2>/dev/null
    sleep 1
fi

# 上次成功的设备优先
DEV=""
if [ -f "$DEVFILE" ]; then
    d=$(cat "$DEVFILE" 2>/dev/null)
    [ -c "$d" ] && DEV="$d"
fi

# 没有记录就逐个试探
if [ -z "$DEV" ]; then
    for h in /dev/hidraw0 /dev/hidraw1 /dev/hidraw2 /dev/hidraw3 /dev/hidraw4 /dev/hidraw5; do
        [ -c "$h" ] || continue
        if [ -n "$CHECK" ]; then
            "$CHECK" --quiet --type=any "$h" 2>/dev/null || continue
        fi
        DEV="$h"
        break
    done
fi

[ -z "$DEV" ] && { log "no IPTS hidraw found"; exit 1; }
echo "$DEV" > "$DEVFILE"

"$IPTSD" "$DEV" >> "$LOG" 2>&1 &
sleep 2

# 健康检查：虚拟触摸屏是否存在
if dumpsys input 2>/dev/null | grep -q 'IPTSD Virtual Touchscreen'; then
    log "iptsd running on $DEV (pid $(pidof iptsd))"
else
    log "iptsd started on $DEV but virtual device missing"
fi
