import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isObscurePass = true;
  bool _isObscureConfirm = true;
  bool _isLoading = false;

  String? _emailError;
  String? _passError;
  String? _confirmPassError;

  // Hito 1 - B (h1-5): Validación de correo institucional @tecdesoftware.edu.mx
  bool _isValidInstitutionalEmail(String email) {
    final re = RegExp(
      r'^[^\s@]+@tecdesoftware\.edu\.mx$',
      caseSensitive: false,
    );
    return re.hasMatch(email);
  }

  // Hito 1 - B (h1-5): Reglas individuales de contraseña para mostrarlas en pantalla
  bool get _hasMinLength => _passwordCtrl.text.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordCtrl.text);
  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_passwordCtrl.text);
  bool get _hasDigit => RegExp(r'\d').hasMatch(_passwordCtrl.text);
  bool get _hasSpecial =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(_passwordCtrl.text);

  bool _isValidPassword(String pass) {
    final re = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
    );
    return re.hasMatch(pass);
  }

  Future<void> _onSignUp() async {
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final confirmPass = _confirmPasswordCtrl.text;

    String? eError;
    String? pError;
    String? cError;

    if (email.isEmpty) {
      eError = 'Ingresa tu correo institucional';
    } else if (!_isValidInstitutionalEmail(email)) {
      eError = 'Debe terminar en @tecdesoftware.edu.mx';
    }

    if (pass.isEmpty) {
      pError = 'Ingresa una contraseña';
    } else if (!_isValidPassword(pass)) {
      pError = 'La contraseña no cumple con todos los requisitos';
    }

    if (confirmPass.isEmpty) {
      cError = 'Confirma tu contraseña';
    } else if (confirmPass != pass) {
      cError = 'Las contraseñas no coinciden';
    }

    setState(() {
      _emailError = eError;
      _passError = pError;
      _confirmPassError = cError;
    });

    FocusScope.of(context).unfocus();

    if (eError != null || pError != null || cError != null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Hito 1 - B (h1-6): Registrar usuario en Firebase Authentication
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              '¡Cuenta registrada con éxito! Ahora puedes iniciar sesión.',
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );

      // Regresar a la pantalla de Login
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.code == 'email-already-in-use') {
          _emailError = 'Este correo institucional ya está registrado';
        } else if (e.code == 'invalid-email') {
          _emailError = 'El formato del correo no es válido';
        } else if (e.code == 'weak-password') {
          _passError = 'La contraseña es demasiado débil';
        }
      });

      if (e.code != 'email-already-in-use' &&
          e.code != 'invalid-email' &&
          e.code != 'weak-password') {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Error al registrar: ${e.message ?? e.code}'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Ocurrió un error inesperado al registrar.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Widget _buildRuleItem(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: met ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: met ? Colors.green.shade800 : Colors.grey.shade700,
                fontWeight: met ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool emailMet = _isValidInstitutionalEmail(_emailCtrl.text.trim());

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Registro de usuario',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ingresa tu correo institucional y crea una contraseña segura.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailCtrl,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo institucional',
                    hintText: 'usuario@tecdesoftware.edu.mx',
                    errorText: _emailError,
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordCtrl,
                  onChanged: (_) => setState(() {}),
                  obscureText: _isObscurePass,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Contraseña segura',
                    errorText: _passError,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscurePass
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscurePass = !_isObscurePass;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _confirmPasswordCtrl,
                  onChanged: (_) => setState(() {}),
                  obscureText: _isObscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    hintText: 'Repite tu contraseña',
                    errorText: _confirmPassError,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscureConfirm = !_isObscureConfirm;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: size.width,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Requisitos de la cuenta:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildRuleItem(
                        'Correo con terminación @tecdesoftware.edu.mx',
                        emailMet,
                      ),
                      _buildRuleItem('Mínimo 8 caracteres', _hasMinLength),
                      _buildRuleItem(
                        'Al menos una letra mayúscula (A-Z)',
                        _hasUppercase,
                      ),
                      _buildRuleItem(
                        'Al menos una letra minúscula (a-z)',
                        _hasLowercase,
                      ),
                      _buildRuleItem('Al menos un número (0-9)', _hasDigit),
                      _buildRuleItem(
                        'Al menos un símbolo especial (!@#\$%...)',
                        _hasSpecial,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                MaterialButton(
                  minWidth: size.width,
                  height: 50,
                  color: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textColor: Colors.white,
                  onPressed: _isLoading ? null : _onSignUp,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Registrarse',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿Ya tienes una cuenta?'),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Inicia sesión',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }
}
