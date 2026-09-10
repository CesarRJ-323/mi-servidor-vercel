# Setup de Firebase — Delivery App V2

Guía paso a paso. La capa de código ya está escrita en `lib/`. Esto es lo que vos
tenés que hacer en Firebase Console + tu máquina para que compile y corra.

---

## 1. Crear el proyecto en Firebase Console

1. Ir a https://console.firebase.google.com/
2. "Add project" → nombre: `delivery-app-v2` (el que quieras)
3. Google Analytics: opcional (recomendado para ver retención)
4. Crear proyecto

## 2. Registrar la app Android

1. En el panel del proyecto → ícono de Android ( "Add app" > Android )
2. Package name: **`com.cesar.delivery_app_v2`**
   (es el `applicationId` de `android/app/build.gradle.kts` / `build.gradle`)
3. Nickname: `delivery_app_v2`
4. SHA-1 de debug (necesario para Auth):
   ```cmd
   cd C:\Users\lia\Desktop\delivery_app_v2
   keytool -list -v -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore -storepass android -keypass android
   ```
   Copiás el SHA1 (y SHA256) y lo pegás.
5. Descargar **google-services.json** y colocarlo en:
   `android/app/google-services.json`  (NO en la raíz)
6. Firebase te pide editar `android/build.gradle` y `android/app/build.gradle`.
   Con Flutter 3.47 + Gradle moderno ya está casi listo; verifica que en
   `android/app/build.gradle.kts` (o .gradle) haya:
   ```gradle
   apply plugin: "com.google.gms.google-services"
   ```
   y en `android/build.gradle.kts` los repos y el classpath del google-services.

## 3. Habilitar Authentication

1. Build > Authentication > Get started
2. Sign-in method > Email/Password > **Enable** > Save

## 4. Crear la base de Cloud Firestore

1. Build > Firestore Database > Create database
2. Modo producción (las reglas las reemplazamos con las de `firestore.rules`)
3. Región: la más cercana (ej. `southamerica-east1` São Paulo)
4. Crear
5. En la pestaña "Rules", pegá el contenido de `firestore.rules` de este repo
   (o corré `firebase deploy --only firestore:rules` desde la raíz del proyecto).

## 5. Generar firebase_options.dart (en tu PC)

```cmd
cd C:\Users\lia\Desktop\delivery_app_v2
dart pub global activate flutterfire_cli
flutterfire configure
```
- Elige el proyecto que creaste en el paso 1.
- Seleccioná Android (y lo que uses). iOS solo si lo vas a publicar ahí.
- Esto crea `lib/firebase_options.dart`. SIN este archivo el código NO compila.

## 6. Instalar dependencias y correr

```cmd
flutter pub get
flutter analyze      # debería dar "No issues found"
flutter run -d emulator-5554
```

## 7. Primer admin (importante)

El registro normal crea usuarios con `rol: 'cliente'`. Para hacer admin a un
usuario (vos):

- Registrate en la app normalmente (cualquier email/pass).
- En Firestore > Colección `usuarios` > doc con tu uid > editá `rol` de
  `cliente` a **`admin`**.
- Cerrá sesión y volvé a entrar. El router te manda solo a `/admin`.

(Después podemos automatizarlo con una Cloud Function o una pantalla de
asignación de roles protegida por admin.)

## 8. Poblar productos (opcional pero recomendado)

Desde Firestore > `productos` > Add document, con los campos del
`producto_model.dart`:
```
nombre: "Leche", precio_base: 1200, descuento_activo: false,
porcentaje_descuento: null, url_imagen: "", disponible: true, stock: 50
```
O pedime un script de seed en Dart para cargarlos en lote.

---

## Estructura creada en esta integración

```
lib/
  firebase_options.dart          <-generado por flutterfire (paso 5)
  main.dart                      <- Firebase.initializeApp
  app.dart                       <- ConsumerWidget + MaterialApp.router
  data/repositories/
    auth_repository.dart
    usuario_repository.dart
    producto_repository.dart
    pedido_repository.dart
  providers/
    app_providers.dart           <- authStateProvider, isAdminProvider, streams
    go_router_refresh_stream.dart<- conecta Auth con el router
  routes/app_router.dart         <- guard de admin REAL (rol desde Firestore)
  screens/login_screen.dart      <- Firebase Auth real (signIn / createUser)
firestore.rules                  <- reglas seguras (PII protegida)
firebase.json
```

## Notas de seguridad
- Nunca commitees `google-services.json` ni `firebase_options.dart` con claves
  de producción a un repo público. El `.gitignore` ya ignora `*.json`? Verificá.
- Las reglas de `firestore.rules` son restrictivas: cada usuario solo lee su
  propio doc; solo admin escribe productos/cambia estado de pedidos.
- Para Play Store: usá una SHA1 de la clave de firma de release, no solo debug.
