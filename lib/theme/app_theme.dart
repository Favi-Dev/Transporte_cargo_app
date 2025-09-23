// Bloque 1: Importaciones
/// Importa el paquete `material.dart` de Flutter, que es esencial para
/// acceder a todas las clases y widgets de Material Design, incluyendo
/// `ThemeData`, `Color`, `CardThemeData`, etc.
import 'package:flutter/material.dart';

// Bloque 2: Definición de la Clase
/// Clase de utilidad que centraliza toda la configuración de diseño y tema de la aplicación.
/// Al usar propiedades y métodos estáticos (`static`), no es necesario crear una instancia
/// de `AppTheme` para usar sus miembros; se accede directamente (ej. `AppTheme.theme`).
class AppTheme {
  /// Bloque 2.1: Constantes de Color
  /// Define los colores principales de la marca como constantes estáticas para ser
  /// reutilizadas fácilmente a lo largo del tema, asegurando consistencia y
  /// facilitando futuros cambios de diseño.
  static const Color primaryRed = Color(0xFFD32F2F);
  static const Color darkCard = Color(0xFF212121);
  static const Color lightBackground = Color(0xFFF5F5F5);

  /// Bloque 2.2: Getter del Tema Principal
  /// Un `getter` estático que construye y devuelve el objeto `ThemeData` principal de la app.
  /// Este objeto contiene toda la configuración de estilo que se aplicará
  /// de forma global a todos los widgets de Material Design.
  static ThemeData get theme {
    return ThemeData(
      /// Define el esquema de colores moderno (Material 3), generado a partir de un
      /// color 'semilla' (`seedColor`). Flutter deriva una paleta completa y armoniosa
      /// a partir de este color base.
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTheme.primaryRed,
        brightness: Brightness.light,
        background: AppTheme.lightBackground,
      ),

      /// Establece el color de fondo por defecto para todas las pantallas (`Scaffold`).
      scaffoldBackgroundColor: AppTheme.lightBackground,

      /// Personaliza la apariencia de todas las `AppBar`s para que tengan un estilo consistente.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.lightBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      /// Define el estilo por defecto para todos los widgets `Card`. En este caso,
      /// un fondo oscuro, bordes redondeados y una ligera elevación.
      /// Se usa `CardThemeData` por compatibilidad con la versión de Flutter del proyecto.
      cardTheme: CardThemeData(
        color: AppTheme.darkCard,
        elevation: 4,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      /// Establece un estilo único y consistente para todos los `ElevatedButton`s.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryRed,
          foregroundColor: Colors.white,
          side: const BorderSide(
            color: Colors.white, // Color del borde
            width: 2.0, // Grosor del borde
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),

      /// Personaliza la barra de navegación inferior (`BottomNavigationBar`).
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primaryRed,
        unselectedItemColor: Colors.grey,
      ),

      /// Define el estilo para las barras de pestañas (`TabBar`).
      /// Se usa `TabBarThemeData` por compatibilidad con la versión de Flutter del proyecto.
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppTheme.primaryRed,
        labelColor: AppTheme.primaryRed,
        unselectedLabelColor: Colors.black54,
      ),

      /// Habilita el uso de los componentes y estilos más recientes de Material Design 3.
      useMaterial3: true,
    );
  }
}
