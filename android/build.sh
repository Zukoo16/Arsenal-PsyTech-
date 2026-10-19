#!/usr/bin/env bash
# Arsenal PsyTech — APK құрастыру (Gradless: aapt2 + javac + d8 + apksigner)
# Қажет: JDK 17 (javac, keytool, jar) және Android SDK (platforms + build-tools)
# AI кілті: $AI_API_KEY немесе ~/Рабочий стол/api-lab/.env (API_KEY=)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/build"

# --- Жолдар ---
JDK="${JDK_HOME:-$HOME/toolchain/jdk}"
SDK="${ANDROID_SDK_ROOT:-$HOME/toolchain/android-sdk}"
BT="$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)"
PLATFORM="$(ls -d "$SDK"/platforms/android-* | sort -V | tail -1)"
ANDROID_JAR="$PLATFORM/android.jar"

AAPT2="$BT/aapt2"
D8="$BT/d8"
ZIPALIGN="$BT/zipalign"
APKSIGNER="$BT/apksigner"

export JAVA_HOME="$JDK"
export PATH="$JDK/bin:$PATH"

echo "== JDK: $JDK"
echo "== SDK: $SDK (build-tools: $(basename "$BT"), platform: $(basename "$PLATFORM"))"

# --- 0. Ассет дайындау: source → assets (tailwind offline + API кілтін толу) ---
KEY="${AI_API_KEY:-}"
if [ -z "$KEY" ] && [ -f "$HOME/Рабочий стол/api-lab/.env" ]; then
    KEY="$(grep -E '^API_KEY=' "$HOME/Рабочий стол/api-lab/.env" | head -1 | cut -d= -f2-)"
fi
if [ -z "$KEY" ]; then
    echo "⚠️  API кілті жоқ (AI_API_KEY / .env) — чат жұмыс істемейді!"
fi
AI_KEY="$KEY" ROOT="$ROOT" python3 - <<'PYEOF'
import os
key = os.environ.get("AI_KEY", "")
root = os.environ["ROOT"]
src = open(os.path.join(root, '..', 'arsenal_psytech.html'), encoding='utf-8').read()
src = src.replace('<script src="https://cdn.tailwindcss.com"></script>',
                  '<link rel="stylesheet" href="tailwind.css">')
src = src.replace('__AI_API_KEY__', key)
open(os.path.join(root, 'assets', 'index.html'), 'w', encoding='utf-8').write(src)
print('[0/6] assets/index.html дайын (кілт:', 'бар' if key else 'жоқ', ')')
PYEOF

rm -rf "$OUT"
mkdir -p "$OUT/gen" "$OUT/classes" "$OUT/dex"

# --- 1. Ресурстарды компиляциялау ---
"$AAPT2" compile --dir "$ROOT/res" -o "$OUT/res.zip"
echo "[1/6] aapt2 compile OK"

# --- 2. APK link (manifest + R.java) ---
"$AAPT2" link \
    -o "$OUT/base.apk" \
    -I "$ANDROID_JAR" \
    --manifest "$ROOT/AndroidManifest.xml" \
    --java "$OUT/gen" \
    --min-sdk-version 21 \
    --target-sdk-version 34 \
    --version-code 1 \
    --version-name "1.0.0" \
    "$OUT/res.zip"
echo "[2/6] aapt2 link OK"

# --- 3. Java компиляция ---
javac -source 1.8 -target 1.8 \
    -bootclasspath "$ANDROID_JAR" \
    -classpath "$ANDROID_JAR" \
    -d "$OUT/classes" \
    "$ROOT"/src/com/psytech/arsenal/*.java \
    "$OUT"/gen/com/psytech/arsenal/R.java
echo "[3/6] javac OK"

# --- 4. DEX ---
"$D8" --release --lib "$ANDROID_JAR" --min-api 21 \
    --output "$OUT/dex" \
    $(find "$OUT/classes" -name '*.class')
echo "[4/6] d8 OK"

# --- 5. DEX + assets APK-ға ---
cd "$OUT/dex"
zip -q "$OUT/base.apk" classes.dex
cd "$ROOT/assets"
zip -qr "$OUT/base.apk" .
cd "$ROOT"

# --- 6. Align + Sign ---
"$ZIPALIGN" -f 4 "$OUT/base.apk" "$OUT/aligned.apk"

KEYSTORE="$ROOT/arsenal-debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
    keytool -genkeypair -v \
        -keystore "$KEYSTORE" \
        -storepass arsenal123 -keypass arsenal123 \
        -alias arsenal \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Arsenal PsyTech, OU=PsyTech, O=PsyTech, L=Almaty, C=KZ" 2>/dev/null
fi

"$APKSIGNER" sign \
    --ks "$KEYSTORE" --ks-pass pass:arsenal123 --key-pass pass:arsenal123 \
    --ks-key-alias arsenal \
    --out "$OUT/ArsenalPsyTech.apk" \
    "$OUT/aligned.apk"

"$APKSIGNER" verify --print-certs "$OUT/ArsenalPsyTech.apk" >/dev/null && echo "[5/6] sign+verify OK"
echo "[6/6] ГОТОВО: $OUT/ArsenalPsyTech.apk"
ls -lh "$OUT/ArsenalPsyTech.apk"
