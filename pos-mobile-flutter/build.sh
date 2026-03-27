#!/bin/bash
VERSION=$(cat version.txt)
flutter build apk --target-platform android-arm64 --split-per-abi  
mv build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
   build/app/outputs/flutter-apk/admin-pos-v$VERSION.apk