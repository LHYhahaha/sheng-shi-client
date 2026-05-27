#!/usr/bin/env bash
# 真机录屏：只测两个播放器 PageView
#   1) For You  tab -> PlayerPage.forYou 纵向切条
#   2) 首页进剧 -> PlayerPage 单剧纵向切集
# 不滑动首页卡片网格。
set -euo pipefail

ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
DEVICE="${DEVICE:-}"
PKG="com.yushi.drama.client"
ACTIVITY="${PKG}/.MainActivity"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/artifacts/manual_device_scroll"
mkdir -p "$OUT_DIR"

if [[ -z "$DEVICE" ]]; then
  DEVICE="$("$ADB" devices | awk 'NR>1 && $2=="device"{print $1; exit}')"
fi
if [[ -z "$DEVICE" ]]; then
  echo "No Android device connected." >&2
  exit 1
fi

ADB_DEVICE=("$ADB" -s "$DEVICE")
echo "Using device: $DEVICE"

SIZE="$("${ADB_DEVICE[@]}" shell wm size | tr -d '\r' | awk '{print $3}')"
WIDTH="${SIZE%x*}"
HEIGHT="${SIZE#*x}"
CENTER_X=$((WIDTH / 2))
# 真机 uiautomator 实测坐标（1080x2408, SM A145F）：
# Home [42,2093][245,2273], For you [307,2093][509,2273]
HOME_X=143
FOR_YOU_X=408
MY_LIST_X=672
PROFILE_X=936
NAV_Y=2183
# 播放器纵向滑动区域（避开底部 tab / 顶部状态栏）
SWIPE_X=$CENTER_X
SWIPE_UP_START_Y=$((HEIGHT * 72 / 100))
SWIPE_UP_END_Y=$((HEIGHT * 28 / 100))
# 首页第一张剧卡片（竖版海报，大致在首屏左侧中上）
HOME_CARD_X=$((WIDTH / 4))
HOME_CARD_Y=$((HEIGHT * 38 / 100))

echo "Screen ${WIDTH}x${HEIGHT}"
echo "  nav home=(${HOME_X},${NAV_Y}) forYou=(${FOR_YOU_X},${NAV_Y}) myList=(${MY_LIST_X},${NAV_Y})"
echo "  player swipe vertical x=${SWIPE_X} y=${SWIPE_UP_START_Y}->${SWIPE_UP_END_Y}"
echo "  home drama card tap=(${HOME_CARD_X},${HOME_CARD_Y})"

cd "$ROOT_DIR"
echo "Installing debug APK..."
flutter install -d "$DEVICE" >/dev/null

RECORD_PATH="/sdcard/drama_player_scroll_$(date +%s).mp4"
LOCAL_MP4="${OUT_DIR}/player_and_foryou_$(date +%Y%m%d_%H%M%S).mp4"
LOG_FILE="${OUT_DIR}/player_and_foryou.log"

player_swipe_rounds() {
  local label="$1"
  local rounds="${2:-6}"
  echo "--- ${label}: ${rounds} rounds up/down ---"
  for round in $(seq 1 "$rounds"); do
    echo "  ${label} round ${round}: next (swipe up)"
    "${ADB_DEVICE[@]}" shell input swipe "$SWIPE_X" "$SWIPE_UP_START_Y" "$SWIPE_X" "$SWIPE_UP_END_Y" 340
    sleep 2.0
    echo "  ${label} round ${round}: previous (swipe down)"
    "${ADB_DEVICE[@]}" shell input swipe "$SWIPE_X" "$SWIPE_UP_END_Y" "$SWIPE_X" "$SWIPE_UP_START_Y" 340
    sleep 2.0
  done
  echo "  ${label}: fast flings"
  for _ in 1 2 3; do
    "${ADB_DEVICE[@]}" shell input swipe "$SWIPE_X" "$SWIPE_UP_START_Y" "$SWIPE_X" "$((SWIPE_UP_END_Y + 80))" 200
    sleep 1.4
  done
  sleep 1
}

{
  echo "=== player + for-you scroll test $(date -Iseconds) ==="

  "${ADB_DEVICE[@]}" shell input keyevent KEYCODE_WAKEUP
  "${ADB_DEVICE[@]}" shell am force-stop "$PKG"
  sleep 1
  "${ADB_DEVICE[@]}" shell rm -f "$RECORD_PATH"
  "${ADB_DEVICE[@]}" shell screenrecord --time-limit 120 "$RECORD_PATH" &
  RECORD_PID=$!
  sleep 1

  echo "Launch app"
  "${ADB_DEVICE[@]}" shell am start -n "$ACTIVITY" -W
  sleep 4

  echo "=== A: For You 播放器 (PlayerPage.forYou) ==="
  echo "Tap For You tab (PlayerPage.forYou)"
  "${ADB_DEVICE[@]}" shell input tap "$FOR_YOU_X" "$NAV_Y"
  sleep 5
  player_swipe_rounds "for_you_player" 6

  echo "=== B: 单剧播放器 (Home -> 进剧 -> PlayerPage) ==="
  echo "Tap Home tab"
  "${ADB_DEVICE[@]}" shell input tap "$HOME_X" "$NAV_Y"
  sleep 2
  echo "Tap first drama card to open player"
  "${ADB_DEVICE[@]}" shell input tap "$HOME_CARD_X" "$HOME_CARD_Y"
  sleep 4
  player_swipe_rounds "single_drama_player" 6

  echo "Back from player (system back)"
  "${ADB_DEVICE[@]}" shell input keyevent KEYCODE_BACK
  sleep 2

  sleep 2
  "${ADB_DEVICE[@]}" shell pkill -2 screenrecord 2>/dev/null || true
  wait "$RECORD_PID" 2>/dev/null || true
  sleep 2
  "${ADB_DEVICE[@]}" pull "$RECORD_PATH" "$LOCAL_MP4"
  "${ADB_DEVICE[@]}" shell rm -f "$RECORD_PATH"
  echo "Recording: $LOCAL_MP4"
} 2>&1 | tee "$LOG_FILE"

if command -v ffmpeg >/dev/null 2>&1; then
  FRAME_DIR="${OUT_DIR}/frames_$(basename "$LOCAL_MP4" .mp4)"
  mkdir -p "$FRAME_DIR"
  # For You 段约 0-50s，单剧段约 50-110s（按脚本节奏估）
  for sec in 8 16 24 32 40 48 56 64 72 80 88 96; do
    ffmpeg -y -ss "00:00:${sec}" -i "$LOCAL_MP4" -vframes 1 -update 1 \
      "${FRAME_DIR}/t${sec}s.jpg" 2>/dev/null || true
  done
  echo "Frames: $FRAME_DIR"
fi

echo "Done."
