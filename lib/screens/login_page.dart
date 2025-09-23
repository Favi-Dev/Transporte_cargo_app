// Bloque 1: Importaciones
/// Importa los paquetes necesarios para la pantalla:
/// - `material.dart`: Para los widgets de Flutter.
/// - `firebase_auth.dart`: Para acceder a los servicios de Autenticación de Firebase.
/// - `main_screen.dart`: La pantalla principal a la que se navega tras un login exitoso.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_screen.dart';

// Bloque 2: Definición del StatefulWidget
/// Define la `LoginPage` como un `StatefulWidget`. Es necesario que tenga estado
/// para manejar la información que el usuario introduce en los campos, el estado de carga
/// del botón de login, y la visibilidad de la contraseña.
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

// Bloque 3: Clase de Estado
/// Clase que maneja toda la lógica y el estado de la pantalla de Login.
class _LoginPageState extends State<LoginPage> {
  // Bloque 3.1: Variables de Estado y Controladores
  /// Define las variables de estado y controladores para el formulario:
  /// - `_rutController` y `_passwordController`: Gestionan el texto de los campos de entrada.
  /// - `_formKey`: Identifica el formulario para poder validarlo.
  /// - `_scrollController`: Controla el scroll automático de la pantalla al iniciar.
  /// - `_obscureText`: Controla si la contraseña se muestra o se oculta.
  /// - `_isLoading`: Controla el estado de carga para mostrar un loader en el botón.
  final _rutController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  bool _obscureText = true;
  bool _isLoading = false;

  // Bloque 3.2: Método initState
  /// Método del ciclo de vida que se ejecuta una sola vez cuando la pantalla se crea.
  /// Se utiliza para iniciar la animación de scroll automático que desplaza la vista
  /// hacia el formulario de login poco después de que la pantalla se muestra.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  // Bloque 3.3: Método _handleLogin
  /// Método asíncrono que contiene la lógica principal para el inicio de sesión.
  /// 1. Valida el formulario.
  /// 2. Activa el estado de carga.
  /// 3. Transforma el RUT del usuario al formato de email requerido por Firebase Auth.
  /// 4. Llama a `signInWithEmailAndPassword` para autenticar al usuario.
  /// 5. Si tiene éxito, navega a la `MainScreen`.
  /// 6. Si falla, muestra un `SnackBar` con el mensaje de error.
  /// 7. Desactiva el estado de carga al finalizar.
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final rut = _rutController.text.trim();
      final email = '$rut@fernandezcargo.cl';
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Error de autenticación.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Bloque 3.4: Método dispose
  /// Método de limpieza del ciclo de vida. Se asegura de liberar los recursos
  /// utilizados por los controladores (`_rutController`, `_passwordController`, `_scrollController`)
  /// cuando la pantalla es eliminada, para prevenir fugas de memoria.
  @override
  void dispose() {
    _rutController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Bloque 4: Método build
  /// Método principal que construye la compleja interfaz visual de la pantalla de login.
  /// - Usa un `Stack` para superponer el fondo curvo rojo detrás del contenido principal.
  /// - Un `SingleChildScrollView` permite que la pantalla sea desplazable en dispositivos pequeños.
  /// - Un `Form` contiene los campos de texto (`TextFormField`) y el botón de login,
  ///   gestionando la validación de los datos ingresados por el usuario.
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: _BottomWaveClipper(),
              child: Container(
                height: size.height * 0.3,
                color: const Color(0xFFD32F2F),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: size.height * 0.1),
                        Image.asset(
                          'assets/images/Logo_Fernandez_SPA-removebg-preview.png',
                          width: size.width * 0.4,
                        ),
                        const SizedBox(height: 40),
                        const Text('Hola Otra Vez!',
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text('Ingresa Tu RUT Y Contraseña',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[600])),
                        const SizedBox(height: 30),
                        Container(
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF212121),
                            borderRadius: BorderRadius.circular(20.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                spreadRadius: 5,
                                blurRadius: 15,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Inicia sesión aquí',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _rutController,
                                decoration: InputDecoration(
                                  hintText: '12345678-9',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none),
                                ),
                                keyboardType: TextInputType.text,
                                validator: (value) => value!.isEmpty
                                    ? 'Por favor ingresa tu RUT'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscureText,
                                decoration: InputDecoration(
                                  hintText: 'Contraseña',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscureText
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.grey),
                                    onPressed: () {
                                      setState(() {
                                        _obscureText = !_obscureText;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) => value!.isEmpty
                                    ? 'Por favor ingresa tu contraseña'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Checkbox(
                                      value: false,
                                      onChanged: (val) {},
                                      checkColor: Colors.white,
                                      activeColor: const Color(0xFFD32F2F),
                                      side: const BorderSide(
                                          color: Colors.white54)),
                                  const Text('Recordarme',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD32F2F),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Text('INICIAR SESIÓN',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {},
                                child: const Text('¿Olvidaste tu contraseña?',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: size.height * 0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Bloque 5: Clase _BottomWaveClipper
/// Clase auxiliar privada que extiende `CustomClipper`. Su única función es
/// definir la forma geométrica (el `Path`) de la curva roja del fondo.
class _BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.quadraticBezierTo(size.width / 2, size.height * 0.3, 0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
