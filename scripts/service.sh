#!/system/bin/sh
# 开机自愈脚本（可作为 KernelSU 模块的 service.sh）
#
# 做四件事：
#   1. 首次开机写入触控参数 90-touch.conf
#   2. 写入 modules.blocklist（音量键），缺失才写，不覆盖已有内容
#   3. NTP 强制对时（双系统时间 +8h）
#   4. 看护 iptsd：每 2 秒检查，掉了就拉起（息屏唤醒后 hidraw 会断）

MODDIR=$(cd "$(dirname "$0")" && pwd)
LOG=/data/local/tmp/iptsd-fix.log
CFG=/data/vendor/iptsd.d/90-touch.conf

log() { echo "[$(date '+%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# 等系统起来
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 120 ]; do
    sleep 2
    i=$((i+1))
done
sleep 2

# 1. 触控参数（已存在就不动，避免覆盖用户自己的调参）
if [ ! -f "$CFG" ] && [ -f "$MODDIR/config/90-touch.conf" ]; then
    mkdir -p /data/vendor/iptsd.d 2>/dev/null
    cp "$MODDIR/config/90-touch.conf" "$CFG" 2>/dev/null
    chmod 644 "$CFG" 2>/dev/null
    log "installed default config $CFG"
fi

# 2. 音量键：延后加载 soc_button_array（init 早期读取，写入后需重启才生效）
BL=/data/vendor/modules.blocklist
if [ ! -f "$BL" ]; then
    mkdir -p /data/vendor 2>/dev/null
    printf 'deferred soc_button_array\n' > "$BL" 2>/dev/null
    log "created $BL (volume keys work after next boot)"
fi

# 3. 对时：RTC 存的是 Windows 的本地时间，Android 当 UTC 读会快 8 小时
settings put global ntp_server ntp.aliyun.com 2>/dev/null
n=0
while [ "$n" -lt 3 ]; do
    settings put global auto_time 0 2>/dev/null
    sleep 1
    settings put global auto_time 1 2>/dev/null
    sleep 2
    n=$((n+1))
done
log "ntp resync requested"

# 4. iptsd 看护
while true; do
    if ! pidof iptsd >/dev/null 2>&1; then
        sh "$MODDIR/scripts/start-iptsd.sh" >> "$LOG" 2>&1
    fi
    sleep 2
done
