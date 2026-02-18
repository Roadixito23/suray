import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_html/html.dart' as html;
import 'home.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Future<void> _registrarVisita() async {
    try {
      const String localStorageKey = 'suray_ultima_visita';
      const Duration intervaloDeduplicacion = Duration(hours: 24);

      if (kIsWeb) {
        final String? ultimaVisitaStr =
            html.window.localStorage[localStorageKey];

        if (ultimaVisitaStr != null) {
          final DateTime ultimaVisita =
              DateTime.fromMillisecondsSinceEpoch(int.parse(ultimaVisitaStr));
          if (DateTime.now().difference(ultimaVisita) < intervaloDeduplicacion) {
            return; // Visita reciente, no contar
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('estadisticas')
          .doc('visitas')
          .set(
            {
              'cantidadVisitas': FieldValue.increment(1),
              'ultimaActualizacion': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

      if (kIsWeb) {
        html.window.localStorage[localStorageKey] =
            DateTime.now().millisecondsSinceEpoch.toString();
      }
    } catch (_) {
      // Silencio total. Nunca afectar la experiencia del usuario.
    }
  }

  @override
  void initState() {
    super.initState();
    _registrarVisita();
    // Esperar 1 segundo y navegar
    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomePage(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MyApp.primaryNavy,
              MyApp.lightNavy,
              MyApp.primaryOrange.withValues(alpha: 0.8),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: MyApp.primaryOrange.withValues(alpha: 0.3),
                  blurRadius: 25.0,
                  spreadRadius: 5.0,
                ),
                BoxShadow(
                  color: MyApp.primaryNavy.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/logocircle.png',
                width: 220,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
