import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  // 6.1 Parámetro clave: URL base de la API de Spring Boot (puerto 8090)
  // - Web / iOS Simulator / macOS / Celular USB (adb reverse): http://localhost:8090
  // - Emulador Android: http://10.0.2.2:8090
  static const String baseUrl = 'http://localhost:8090';

  // 6.2 Función para pedir la lista de productos al endpoint GET /products
  Future<List<dynamic>> fetchProducts() async {
    final response = await http.get(Uri.parse('$baseUrl/products'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar productos de la API');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos de Spring Boot'),
        actions: [
          // Hito 1 - C (h1-8): Botón de Cerrar sesión en el AppBar del catálogo
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      // 6.3 FutureBuilder: espera la respuesta de la API y dibuja el resultado
      body: FutureBuilder<List<dynamic>>(
        future: fetchProducts(),
        builder: (context, snapshot) {
          // Mientras responde el servidor, mostrar indicador de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Si hubo un error de conexión
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final products = snapshot.data ?? [];

          // 6.4 Mostrar los elementos de la base de datos en una lista sencilla
          // Hito 1 - D (h1-10): Mostrar además de nombre, stock y precio, la categoría product['category']['category']
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final categoryName = product['category'] != null
                  ? product['category']['category']
                  : 'Sin categoría';
              final imageUrl = product['imageUrl']?.toString() ?? '';
              return ListTile(
                // Hito 2 - A (h2-2): Mostrar imagen desde Supabase Storage con Image.network y errorBuilder
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                title: Text(product['name'].toString()),
                subtitle: Text(
                  'Categoría: $categoryName • Stock: ${product['stock']}',
                ),
                trailing: Text('\$${product['price']}'),
              );
            },
          );
        },
      ),
    );
  }
}
