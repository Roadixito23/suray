import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _notificationsEnabled = false;
  String? _fcmToken;

  bool get notificationsEnabled => _notificationsEnabled;
  String? get fcmToken => _fcmToken;

  /// Inicializar el servicio de notificaciones
  Future<void> initialize() async {
    try {
      // Solicitar permisos
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Permisos de notificaciones concedidos');
        _notificationsEnabled = true;

        // Obtener el token FCM
        _fcmToken = await _messaging.getToken(
          vapidKey:
              kIsWeb
                  ? 'BLwRb6doqfWV_Yjtl_sCYwB1KmeVl3tslPxjfQQSVqiCuZtJMdDtX7S8rakdun4CgbNTC4VvUX6tzex2KVO9Np8' // Ej: BEl7j3Hx9K2...
                  : null,
        );

        if (_fcmToken != null) {
          debugPrint('📱 Token FCM: $_fcmToken');
          // Aquí podrías guardar el token en Firestore si necesitas enviar notificaciones específicas
        }

        // Configurar listeners para mensajes
        _setupMessageHandlers();
      } else {
        debugPrint('⚠️ Permisos de notificaciones denegados');
        _notificationsEnabled = false;
      }
    } catch (e) {
      debugPrint('❌ Error inicializando notificaciones: $e');
      _notificationsEnabled = false;
    }
  }

  /// Configurar handlers para diferentes estados de la app
  void _setupMessageHandlers() {
    // Mensaje recibido cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 Mensaje recibido en primer plano:');
      debugPrint('   Título: ${message.notification?.title}');
      debugPrint('   Cuerpo: ${message.notification?.body}');
      debugPrint('   Data: ${message.data}');

      // Aquí podrías mostrar una notificación local o un banner in-app
    });

    // Mensaje recibido cuando la app está en segundo plano pero no cerrada
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 App abierta desde notificación:');
      debugPrint('   Título: ${message.notification?.title}');
      debugPrint('   Data: ${message.data}');

      // Aquí podrías navegar a una página específica basada en message.data
    });
  }

  /// Enviar una notificación de prueba (simulada)
  Future<void> sendTestNotification() async {
    if (!_notificationsEnabled) {
      debugPrint('⚠️ Las notificaciones no están habilitadas');
      return;
    }

    debugPrint('🧪 Enviando notificación de prueba...');
    debugPrint('📱 Token: $_fcmToken');
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('Para enviar una notificación de prueba real:');
    debugPrint('');
    debugPrint('1. Ve a Firebase Console > Cloud Messaging');
    debugPrint('2. Clic en "Enviar tu primer mensaje"');
    debugPrint('3. Título: "¡Bienvenido a Buses Suray!"');
    debugPrint(
      '4. Cuerpo: "Las notificaciones están activas. Te avisaremos sobre cambios en horarios."',
    );
    debugPrint('5. En "Objetivo" selecciona "Dispositivo único"');
    debugPrint('6. Pega este token: $_fcmToken');
    debugPrint('7. Envía la notificación');
    debugPrint('═══════════════════════════════════════════════════════');
  }

  /// Verificar si las notificaciones están habilitadas
  Future<bool> checkPermissions() async {
    try {
      NotificationSettings settings =
          await _messaging.getNotificationSettings();
      _notificationsEnabled =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      return _notificationsEnabled;
    } catch (e) {
      debugPrint('❌ Error verificando permisos: $e');
      return false;
    }
  }

  /// Solicitar permisos nuevamente
  Future<bool> requestPermissions() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      _notificationsEnabled =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      if (_notificationsEnabled && _fcmToken == null) {
        _fcmToken = await _messaging.getToken(
          vapidKey:
              kIsWeb
                  ? 'BLwRb6doqfWV_Yjtl_sCYwB1KmeVl3tslPxjfQQSVqiCuZtJMdDtX7S8rakdun4CgbNTC4VvUX6tzex2KVO9Np8'
                  : null,
        );
        debugPrint('📱 Nuevo token FCM: $_fcmToken');
        _setupMessageHandlers();
      }

      return _notificationsEnabled;
    } catch (e) {
      debugPrint('❌ Error solicitando permisos: $e');
      return false;
    }
  }
}
