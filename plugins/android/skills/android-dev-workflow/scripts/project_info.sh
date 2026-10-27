#!/usr/bin/env bash
# project_info.sh — quick orientation in an Android/KMP project.
# Usage: bash project_info.sh [project-root]
# Prints: toolchain versions, SDK levels, modules, detected stack, agent context files.
set -u
ROOT="${1:-.}"
cd "$ROOT" || { echo "no such dir: $ROOT"; exit 1; }

section() { printf '\n== %s ==\n' "$1"; }
grab() { grep -rhoE "$1" $2 2>/dev/null | head -n "${3:-3}"; }

section "Project root: $(pwd)"
ls -1 | head -40

section "Gradle wrapper / AGP / Kotlin"
grab 'distributionUrl=.*' gradle/wrapper/gradle-wrapper.properties 1 | sed 's/.*gradle-/gradle-/'
if [[ -f gradle/libs.versions.toml ]]; then
  echo "-- libs.versions.toml [versions] (first 60 lines):"
  awk '/^\[versions\]/{f=1;next} /^\[/{f=0} f' gradle/libs.versions.toml | grep -E '^(agp|android|kotlin|ksp|compose|composeBom|compose-bom|hilt|koin|metro|room|room3|navigation|nav3|navigation3|okhttp|retrofit|ktor|coil|coroutines|serialization|lifecycle|datastore|work)' | head -60
else
  echo "(no version catalog) — grep build files:"
  grab 'com\.android\.(application|library)["'\'' ]+version["'\'' ]+[0-9.]+' "build.gradle.kts settings.gradle.kts" 2
  grab 'kotlin\(["'\'']android["'\'']\)|org\.jetbrains\.kotlin.*version' "build.gradle.kts settings.gradle.kts" 2
fi

section "SDK levels (compile/target/min)"
grep -rhoE '(compileSdk|targetSdk|minSdk)(Version)?\s*=?\s*[0-9]+' --include=build.gradle.kts --include=build.gradle --include=*.toml . 2>/dev/null | sort | uniq -c | sort -rn | head -12
grep -rhoE 'compileSdk\s*=\s*libs\.versions\.[a-zA-Z]+' --include=build.gradle.kts . 2>/dev/null | head -3

section "Modules (settings.gradle(.kts))"
grep -hoE 'include\s*\(?["'\''][^"'\'']+' settings.gradle.kts settings.gradle 2>/dev/null | sed -E 's/include\s*\(?["'\'']//' | tr '\n' ' '; echo
ls -d build-logic buildSrc 2>/dev/null && echo "(convention plugins present)"

section "Detected stack"
have() { grep -rqE "$1" --include=*.toml --include=build.gradle.kts --include=build.gradle . 2>/dev/null && echo "  [x] $2" || echo "  [ ] $2"; }
have 'compose-bom|compose\.bom|androidx\.compose' 'Jetpack Compose'
have 'material3' 'Material 3'
have 'navigation3' 'Navigation 3'
have 'navigation-compose|androidx\.navigation:navigation' 'Navigation 2 (legacy)'
have 'hilt' 'Hilt'
have 'io\.insert-koin|koin' 'Koin'
have 'dev\.zacsweers\.metro|metro' 'Metro'
have 'androidx\.room3|room3' 'Room 3'
have 'androidx\.room:room|room-runtime' 'Room 2'
have 'datastore' 'DataStore'
have 'retrofit' 'Retrofit'
have 'ktor-client' 'Ktor client'
have 'okhttp' 'OkHttp'
have 'kotlinx-serialization|serialization-json' 'kotlinx.serialization'
have 'moshi' 'Moshi'
have 'coil' 'Coil'
have 'work-runtime|androidx\.work' 'WorkManager'
have 'kotlin\("multiplatform"\)|kotlin-multiplatform|org\.jetbrains\.kotlin\.multiplatform' 'Kotlin Multiplatform'
have 'kapt' 'kapt (legacy — prefer KSP)'
have 'ksp' 'KSP'
have 'benchmark-macro|baselineprofile' 'Macrobenchmark / Baseline Profiles'
have 'roborazzi|paparazzi|compose\.screenshot|screenshot-validation' 'Screenshot tests'
have 'robolectric' 'Robolectric'
have 'leakcanary' 'LeakCanary'

section "Source style"
XML=$(find . -path '*/src/main/res/layout*' -name '*.xml' 2>/dev/null | wc -l | tr -d ' ')
KT=$(find . -path '*/src/main*' -name '*.kt' 2>/dev/null | wc -l | tr -d ' ')
JAVA=$(find . -path '*/src/main*' -name '*.java' 2>/dev/null | wc -l | tr -d ' ')
COMPOSABLES=$(grep -rl '@Composable' --include=*.kt . 2>/dev/null | wc -l | tr -d ' ')
echo "  XML layouts: $XML | Kotlin files: $KT | Java files: $JAVA | files with @Composable: $COMPOSABLES"

section "Agent/context files"
ls -1 AGENTS.md CLAUDE.md GEMINI.md README.md CONTRIBUTING.md .editorconfig 2>/dev/null
ls -d .claude .agents .android .github 2>/dev/null

section "Tooling available"
for t in android adb emulator java; do printf '  %-9s %s\n' "$t" "$(command -v $t || echo 'not on PATH')"; done
[[ -n "${ANDROID_HOME:-}" ]] && echo "  ANDROID_HOME=$ANDROID_HOME" || echo "  ANDROID_HOME unset (check local.properties sdk.dir)"
adb devices 2>/dev/null | tail -n +2 | grep -v '^$' | sed 's/^/  device: /'
