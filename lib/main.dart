import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart'; // Eliminado
import 'firebase_options.dart';
import 'splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // --- NUEVA PALETA DE COLORES MODERNA ---
  static const Color primaryNavy = Color(0xFF001959); // Azul marino principal
  static const Color primaryOrange = Color(0xFFF47200); // Naranja vibrante principal
  static const Color lightNavy = Color(0xFF1E3A8A); // Azul marino más claro
  static const Color deepOrange = Color(0xFFE65100); // Naranja más oscuro
  static const Color softOrange = Color(0xFFFFA726); // Naranja suave
  static const Color accentBlue = Color(0xFF3B82F6); // Azul de acento
  static const Color lightGreyBackground = Color(0xFFF8FAFC); // Fondo moderno
  static const Color surfaceWhite = Color(0xFFFFFFFF); // Superficie blanca
  static const Color darkTextColor = Color(0xFF1E293B); // Texto principal
  static const Color lightTextColor = Color(0xFF64748B); // Texto secundario
  static const Color borderColor = Color(0xFFE2E8F0); // Bordes sutiles
  static const Color successColor = Color(0xFF10B981); // Verde para éxito
  static const Color warningColor = Color(0xFFF59E0B); // Amarillo para advertencias
  static const Color errorColor = Color(0xFFEF4444); // Rojo para errores

  // Colores para horarios por tipo de día
  static const Color weekdayMint = Color(0xFF06D6A0); // Verde menta para días laborales
  static const Color weekdayMintDark = Color(0xFF05B287); // Verde menta oscuro
  static const Color saturdayOrange = Color(0xFFFFB703); // Naranja dorado para sábados
  static const Color saturdayOrangeDark = Color(0xFFFB8500); // Naranja dorado oscuro
  static const Color sundayRed = Color(0xFFEF476F); // Rojo coral para domingos/feriados
  static const Color sundayRedDark = Color(0xFFD62246); // Rojo coral oscuro

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Suray',

      // --- THEME DATA CENTRALIZADO Y MODERNO ---
      theme: ThemeData(
        primaryColor: primaryNavy,
        scaffoldBackgroundColor: lightGreyBackground,
        fontFamily: 'Montserrat',

        // Esquema de colores para consistencia
        colorScheme: const ColorScheme.light(
          primary: primaryNavy,
          secondary: primaryOrange,
          tertiary: accentBlue,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          surface: surfaceWhite,
          onSurface: darkTextColor,
          error: errorColor,
          onError: Colors.white,
          outline: borderColor,
        ),

        // Estilos de texto para consistencia tipográfica
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'Hemiheads',
            fontSize: 32.0,
            color: primaryNavy,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Hemiheads',
            fontSize: 28.0,
            color: primaryNavy,
            fontWeight: FontWeight.bold,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'Hemiheads',
            fontSize: 24.0,
            color: primaryNavy,
            fontWeight: FontWeight.bold,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Hemiheads',
            fontSize: 22.0,
            fontWeight: FontWeight.bold,
            color: primaryNavy,
          ),
          titleMedium: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            color: darkTextColor,
          ),
          bodyLarge: TextStyle(
            fontSize: 16.0,
            color: darkTextColor,
            height: 1.6,
          ),
          bodyMedium: TextStyle(
            fontSize: 14.0,
            color: lightTextColor,
            height: 1.5,
          ),
          labelLarge: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: darkTextColor,
          ),
        ),

        // Tema para la AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontFamily: 'Hemiheads',
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),

        // Tema para las tarjetas
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: primaryNavy.withOpacity(0.1),
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor.withOpacity(0.5), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          color: surfaceWhite,
        ),

        // Tema para botones elevados
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
            ),
            elevation: 2,
            shadowColor: primaryOrange.withOpacity(0.3),
          ),
        ),

        // Tema para botones de texto
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryOrange,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Montserrat',
            ),
          ),
        ),

        // Tema para botones outlined
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryNavy,
            side: const BorderSide(color: primaryNavy, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Montserrat',
            ),
          ),
        ),

        // Tema para inputs
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryOrange, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),

        // Transiciones de página suaves
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: const SplashScreen(),
    );
  }
}