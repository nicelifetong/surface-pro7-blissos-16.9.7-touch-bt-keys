#!/system/bin/sh
# post-fs-data 阶段关闭 Launcher3 的「双击休眠」手势
# 目的：解决「摸着摸着突然息屏」——该手势在连续点击时被误判

LOG=/data/local/tmp/iptsd-fix.log
LP=/data/data/com.android.launcher3/shared_prefs/com.android.launcher3.prefs.xml

log() { echo "[$(date '+%m-%d %H:%M:%S')] post-fs-data: $*" >> "$LOG"; }

[ -f "$LP" ] || exit 0

if grep -q 'name="pref_sleep_gesture"' "$LP"; then
    sed -i 's/name="pref_sleep_gesture" value="true"/name="pref_sleep_gesture" value="false"/' "$LP"
else
    sed -i 's#</map>#    <boolean name="pref_sleep_gesture" value="false" />\n</map>#' "$LP"
fi

# 改回去权限，否则桌面读不到
OWNER=$(stat -c '%u:%g' /data/data/com.android.launcher3 2>/dev/null)
[ -n "$OWNER" ] && chown "$OWNER" "$LP" 2>/dev/null
chmod 660 "$LP" 2>/dev/null
log "pref_sleep_gesture=false applied"
