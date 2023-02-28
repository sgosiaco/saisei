@echo off
flutter build apk --split-per-abi --release
explorer .\build\app\outputs\flutter-apk