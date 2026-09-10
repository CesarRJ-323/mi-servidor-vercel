# 🛵 Delivery App V2 - Documentación del Proyecto

> **Aplicación de delivery hiperlocal multiplataforma** construida con Flutter 3.47.2

---

## 📱 Contexto del Proyecto

Aplicación móvil de delivery hiperlocal **exclusivamente para Android e iOS**, diseñada para conectar usuarios con productos/locales cercanos. Incluye sistema de tokens acumulables, promociones dinámicas, carrito inteligente y panel administrativo completo.

### Características Principales
- **Autenticación dual**: Login para clientes y panel administrativo
- **Promociones dinámicas**: Barra de promos con auto-scroll y timing configurable
- **Catálogo categorizado**: Organización por categorías con precios dinámicos
- **Carrito inteligente**: Controles de cantidad, cálculo de descuentos
- **Sistema de tokens**: Acumulación y canje por promociones
- **Panel administrativo**: Gestión de pedidos, productos y promociones

---

## 📁 Estructura del Proyecto

```
delivery_app_v2/
├── lib/
│   ├── main.dart                 # Entry point
│   ├── app.dart                  # Configuración global y temas
│   ├── routes/
│   │   └── app_router.dart       # Navegación con GoRouter
│   ├── models/
│   │   ├── usuario_model.dart    # Modelo Usuario (cliente/admin)
│   │   ├── producto_model.dart   # Modelo Producto con precios dinámicos
│   │   └── pedido_model.dart     # Modelo Pedido con items
│   ├── screens/
│   │   ├── login_screen.dart     # Login/Registro con WhatsApp
│   │   ├── home_screen.dart      # Home con PromoBar + categorías
│   │   ├── category_screen.dart  # Lista de productos por categoría
│   │   ├── cart_screen.dart      # Carrito con controles de cantidad
│   │   ├── promos_screen.dart    # Lista de promociones disponibles
│   │   └── admin/
│   │       ├── admin_dashboard.dart  # Dashboard con stats en tiempo real
│   │       ├── pedidos_screen.dart   # Gestión de pedidos
│   │       ├── productos_screen.dart # CRUD de productos
│   │       └── promos_screen.dart    # Gestión de promociones y tokens
│   └── widgets/
│       └── promo_bar.dart        # Widget reutilizable de promociones
├── assets/
│   ├── images/                   # Imágenes de productos
│   ├── icons/                    # Iconos SVG/PNG
│   └── fonts/                    # Fuentes Poppins
├── test/
│   └── widget_test.dart          # Tests unitarios
├── android/                      # Configuración Android nativa
├── ios/                          # Configuración iOS nativa
├── pubspec.yaml                  # Dependencias del proyecto
├── setup-flutter.bat             # Script de configuración Flutter
└── README.md                     # Este archivo
```

---

## 🛠️ Tecnologías y Arquitectura

### Stack Tecnológico
- **Flutter** 3.47.2 (Canal Stable)
- **Dart** 3.13.2
- **GoRouter** 18.0.0 - Navegación declarativa
- **Flutter Riverpod** 2.6.1 - Gestión de estado
- **CachedNetworkImage** 4.0.0 - Carga eficiente de imágenes
- **Image Picker** 1.2.3 - Selección de imágenes desde galería/cámara
- **Intl** 0.20.3 - Formateo de fechas y monedas

### Arquitectura Clean Architecture
1. **Presentación** (`screens/`, `widgets/`)
2. **Dominio** (`models/`)
3. **Datos** (Firestone integrations pendientes)

### Patrones Implementados
- **Model-View-Presenter** (MVP) simplificado
- **Dependency Injection** vía Riverpod
- **Navigation** declarativa con GoRouter
- **Mock Data** para desarrollo y testing

---

## 🎨 Sistema de Diseño

### Paleta de Colores
| Uso | Hex | Preview |
|-----|-----|---------|
| Primary | `#667EEA` | 🟣 |
| Secondary | `#764BA2` | 🟣 |
| Fondo | `#2A0800` | 🟤 |
| Acento | `#0891B2` | 💧 |
| Texto principal | `#333333` | ⚫ |
| Texto secundario | `#666666` | 🌫️ |
| Error | `#FF4757` | 🔴 |
| Éxito | `#2ED573` | 🟢 |

### Tipografía
- **Fuente principal**: Poppins (Regular, Medium, SemiBold, Bold)
- **Fallback**: Roboto (nativo de Flutter)

---

## 🚀 Cómo Ejecutar el Proyecto

### Requisitos
1. Flutter SDK 3.47.2+
2. Android SDK API 34+ (para emulador)
3. Java JDK 17+
4. Chrome/Edge (para testing web)

