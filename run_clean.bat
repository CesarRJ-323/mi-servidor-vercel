@echo off
REM ============================================================
REM  run_clean.bat - Ejecuta la app SIEMPRE desde cero (sin APK viejo)
REM  Uso: poner este archivo en la carpeta del proyecto y darle doble clic
REM  (requiere tener el emulador abierto y el Flutter SDK en el PATH).
REM
REM  Credenciales via --dart-define (NUNCA hardcodear).
REM  Setear en environment variables TEST_ADMIN_EMAIL / TEST_ADMIN_PASS.
REM ============================================================
SETLOCAL
SET EMU=emulator-5554
SET PKG=com.cesar.delivery_app
SET ADB=C:\Users\lia\AppData\Local\Android\Sdk\platform-tools\adb.exe
SET FLUTTER=C:\Users\lia\OneDrive\Desktop\flutter_windows_3.47.2-stable\bin\flutter.bat

echo [1/4] Deteniendo la app si esta corriendo...
"%ADB%" -s %EMU% shell am force-stop %PKG% 2>nul

echo [2/4] Desinstalando la app vieja (si existe)...
"%ADB%" uninstall %PKG% 2>nul

echo [3/4] Esperando emulador...
"%ADB%" wait-for-device

echo [4/4] Compilando e instalando la app NUEVA...
"%FLUTTER%" run -d %EMU% --no-enable-impeller ^
  --dart-define=TEST_ADMIN_EMAIL=%TEST_ADMIN_EMAIL% ^
  --dart-define=TEST_ADMIN_PASS=%TEST_ADMIN_PASS% ^
  --dart-define=TEST_CLIENTE_EMAIL=%TEST_CLIENTE_EMAIL% ^
  --dart-define=TEST_CLIENTE_PASS=%TEST_CLIENTE_PASS%

echo Listo. La app corre con el codigo actual (sin versiones viejas).
ENDLOCAL
