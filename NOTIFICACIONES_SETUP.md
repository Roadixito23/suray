# Configuración de Notificaciones Push con Firebase

## 📱 Sistema de Notificaciones Implementado

Se ha agregado un sistema completo de notificaciones push usando Firebase Cloud Messaging (FCM) con:

- ✅ Banner flotante atractivo que invita a activar notificaciones
- ✅ Botón de activación con feedback visual
- ✅ Botón X para cerrar el banner
- ✅ Servicio de notificaciones completo
- ✅ Soporte para Web y Móvil
- ✅ Notificación de prueba automática

## 🚀 Pasos para Completar la Configuración

### 1. Instalar Dependencias

```bash
cd /home/road/dev/suray
flutter pub get
```

### 2. Configurar Firebase Console

#### a) Obtener VAPID Key (Solo Web)

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto
3. Ve a **Project Settings** (⚙️) > **Cloud Messaging**
4. En la sección **Web configuration**, busca **Web Push certificates**
5. Si no existe, clic en **Generate key pair**
6. Copia la **Key pair** (VAPID key)

#### b) Actualizar el Código

Abre `/home/road/dev/suray/lib/services/notification_service.dart` y reemplaza:

```dart
vapidKey: kIsWeb
    ? 'TU_VAPID_KEY_AQUI' // <- Pega tu VAPID key aquí
    : null,
```

### 3. Crear Service Worker para Web

Crea el archivo `web/firebase-messaging-sw.js`:

```javascript
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// Tu configuración de Firebase (obtenerla de firebase_options.dart)
firebase.initializeApp({
  apiKey: "TU_API_KEY",
  authDomain: "TU_AUTH_DOMAIN",
  projectId: "TU_PROJECT_ID",
  storageBucket: "TU_STORAGE_BUCKET",
  messagingSenderId: "TU_MESSAGING_SENDER_ID",
  appId: "TU_APP_ID",
  measurementId: "TU_MEASUREMENT_ID"
});

const messaging = firebase.messaging();

// Manejar mensajes en segundo plano
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Mensaje recibido en segundo plano:', payload);
  
  const notificationTitle = payload.notification.title || 'Buses Suray';
  const notificationOptions = {
    body: payload.notification.body || 'Nueva notificación',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'suray-notification',
    requireInteraction: false,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
```

### 4. Actualizar web/index.html

Agrega antes del cierre de `</body>`:

```html
<!-- Firebase Messaging Service Worker -->
<script>
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/firebase-messaging-sw.js')
      .then((registration) => {
        console.log('Service Worker registrado:', registration);
      })
      .catch((error) => {
        console.error('Error registrando Service Worker:', error);
      });
  }
</script>
```

### 5. Probar Notificaciones

#### Opción A: Desde la App (Notificación de Prueba)

1. Ejecuta la app: `flutter run -d chrome --web-port=8080`
2. Espera 3 segundos a que aparezca el banner naranja
3. Clic en **"Activar ahora"**
4. Acepta los permisos del navegador
5. En la consola verás el token FCM y las instrucciones

#### Opción B: Desde Firebase Console

1. Ve a Firebase Console > **Cloud Messaging**
2. Clic en **"Send your first message"**
3. Completa:
   - **Notification title**: "¡Bienvenido a Buses Suray!"
   - **Notification text**: "Las notificaciones están activas. Te avisaremos sobre cambios en horarios."
4. Clic en **"Send test message"**
5. Pega el **token FCM** de la consola
6. Clic en **"Test"**

## 📋 Características del Banner

### Diseño
- ✅ Fondo degradado naranja (color corporativo)
- ✅ Ícono de campana animado
- ✅ Texto claro y conciso
- ✅ Botón "Activar ahora" destacado
- ✅ Botón X para cerrar
- ✅ Sombras y bordes profesionales

### Comportamiento
- ✅ Aparece 3 segundos después de cargar la página
- ✅ Solo se muestra si las notificaciones NO están activadas
- ✅ Se oculta automáticamente al activar notificaciones
- ✅ Se puede cerrar manualmente con el botón X
- ✅ Muestra feedback visual (FloatingNotification) al activar