### Instalación (Windows)
1. Abrir el script de configuración:
   ```cmd
   C:\Users\lia\Desktop\run-flutter.bat
   ```

2. Seleccionar la opción correspondiente:
   ```
   1. Ver dispositivos/emuladores disponibles
   2. Correr app en emulador
   3. Correr app en Chrome
   4. Ver estado del sistema (flutter doctor)
   ```

### Hot Reload
Presionar `r` en la terminal para aplicar cambios sin reiniciar.

---

## 📱 Pantallas Principales

### 1. LoginScreen (`lib/screens/login_screen.dart`)
- Formulario de registro/login
- Integración con WhatsApp para soporte
- Navegación a HomeScreen tras login

### 2. HomeScreen (`lib/screens/home_screen.dart`)
- **PromoBar**: Barra de promociones con auto-scroll (5 segundos)
- Lista de categorías con cards interactivos
- Bottom sheet con órdenes recientes
- Footer con botón de WhatsApp

### 3. CategoryScreen (`lib/screens/category_screen.dart`)
- Lista de productos por categoría
- Cálculo dinámico de precios con descuentos
- Integración con carrito

### 4. CartScreen (`lib/screens/cart_screen.dart`)
- Control de cantidad por producto
- Cálculo de subtotal con descuentos
- Integración con promos
- Checkout vía Mercado Pago (placeholder)

### 5. PromosScreen (`lib/screens/promos_screen.dart`)
- Lista de todas las promociones activas
- Detalles completos de cada oferta
- Sistema de tokens visible

### 6. AdminPanel
- `admin_dashboard.dart`: Stats en tiempo real, pedidos recientes
- `pedidos_screen.dart`: Lista de pedidos con estados (pendiente, confirmado, en_camino, entregado, cancelado)
- `productos_screen.dart`: CRUD de productos
- `promos_screen.dart`: Gestión de promociones y tokens

---

## 🔐 Models Data Structure

### Usuario
```dart
class Usuario {
  String uid;
  String nombre;
  String email;
  String telefono;
  String direccion;
  double? latitud;  // Geolocalización
  double? longitud;
  int tokensBalance;
  bool esAdmin;  // cliente | admin
}
```

### Producto
```dart
class Producto {
  String id;
  String nombre;
  num precioBase;
  bool descuentoActivo;
  num? porcentajeDescuento;
  String urlImagen;
  bool disponible;
  int stock;
  
  // Computed property
  num get precioFinal;  // Aplica descuento si está activo
}
```

### Pedido
```dart
enum EstadoPedido { pendiente, confirmado, enCamino, entregado, cancelado }

class Pedido {
  String id;
  String usuarioId;
  List<PedidoItem> items;
  double subtotal;
  double descuentoAplicado;
  int tokensUtilizados;
  double total;
  String direccionEnvio;
  EstadoPedido estado;
  String? metodoPagoId;
  DateTime fechaCreacion;
}
```

---

## 🧪 Testing

### Tests Unitarios
```bash
# Ejecutar todos los tests
flutter test

# Ejecutar test específico
flutter test test/widget_test.dart

# Generar reporte de cobertura
flutter test --coverage
```

### Preview en Chrome
```bash
flutter run -d chrome
```

---

## 📦 Build de Producción

### Android APK
```bash
flutter build apk --release --build-number=1
```

### Android App Bundle (Google Play)
```bash
flutter build appbundle --release
```

### Web
```bash
flutter build web --release
```

### iOS (macOS requerido)
```bash
flutter build ios --release
```

---

## 🔧 Configuración del Entorno

### Windows Setup Script
Use el script `run-flutter.bat` ubicado en el escritorio para configurar automáticamente el entorno Flutter en Windows:

```cmd
C:\Users\lia\Desktop\run-flutter.bat
```

Este script configura:
- PATH de Flutter
- PATH de Android SDK
- JAVA_HOME
- Variables de entorno necesarias

---

## 🐛 Troubleshooting

### Problemas Comunes

1. **"No connected devices"**
   - Ejecutar `flutter devices` para ver dispositivos disponibles
   - Iniciar emulador: `flutter emulators --launch pixel_5_api_34`

2. **"Building with plugins requires symlink support"**
   - Habilitar Developer Mode en Windows
   - Reiniciar terminal después de cambios de PATH

3. **"flutter: command not found"**
   - Usar `run-flutter.bat` para configuración automática
   - Verificar path: `where flutter`

4. **Errores de compilación Android**
   - Verificar `local.properties` tiene `sdk.dir` correcto
   - Asegurar Android SDK API 34+ instalado