# Arsenal PsyTech — Android (APK)

WebView-обертка над `../arsenal_psytech.html`. Весь UI живёт в `assets/`
(Tailwind скомпилирован offline — CDN не нужен).

## Сборка (без Gradle)

Требования: JDK 17, Android SDK (platforms + build-tools).
На этой машине: `JDK_HOME=~/toolchain/jdk`, `ANDROID_SDK_ROOT=~/toolchain/android-sdk`.

```bash
./build.sh
# → build/ArsenalPsyTech.apk (подписан debug-ключом)
```

Цепочка: `aapt2 compile/link → javac → d8 → zip → zipalign → apksigner`.

## Обновление контента

1. Править источник: `../arsenal_psytech.html`
2. Перегенерировать ассеты:
   - `assets/index.html` — копия с заменой `<script src="https://cdn.tailwindcss.com">`
     на `<link rel="stylesheet" href="tailwind.css">`
   - `assets/tailwind.css` — `npx tailwindcss@3.4 -i input.css -o assets/tailwind.css --minify`
     (content = путь к `arsenal_psytech.html`)
3. `./build.sh`

## AI-чат

В `assets/index.html` строка `const apiKey = ""` — вписать Gemini API key
перед пересборкой, либо заменить на другой OpenAI-совместимый бэкенд.
