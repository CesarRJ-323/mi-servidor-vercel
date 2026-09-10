#!/bin/bash
# Script para escribir email y password en la app usando ADB input.
# Las credenciales se pasan por VARIABLES DE ENTORNO:
#   export TEST_ADMIN_EMAIL=...
#   export TEST_ADMIN_PASS=...
# NUNCA hardcodear credenciales en este script.
#
# El password puede tener caracteres especiales que necesitan manejo cuidadoso.

echo "=== Login automation via ADB ==="

# Leer credenciales desde variables de entorno
EMAIL="${TEST_ADMIN_EMAIL:-alegandraaraoz@gmail.com}"
PASSWORD="${TEST_ADMIN_PASS:-}"

if [ -z "$PASSWORD" ]; then
  echo "❌ ERROR: variable TEST_ADMIN_PASS no está seteada."
  echo "Setear con: export TEST_ADMIN_PASS='tu_password'"
  exit 1
fi

# Tap email field (approximately center x=540, y=540)
echo "1. Tapping email field..."
adb shell input tap 540 540
sleep 2

# Type email (split on @ and .)
echo "2. Typing email: $EMAIL"
IFS='@.' read -ra PARTS <<< "$EMAIL"
adb shell input text "${PARTS[0]}"
sleep 0.3
adb shell input text 91  # @ symbol (keycode for @)
sleep 0.3
adb shell input text "${PARTS[1]}"
sleep 0.3
adb shell input text "."
sleep 0.3
adb shell input text "${PARTS[2]}"
sleep 1

# Tap password field
echo "3. Tapping password field..."
adb shell input tap 540 660
sleep 2

# Clear any existing text first
adb shell input keyevent 123  # KEYCODE_MOVE_HOME

# Type password using a Python helper for proper special char handling
echo "4. Typing password..."
python3 -c "
import subprocess, os, time

password = os.environ.get('TEST_ADMIN_PASS', '')
for char in password:
    result = subprocess.run(['adb', 'shell', 'input', 'text', char],
                          capture_output=True, text=True)
    time.sleep(0.15)
print('Password typed successfully')
"

sleep 2

# Tap "Iniciar sesión" button
echo "5. Tapping Iniciar sesión..."
adb shell input tap 540 820
sleep 10

# Capture result
echo "6. Capturing result..."
adb shell screencap -p /sdcard/screen_after_login.png
adb pull /sdcard/screen_after_login.png "$LOCALAPPDATA/hermes/cache/images/screen_after_login.png" 2>&1

echo "=== Done ==="

# Check logs
echo "=== Logs ==="
adb logcat -d | grep -iE "login.*success|token.*received|FirebaseAuth|PERMISSION_DENIED|admin|rol|sign.in" | tail -10
