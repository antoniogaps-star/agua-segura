# Agua Segura — App móvil

Flutter + SQLite cifrado (Drift + SQLCipher). Aplicación **offline-first**: el técnico
registra el servicio en la azotea, donde no hay señal, y todo sube solo cuando vuelve a
haber internet.

## Requisitos

- Flutter 3.x (Dart >= 3.5)

## Puesta en marcha

```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # genera Drift/Freezed
flutter run
```

> **Importante:** `lib/data/local/database.g.dart` es **código generado** por Drift y
> NO está versionado. Hay que ejecutar `build_runner` (paso de arriba) antes de compilar
> o analizar, o el proyecto no compila. El CI lo hace automáticamente.

> **Gotcha de Windows + OneDrive:** si `build_runner` falla con "Acceso denegado" sobre
> `.dart_tool`, es OneDrive sincronizando esa carpeta. Detén OneDrive, borra `.dart_tool`,
> vuelve a generar y reinícialo.

Para apuntar a un backend distinto del de producción:

```bash
flutter run --dart-define=API_URL=http://TU_HOST:8000/api/v1
```

## Pantallas

1. **¿A quién le toca?** — la principal. Clientes con el mantenimiento vencido o por
   vencer, lo más urgente arriba, con el WhatsApp ya escrito.
2. **Hoy** — la agenda del técnico, con las referencias para llegar.
3. **Clientes** — la cartera, con quién recomendó a quién.
4. **Caja** — cobrado, por cobrar y quién quedó a deber.

Al terminar un servicio se toman las fotos del antes y el después, se arma el certificado
y se ofrece pedirle al cliente que los recomiende.

## Estructura

```
lib/
├── core/          # config, DI, formato, red
├── features/      # pendientes, services, clients, caja, auth, billing
├── data/
│   ├── local/     # esquema Drift/SQLite (con campos de sync)
│   └── sync/      # outbox + motor de sincronización
└── main.dart
```

## Comandos

```bash
flutter analyze
```

```bash
flutter test
```

## APK

Lo compila GitHub Actions en cada cambio de `mobile/` y queda con enlace fijo:

`https://github.com/antoniogaps-star/agua-segura/releases/latest/download/agua-segura.apk`
