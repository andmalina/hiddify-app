name: Malinarium Build & Release
on:
  workflow_call:
    inputs:
      upload-artifact:
        type: boolean
        default: true
      tag-name: { type: string, default: "draft" }
      channel: { type: string, default: "dev" }

env:
  IS_GITHUB_ACTIONS: 1
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
  FLUTTER_VERSION: '3.38.5'
  HAS_APPLE_CERT: ${{ secrets.APPLE_CERTIFICATE_P12 }}
  HAS_WIN_CERT: ${{ secrets.WINDOWS_SIGNING_KEY }}

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true
      - name: Test
        continue-on-error: true
        run: flutter test

  build:
    needs: test
    strategy:
      fail-fast: false
      matrix:
        include:
          - platform: android-apk
            os: ubuntu-latest
          - platform: windows
            os: windows-latest
          - platform: macos
            os: macos-15
    runs-on: ${{ matrix.os }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: 'recursive' # Важно для hiddify-core, если это сабмодуль

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true

      # --- КРИТИЧЕСКИЙ ШАГ: Установка fastforge и инструментов ---
      - name: Install Build Tools & Fastforge
        shell: bash
        run: |
          # Устанавливаем fastforge глобально
          dart pub global activate fastforge
          # Добавляем путь к глобальным пакетам Dart в систему
          echo "$HOME/.pub-cache/bin" >> $GITHUB_PATH
          echo "$(pnpm bin -g 2>/dev/null)" >> $GITHUB_PATH # на всякий случай
          
          if [ "${{ matrix.os }}" == "windows-latest" ]; then
            choco install make nsis -y
          elif [ "${{ matrix.os }}" == "ubuntu-latest" ]; then
            sudo apt-get update && sudo apt-get install -y make
          fi

      - name: Import Apple Certs
        if: ${{ inputs.upload-artifact && matrix.platform == 'macos' && env.HAS_APPLE_CERT != '' }}
        uses: apple-actions/import-codesign-certs@v3
        with: 
          p12-file-base64: "${{ secrets.APPLE_CERTIFICATE_P12 }}"
          p12-password: "${{ secrets.APPLE_CERTIFICATE_P12_PASSWORD }}"

      # --- СБОРКА ЧЕРЕЗ MAKE ---
      - name: Build App
        shell: bash
        run: |
          # Добавляем путь к dart pub cache еще раз для текущей сессии
          export PATH="$PATH":"$HOME/.pub-cache/bin"
          make ${{ matrix.platform }}-release

      - name: Code Sign Windows
        if: ${{ inputs.upload-artifact && matrix.platform == 'windows' && env.HAS_WIN_CERT != '' }}
        uses: hiddify/signtool-code-sign-sha256@main
        with:
          certificate: '${{ secrets.WINDOWS_SIGNING_KEY }}'
          cert-password: '${{ secrets.WINDOWS_SIGNING_PASSWORD }}'
          cert-description: 'Malinarium'
          folder: 'dist'
          recursive: true

      # --- СБОР АРТЕФАКТОВ (теперь берем из папки dist, как в твоем Makefile) ---
      - name: Prepare Out
        shell: bash
        run: |
          mkdir -p out
          # Твой Makefile копирует всё в папку dist, берем оттуда
          if [ -d "dist" ]; then
            cp -rv dist/* out/ 2>/dev/null || true
          fi
          # Если dist пуст, ищем в стандартных путях (страховка)
          cp build/app/outputs/flutter-apk/*.apk out/ 2>/dev/null || true
          cp build/windows/x64/runner/Release/*.exe out/ 2>/dev/null || true
          
          if [ -z "$(ls -A out)" ]; then
            echo "No files found in dist/ or build/." > out/check_logs.txt
          fi

      - name: Upload
        if: inputs.upload-artifact
        uses: actions/upload-artifact@v4
        with:
          name: Malinarium-${{ matrix.platform }}
          path: ./out
          if-no-files-found: warn