import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import 'dart:async';

//5.1 Importar Firebase Auth y la pantalla de productos
import 'package:firebase_auth/firebase_auth.dart';
import 'products_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isObscure = true;

  StateMachineController? _controller;
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;
  SMINumber? _numLook;

  Timer? _typingDebounce;

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  //5.2 Variable para mostrar el CircularProgressIndicator mientras carga
  bool _isLoading = false;

  void _showGlobalError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Credenciales inválidas. Verifica tu correo y contraseña.',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  //4.4 Dar acción al botón
  //5.3 Convertir _onLogin en asíncrono (Future<void> ... async)
  Future<void> _onLogin() async {
    final email = emailCtrl.text.trim();
    final pass = passwordCtrl.text;

    FocusScope.of(context).unfocus();
    _typingDebounce?.cancel();
    _isChecking?.change(false);
    _isHandsUp?.change(false);
    _numLook?.value = 50.0;

    // Hito 1 - A (OWASP): Solo validar que los campos no estén vacíos (sin Regex ni errores por campo)
    if (email.isEmpty || pass.isEmpty) {
      _trigFail?.fire();
      _showGlobalError();
      return;
    }

    //5.4 Activar el CircularProgressIndicator
    setState(() {
      _isLoading = true;
    });

    try {
      //5.5 Autenticar usuario en Firebase (esperamos un par de segundos para ver el loading)
      await Future.delayed(const Duration(seconds: 2));
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      //5.6 Apagar loading, disparar éxito del osito y esperar a que termine su animación
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _trigSuccess?.fire();
      await Future.delayed(const Duration(seconds: 2));

      //5.7 Navegar a la pantalla de productos de Spring Boot
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProductsScreen()),
      );
    } catch (e) {
      //5.8 Si Firebase rechaza el login, apagar loading, mostrar osito triste y mensaje global único (OWASP)
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _trigFail?.fire();
      _showGlobalError();
    }
  }

  // Hito 1 - C (h1-7): Hacer funcional "Forgot password?" con Dialog y sendPasswordResetEmail
  Future<void> _showForgotPasswordDialog() async {
    final resetEmailCtrl = TextEditingController(text: emailCtrl.text.trim());
    String? dialogError;
    bool isSending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Recuperar contraseña'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.',
                    style: TextStyle(fontSize: 13.5),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: resetEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'usuario@tecdesoftware.edu.mx',
                      errorText: dialogError,
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          final resetEmail = resetEmailCtrl.text.trim();
                          if (resetEmail.isEmpty || !resetEmail.contains('@')) {
                            setDialogState(() {
                              dialogError = 'Ingresa un correo válido';
                            });
                            return;
                          }

                          setDialogState(() {
                            dialogError = null;
                            isSending = true;
                          });

                          try {
                            await FirebaseAuth.instance.sendPasswordResetEmail(
                              email: resetEmail,
                            );
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);

                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Correo de recuperación enviado a $resetEmail. Revisa tu bandeja o spam.',
                                  ),
                                  backgroundColor: Colors.green.shade700,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                          } on FirebaseAuthException catch (e) {
                            setDialogState(() {
                              isSending = false;
                              dialogError = e.code == 'invalid-email'
                                  ? 'El formato del correo no es válido'
                                  : 'No se pudo enviar el correo. Verifica la dirección.';
                            });
                          } catch (_) {
                            setDialogState(() {
                              isSending = false;
                              dialogError =
                                  'Error al enviar el correo de recuperación';
                            });
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );

    resetEmailCtrl.dispose();
  }

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus) {
        if (_isHandsUp != null) {
          _isHandsUp?.change(false);
          _numLook?.value = 50;
        }
      }
    });

    _passwordFocusNode.addListener(() {
      _isHandsUp?.change(_passwordFocusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                SizedBox(
                  width: size.width,
                  height: 200,
                  child: RiveAnimation.asset(
                    'assets/login-bear-animation.riv',
                    stateMachines: ['Login Machine'],
                    onInit: (artboard) {
                      _controller = StateMachineController.fromArtboard(
                        artboard,
                        'Login Machine',
                      );
                      if (_controller == null) return;
                      artboard.addController(_controller!);
                      _isChecking = _controller?.findSMI('isChecking');
                      _isHandsUp = _controller?.findSMI('isHandsUp');
                      _trigSuccess = _controller?.findSMI('trigSuccess');
                      _trigFail = _controller?.findSMI('trigFail');
                      _numLook = _controller?.findSMI('numLook');
                    },
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  focusNode: _emailFocusNode,
                  onChanged: (value) {
                    if (_isHandsUp != null) {
                      //_isHandsUp!.change(false);
                    }
                    if (_isChecking != null) {
                      _isChecking!.change(true);
                      final look = (value.length / 70.0 * 100).clamp(
                        0.0,
                        100.0,
                      );
                      _numLook?.value = look;
                      _typingDebounce?.cancel();
                      _typingDebounce = Timer(const Duration(seconds: 3), () {
                        if (!mounted) return;
                        _isChecking?.change(false);
                      });
                    }
                  },
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "email@ejemplo.com",
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordCtrl,
                  focusNode: _passwordFocusNode,
                  onChanged: (value) {
                    if (_isHandsUp != null) {
                      _isHandsUp!.change(true);
                    }
                    if (_isChecking != null) {
                      //_isChecking!.change(false);
                    }
                  },
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    hintText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscure = !_isObscure;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text(
                      "Forgot password?",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ),
                SizedBox(
                  width: size.width,
                  child: const Text(
                    "Al iniciar sesión, aceptas nuestras políticas de privacidad y términos de servicio.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 10),
                MaterialButton(
                  minWidth: size.width,
                  height: 50,
                  color: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textColor: Colors.white,
                  onPressed: _onLogin,
                  //5.9 Mostrar CircularProgressIndicator si está cargando, o el texto Iniciar sesión
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Iniciar sesión",
                          style: TextStyle(color: Colors.white),
                        ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: size.width,
                  child: Row(
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {
                          // Hito 1 - B (h1-4): Navegar a SignUpScreen con Navigator.push
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignUpScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Sign up",
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
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
    emailCtrl.dispose();
    passwordCtrl.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _typingDebounce?.cancel();
    super.dispose();
  }
}