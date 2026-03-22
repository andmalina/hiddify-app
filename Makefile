# --- Конфигурация и переменные ---
include dependencies.properties

# Лог-хелперы (цвета)
BLUE   := \033[1;34m
GREEN  := \033[1;92m
YELLOW := \033[1;33m
RESET  := \033[0m

# Основные команды
FLUTTER := flutter
DART    := dart
MKDIR   := mkdir -p
RM      := rm -rf

# Пути (используем универсальный слеш для CI)
DIST_DIR     := dist
ANDROID_OUT  := android/app/libs
IOS_OUT      := ios/Frameworks
DESKTOP_OUT  := hiddify-core/bin
GEO_ASSETS   := assets/core

# Настройка SED (для кроссплатформенной правки файлов)
ifeq ($(OS),Windows_NT)
    SED := sed -i
else ifeq ($(shell uname),Darwin)
    SED := sed -i ''
else
    SED := sed -i
endif

# Логика выбора ядра (Core) и таргета
ifeq ($(CHANNEL),prod)
    CORE_URL := https://github.com/hiddify/hiddify-next-core/releases/download/v$(core.version)
    TARGET   := lib/main_prod.dart
else
    CORE_URL := https://github.com/hiddify/hiddify-next-core/releases/download/draft
    TARGET   := lib/main.dart
endif

SENTRY_ARGS := --build-dart-define sentry_dsn=$(SENTRY_DSN)

.PHONY: all clean get gen translate prepare protos libs build-all

# --- 1. Базовые операции (Prepare) ---

clean:
	@echo "$(YELLOW)🧹 Полная очистка проекта...$(RESET)"
	$(RM) $(DIST_DIR)
	$(FLUTTER) clean

get:
	@echo "$(BLUE)📦 Загрузка зависимостей Flutter...$(RESET)"
	$(FLUTTER) pub get

gen:
	@echo "$(BLUE)🛠 Генерация кода (build_runner)...$(RESET)"
	$(DART) run build_runner build --delete-conflicting-outputs

translate:
	@echo "$(BLUE)🌐 Синхронизация локализации...$(RESET)"
	$(DART) run slang

common-prepare: get gen translate

# --- 2. Работа с ядрами (Core Libs) ---

android-libs:
	@echo "$(BLUE)🤖 Загрузка Android Core...$(RESET)"
	$(MKDIR) $(ANDROID_OUT)
	curl -L $(CORE_URL)/hiddify-lib-android.tar.gz | tar xz -C $(ANDROID_OUT)/

windows-libs:
	@echo "$(BLUE)🪟 Загрузка Windows Core...$(RESET)"
	$(MKDIR) $(DESKTOP_OUT)
	curl -L $(CORE_URL)/hiddify-lib-windows-amd64.tar.gz | tar xz -C $(DESKTOP_OUT)/

macos-libs:
	@echo "$(BLUE)🍎 Загрузка macOS Core...$(RESET)"
	$(MKDIR) $(DESKTOP_OUT)
	curl -L $(CORE_URL)/hiddify-lib-macos.tar.gz | tar xz -C $(DESKTOP_OUT)/

ios-libs:
	@echo "$(BLUE)📱 Загрузка iOS Core...$(RESET)"
	$(MKDIR) $(IOS_OUT)
	$(RM) $(IOS_OUT)/HiddifyCore.xcframework
	curl -L $(CORE_URL)/hiddify-lib-ios.tar.gz | tar xz -C $(IOS_OUT)/

# --- 3. Сборка (Release) ---

android-apk-release: common-prepare android-libs
	@echo "$(GREEN)🚀 Сборка Android APK...$(RESET)"
	fastforge package --platform android --targets apk --skip-clean --build-target=$(TARGET) $(SENTRY_ARGS)
	$(MKDIR) $(DIST_DIR)
	cp -r build/app/outputs/flutter-apk/*.apk $(DIST_DIR)/
	@echo "$(GREEN)✅ Готово: $(DIST_DIR)/$(RESET)"

windows-release: common-prepare windows-libs
	@echo "$(GREEN)🚀 Сборка Windows EXE...$(RESET)"
	fastforge package --platform windows --targets exe --skip-clean --build-target=$(TARGET) $(SENTRY_ARGS)
	$(MKDIR) $(DIST_DIR)
	# Копируем бинарники из dist (fastforge) или build
	cp -r build/windows/x64/runner/Release/* $(DIST_DIR)/ 2>/dev/null || cp -r dist/windows/* $(DIST_DIR)/
	@echo "$(GREEN)✅ Готово: $(DIST_DIR)/$(RESET)"

macos-release: common-prepare macos-libs
	@echo "$(GREEN)🚀 Сборка macOS DMG...$(RESET)"
	fastforge package --platform macos --targets dmg --skip-clean --build-target=$(TARGET) $(SENTRY_ARGS)
	$(MKDIR) $(DIST_DIR)
	cp -r dist/macos/*.dmg $(DIST_DIR)/ 2>/dev/null || true
	@echo "$(GREEN)✅ Готово$(RESET)"

linux-release: common-prepare
	@echo "$(GREEN)🚀 Сборка Linux AppImage...$(RESET)"
	fastforge package --platform linux --targets appimage --skip-clean --build-target=$(TARGET) $(SENTRY_ARGS)
	$(MKDIR) $(DIST_DIR)
	cp -r dist/linux/*.AppImage $(DIST_DIR)/ 2>/dev/null || true

# --- 4. Протоколы и утилиты ---

protos:
	@echo "$(BLUE)🧬 Генерация Protobuf...$(RESET)"
	$(MKDIR) lib/hiddifycore/generated
	protoc --dart_out=grpc:lib/hiddifycore/generated --proto_path=hiddify-core/ \
	$$(find hiddify-core/v2 hiddify-core/extension -name "*.proto") google/protobuf/timestamp.proto
	@echo "$(GREEN)✅ Протоколы обновлены$(RESET)"

# Установка инструментов (локально)
install-tools:
	$(DART) pub global activate fastforge
	$(DART) pub global activate protoc_plugin

# Универсальная команда для проверки всего билда
build-all: clean android-apk-release windows-release macos-release