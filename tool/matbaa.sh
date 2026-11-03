#!/bin/zsh
# Matbaa Mac uygulamasını derler ve açar (telefon uygulaması değil: hedef lib/main_matbaa.dart).
# Kullanım (proje klasöründen):  ./tool/matbaa.sh
# İlk derleme birkaç dakika sürer; sonrakiler hızlıdır.
set -e
cd "$(dirname "$0")/.."
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8   # CocoaPods UTF-8 ister
pkill -f "Anilarin Matbaa.app" 2>/dev/null || true
flutter build macos --debug -t lib/main_matbaa.dart
open "build/macos/Build/Products/Debug/Anilarin Matbaa.app"