### Mensajes de Feedback
- ✅ **Éxito**: "¡Notificaciones activadas! Te avisaremos sobre cambios importantes."
- ✅ **Error**: "No se pudieron activar las notificaciones. Verifica los permisos de tu navegador."
- ✅ **Token en consola**: Para pruebas manuales

## 🔔 Casos de Uso de Notificaciones

### 1. Cambios de Horarios
```javascript
{
  "title": "Cambio de Horario",
  "body": "El horario de salida de Puerto Aysén ha cambiado a las 15:30 hrs.",
  "data": {
    "type": "schedule_change",
    "route": "aysen_to_coyhaique"
  }
}
```

### 2. Días Festivos
```javascript
{
  "title": "Horario Especial - Feriado",
  "body": "Mañana es feriado. Consulta los horarios especiales.",
  "data": {
    "type": "holiday",
    "date": "2026-03-15"
  }
}
```

### 3. Clima Adverso
```javascript
{
  "title": "Alerta Climática",
  "body": "Condiciones climáticas adversas en la ruta. Consulta actualizaciones.",
  "data": {
    "type": "weather_alert",
    "severity": "high"
  }
}
```

### 4. Servicios Especiales
```javascript
{
  "title": "Servicio Especial",
  "body": "Bus adicional hoy a las 18:00 desde Puerto Aysén.",
  "data": {
    "type": "special_service",
    "time": "18:00"
  }
}
```

## 🎨 Personalización

### Cambiar Colores del Banner

En `lib/home.dart`, método `_buildNotificationBanner()`:

```dart
gradient: LinearGradient(
  colors: [
    MyApp.primaryOrange,  // Color principal
    MyApp.primaryOrange.withOpacity(0.85),  // Color degradado
  ],
),
```

### Cambiar Tiempo de Aparición

En `lib/home.dart`, método `_initializeNotifications()`:

```dart
await Future.delayed(const Duration(seconds: 3)); // Cambiar segundos aquí
```

### Desactivar Banner Permanentemente

En `lib/home.dart`, `initState()`:

```dart
// Comentar esta línea:
// _initializeNotifications();
```

## 🛠️ Troubleshooting

### El banner no aparece
- Verifica que han pasado 3 segundos desde la carga
- Verifica que las notificaciones no estén ya activadas
- Revisa la consola para errores

### Error al solicitar permisos
- Verifica que estás en HTTPS o localhost
- Algunos navegadores bloquean notificaciones en HTTP
- Revisa la configuración de permisos del navegador

### Service Worker no se registra
- Verifica que `firebase-messaging-sw.js` esté en la carpeta `web/`
- Verifica la configuración de Firebase
- Abre DevTools > Application > Service Workers

### Token FCM null
- Verifica que la VAPID key esté configurada
- Verifica los permisos del navegador
- Revisa Firebase Console > Cloud Messaging

## 📱 Testing en Diferentes Navegadores

### Chrome/Edge
```bash
flutter run -d chrome --web-port=8080
```

### Firefox
```bash
flutter run -d firefox --web-port=8080
```

### Safari (macOS)
```bash
flutter run -d safari --web-port=8080
```

## 🔐 Seguridad

- ✅ Tokens FCM encriptados en tránsito
- ✅ Permisos solicitados explícitamente
- ✅ Usuario puede revocar permisos en cualquier momento
- ✅ No se almacenan datos sensibles en notificaciones
- ✅ VAPID key solo en configuración del cliente

## 📊 Métricas Sugeridas

Puedes trackear en Firebase Analytics:
- Tasa de activación de notificaciones
- Tasa de apertura de notificaciones
- Conversión desde notificación a horarios
- Notificaciones enviadas vs entregadas

---

**Implementado**: Marzo 2026  
**Versión**: 1.0  
**Estado**: ✅ Listo para producción (requiere configuración de VAPID key)
