# KampusCheck

Aplicación móvil para **registrar y controlar la asistencia a clases** para diferentes cursos en la Universidad, la cual el registro de asistencia se hace mediante QR dinamico y geocerca Para GPS. Además del proyecto movil estar desarrollado en Flutter (Dart) y empleando como base de datos **Firebase**m


## Roles


| **Estudiante** | **IU** Pestaña "Estudiante" del login | **Funcion* Marca asistencia, consulta su horario, cursos y faltas, justifica inasistencias. |
| **Docente** | **UI** Pestaña "Docente" del login | **Funcion* Crea cursos, lanza sesiones, consulta el historial, aprueba justificaciones, exporta reportes. |
| **Soporte** | **UI**  Menú de tres puntos (⋮) junto a "Docente" | **Funcion* Atiende los tickets de la Mesa de Ayuda. Tiene registro breve propio. |


## Funcionalidades

### Docente
- Creación de cursos con días, horario, aula, edificio, campus y **total de sesiones (CLASES) del semestre** Carga del padrón por archivo Excel/CSV (matrícula; nombre; correo) con esa estructura estudiantes cargue de estudiantes.
- 
- **Validación de cruce de horarios**: no permite cursos solapados del mismo docente ni de un estudiante ya inscrito en otro curso activo.
- Lanzar una sesión de asistencia con **QR que cambia cada 1 minuto** y **geocerca** (radio configurable). El punto se toma del GPS o se ubica a mano en un **mapa real**.
- 
- Historial de asistencia por estudiante con **exportación a CSV (Excel)** y reporte general del curso.
- **Altas, ediciones y bajas manuales** de estudiantes, con la misma estructura del Excel.
- 
- **Aviso preventivo** de inasistencias (se muestra en el panel del estudiante y, opcionalmente, por correo).
- Revisión de justificaciones (aprobar o rechazar) con descarga del archivo adjunto y **registro histórico** de todas las justificaciones para el **estudiante** en su envió de justificaciones especificas a las sesiones de clases que ha faltado. 

### Estudiante
- Marcado de asistencia escaneando el QR, validado por **cercanía al aula** (geocerca).
- **Un teléfono, una cuenta por clase**: si el mismo dispositivo ya registró a otro estudiante en esa clase, se bloquea.
- Horario semanal de **lunes a domingo**, con próxima clase.
- Estado de faltas por curso con alertas de riesgo.
- **Justificación de una inasistencia concreta** (fecha y hora de la clase), con motivo y archivo adjunto (PDF o imagen, hasta 700 KB). Registro de sus justificaciones.

### Inasistencias dinámicas
La pérdida por fallas ocurre al superar el **20 %** de las sesiones del curso. El docente define el total de sesiones por curso; si al final se dictaron menos (por ejemplo 28 de 30), ajusta el total y el límite se recalcula sobre las sesiones realmente dictadas.

### Mesa de Ayuda
- Chat de soporte para usuarios con sesión y formulario de contacto para quien **no puede iniciar sesión** (el agente responde al correo indicado).
- Panel del agente de soporte con todos los tickets.



## Tecnologías

| Componente | Uso |
|---|---|
| Flutter / Dart (SDK ^3.13) | Aplicación multiplataforma (probada en Android) |
| `firebase_core`, `firebase_auth` | Autenticación por correo y contraseña |
| `cloud_firestore` | Base de datos en tiempo real |
| `mobile_scanner` | Lectura del código QR con la cámara |
| `qr_flutter` | Generación del QR del docente |
| `geolocator` | Ubicación GPS y cálculo de distancia a la geocerca |
| `flutter_map` + `latlong2` | Mapa (OpenStreetMap) para ubicar la geocerca |
| `file_picker` | Carga del padrón y adjuntos de justificaciones |
| `shared_preferences` | Identificador del dispositivo (control de un teléfono por clase) |

---

## Estructura del proyecto

```
kampuscheck/
├── android/            Proyecto nativo Android (permisos, Gradle, Firebase)
├── ios/                Proyecto nativo iOS
├── web/, windows/      Plataformas generadas por Flutter
├── test/               Pruebas
├── pubspec.yaml        Dependencias y metadatos
├── firebase.json       Configuración de Firebase CLI
└── lib/
    ├── main.dart               Punto de entrada
    ├── firebase_options.dart   Configuración generada de Firebase
    ├── page/                   Pantallas (login, registro, paneles, sesiones)
    │   ├── estudiante/         Panel, horario, cursos, perfil, marcar asistencia
    │   └── soporte/            Panel, chat y ayuda de la Mesa de Ayuda
    ├── providers/              Lógica y acceso a Firebase
    │   ├── auth_provider.dart
    │   ├── asistencia_provider.dart   (docente)
    │   ├── estudiante_provider.dart
    │   └── soporte_provider.dart
    └── src/                    Utilidades: tema, widgets, horario, validadores,
                                inasistencias, dispositivo, archivos
```

### Colecciones de Firestore

| `usuarios` | Perfil y rol (estudiante, docente, soporte) |
| `cursos` | Datos del curso, horario, padrón y total de sesiones |
| `sesiones` | Sesiones de asistencia (QR, geocerca) |
| `sesiones/{id}/asistencias` | Registro de cada estudiante en la sesión |
| `sesiones/{id}/dispositivos` | Dispositivo usado por cada estudiante en la sesión |
| `solicitudes` | Justificaciones de inasistencia |
| `notificaciones` | Avisos preventivos |
| `tickets` y `tickets/{id}/mensajes` | Mesa de Ayuda |
| `mail` | Cola de correos (extensión opcional Trigger Email) |

---

## Permisos de la aplicación

**Android** (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```
La cámara la declara automáticamente `mobile_scanner`.

**iOS** (`ios/Runner/Info.plist`): `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription` y `NSPhotoLibraryUsageDescription`.


## Cómo probarlo

1. **Docente:** iniciar sesión → crear un curso → lanzar una sesión (mostrar el QR).
2. **Estudiante** (otro teléfono): iniciar sesión → "Marcar asistencia" → escanear el QR dentro del radio.
3. Esperar 1 minuto: el QR cambia y el anterior deja de servir.
4. Cerrar sesión en el teléfono del estudiante y entrar con otra cuenta: el sistema bloquea el registro en esa misma clase.
5. Presentar una justificación con adjunto y aprobarla desde el docente.
6. Entrar como **Soporte** (⋮) y responder un ticket.



## Notas

- Los correos válidos son institucionales (`@udla.edu.co`); que llegan a carpeta de Spam


## Autor

Jeiner Chacón
