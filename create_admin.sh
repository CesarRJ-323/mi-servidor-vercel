#!/bin/bash
# Script para crear el usuario admin y verificar la app
# Evita el problema de App Check debug tokens cambiantes

# Step 1: Build the test app (uses the same debug token as the running app)
echo "=== Building test app ==="
flutter build apk --debug 2>&1 | tail -3

# Step 2: Install the app (uses the same token since no pm clear)
echo "=== Installing app ==="
adb install -r build/app/outputs/flutter-apk/app-debug.apk 2>&1

# Step 3: Start the app and get the current token
echo "=== Getting current debug token ==="
adb logcat -c
adb shell am start -n com.cesar.delivery_app/.MainActivity 2>&1
sleep 8
TOKEN=$(adb logcat -d | grep "Firebase App Check debug token" | tail -1 | sed 's/.*: //')
echo "Current token: $TOKEN"
echo "=== REGISTER THIS TOKEN IN FIREBASE CONSOLE ==="
echo "Go to: https://console.firebase.google.com/project/deliverymovile-c25ff/appcheck"

# Step 4: Run the admin creation test
echo "=== Creating admin user ==="
# Use the token from the environment or pass as dart-define
flutter test integration_test/create_admin_test.dart -d emulator-5554 2>&1

# Step 5: Verify
echo "=== Verification ==="
flutter test integration_test/firebase_connectivity_test.dart -d emulator-5554 2>&1