@echo off
flutter build apk --split-per-abi
explorer build\app\outputs\apk\release