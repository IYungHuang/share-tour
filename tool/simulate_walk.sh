#!/usr/bin/env bash
# 對 Android 模擬器注入一條步行路徑，用於在室內驗證 GPS 追蹤。
#
# 室內收不到有意義的定位，而 DoD 要求「步行 500 公尺」的實測。模擬器的
# geo fix 走的是模擬的 GPS 硬體而非 mock provider，所以會經過與真機完全
# 相同的那條管線——這不是繞過測試，是讓它可重複。
#
# 用法：tool/simulate_walk.sh [公尺數] [每筆間隔秒] [公尺/秒] [起始緯度] [起始經度]
#
# 注意：變數後面若直接接全形標點，必須寫成 ${VAR}——bash 會把全形字元
# 當成變數名的一部分而報 unbound variable。
set -euo pipefail

ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
EMU="${EMU:-}"
if [ -z "$EMU" ]; then EMU=$("$ADB" devices | grep emulator | awk "{print \$1}" | head -1); fi
METERS="${1:-500}"
INTERVAL="${2:-1}"
SPEED="${3:-1.39}"      # 公尺/秒。1.39 = 步行 5 km/h
LAT="${4:-25.0340}"     # 台北 101
LNG="${5:-121.5640}"

STEP_M=$(python3 -c "print($SPEED * $INTERVAL)")
STEPS=$(python3 -c "print(int($METERS / $STEP_M))")

echo "注入 ${METERS} 公尺步行路徑：${STEPS} 筆，每筆 ${INTERVAL} 秒（約 ${STEP_M} 公尺/筆）"
echo "裝置 ${EMU}，起點 (${LAT}, ${LNG}) 往北"

for i in $(seq 0 "$STEPS"); do
  CUR_LAT=$(python3 -c "print(f'{$LAT + $i * $STEP_M / 110574.0:.7f}')")
  "$ADB" -s "$EMU" emu geo fix "$LNG" "$CUR_LAT" > /dev/null
  printf "\r  %d/%d  lat=%s" "$i" "$STEPS" "$CUR_LAT"
  sleep "$INTERVAL"
done
echo ""
echo "完成。預期 HUD 的 REAL 約增加 ${METERS} 公尺（±20%）。"
