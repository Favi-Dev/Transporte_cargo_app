// Bloque 1: Importaciones
/// Importa el paquete `material.dart` para tener acceso a la clase `Color`
/// y a la paleta de colores predefinida de Material Design (ej. `Colors.red`).
import 'package:flutter/material.dart';

// Bloque 2: Función getColorFromString
/// Función de utilidad que convierte un nombre de color en formato `String`
/// (ej. "rojo"), tal como se guarda en Firestore, a un objeto `Color` que
/// Flutter puede usar para dibujar en la interfaz de usuario.
///
/// Esto es crucial para la funcionalidad de la "burbuja de color" en las listas
/// de vehículos.
///
/// @param colorName El nombre del color en formato de texto.
/// @return Un objeto `Color` correspondiente al nombre.
Color getColorFromString(String colorName) {
  /// Primero, convierte el texto de entrada a minúsculas para que la comparación
  /// no sea sensible a mayúsculas (ej. "Rojo", "rojo" y "ROJO" darán el mismo resultado).
  String lowerColorName = colorName.toLowerCase();

  /// Utiliza una sentencia `switch` para comparar el nombre del color y devolver
  /// el objeto `Color` predefinido de Flutter correspondiente.
  switch (lowerColorName) {
    case 'rojo':
      return Colors.red;
    case 'azul':
      return Colors.blue;
    case 'amarillo':
      return Colors.yellow;
    case 'verde':
      return Colors.green;
    case 'negro':
      return Colors.black;
    case 'blanco':
      return Colors.white;
    case 'gris':
      return Colors.grey;
    case 'naranja':
      return Colors.orange;
    case 'morado':
      return Colors.purple;
    // Se pueden añadir más colores aquí si la flota de vehículos se expande.

    /// Cláusula `default`: si el `colorName` que llega desde Firestore no coincide
    /// con ninguno de los casos anteriores, se devuelve un color gris por defecto.
    /// Esto previene que la aplicación falle si se introduce un color no reconocido.
    default:
      return Colors.grey.shade400;
  }
}
