#!/bin/bash
# deploy-firebase-fix.sh — Script para corregir Firebase connection issues
# 
# PASOS:
# 1. firebase login
# 2. ./deploy-firebase-fix.sh
# 3. flutter clean && flutter pub get
# 4. flutter install -d emulator-5554
# 5. Abrir app en el emulador

echo "=== Deploying Firestore Rules + Indexes ==="
echo ""

# Deploy only firestore rules (the corrected ones)
firebase deploy --only firestore:rules --project deliverymovile-c25ff

echo ""
echo "=== Checking Firestore Indexes ==="
firebase firestore:indexes 2>&1

echo ""
echo "=== DONE ==="
echo "Luego de esto, reinstalá la app:"
echo "  flutter clean"
echo "  flutter install -d emulator-5554"
echo ""
echo "Si el composite index sigue compilando, esperá a que termine en Firebase Console."
