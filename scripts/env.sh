#!/usr/bin/env bash

if [ -z "${PROJECT_ROOT:-}" ]; then
  PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
export FLUTTER_ROOT="$PROJECT_ROOT/.toolchains/flutter"
export JAVA_HOME="$PROJECT_ROOT/.toolchains/jdk-17"
export GRADLE_USER_HOME="$PROJECT_ROOT/.toolchains/gradle-home"
export ANDROID_HOME="$PROJECT_ROOT/.toolchains/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$FLUTTER_ROOT/bin:$FLUTTER_ROOT/bin/cache/dart-sdk/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
