import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  // 6.1 Parámetro clave: URL base de la API de Spring Boot (puerto 8090)
  // - Web / iOS Simulator / macOS / Celular USB (adb reverse): http://localhost:8090
  // - Emulador Android: http://10.0.2.2:8090
  static const String baseUrl = 'http://localhost:8090';

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<List<dynamic>> _productsFuture;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Todas';

  // Catálogo base de categorías de PostgreSQL (id_categoria -> nombre)
  static const Map<int, String> _defaultCategories = {
    1: 'Frutas y verduras',
    2: 'Pastelería',
    3: 'Carnes y pescados',
    4: 'Lácteos y huevos',
    5: 'Bebidas',
    6: 'Licores',
    7: 'Cuidado personal',
    8: 'Despensa',
  };

  @override
  void initState() {
    super.initState();
    _productsFuture = fetchProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reloadProducts() {
    setState(() {
      _productsFuture = fetchProducts();
    });
  }

  // 6.2 Función para pedir la lista de productos al endpoint GET /products
  Future<List<dynamic>> fetchProducts() async {
    final response = await http.get(
      Uri.parse('${ProductsScreen.baseUrl}/products'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Código de estado: ${response.statusCode}');
    }
  }

  // Hito 2 - B (h2-5): Crear producto (POST /products)
  Future<void> _createProduct(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('${ProductsScreen.baseUrl}/products'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al crear producto (${response.statusCode})');
    }
  }

  // Hito 2 - B (h2-5): Actualizar producto existente (PUT /products/{id})
  Future<void> _updateProduct(
    int productId,
    Map<String, dynamic> payload,
  ) async {
    final bodyWithId = {...payload, 'productId': productId};
    final putResponse = await http.put(
      Uri.parse('${ProductsScreen.baseUrl}/products/$productId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bodyWithId),
    );

    if (putResponse.statusCode == 200 || putResponse.statusCode == 201) {
      return;
    }

    // Respaldo compatible si el servidor aún no se ha reiniciado con @PutMapping
    if (putResponse.statusCode == 405 || putResponse.statusCode == 404) {
      final postResponse = await http.post(
        Uri.parse('${ProductsScreen.baseUrl}/products'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyWithId),
      );
      if (postResponse.statusCode == 200 || postResponse.statusCode == 201) {
        return;
      }
    }

    throw Exception(
      'Error al actualizar producto (${putResponse.statusCode})',
    );
  }

  // Hito 2 - B (h2-5): Eliminar producto (DELETE /products/{id})
  Future<void> _deleteProduct(int productId) async {
    final response = await http.delete(
      Uri.parse('${ProductsScreen.baseUrl}/products/$productId'),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        'No se pudo eliminar (puede tener compras asociadas en la BD).',
      );
    }
  }

  // Hito 2 - B (h2-5): Diálogo para Crear (POST) o Editar (PUT) producto
  Future<void> _showProductFormDialog({Map<String, dynamic>? product}) async {
    final bool isEditing = product != null;
    final nameCtrl = TextEditingController(
      text: isEditing ? (product['name']?.toString() ?? '') : '',
    );
    final priceCtrl = TextEditingController(
      text: isEditing ? (product['price']?.toString() ?? '') : '',
    );
    final stockCtrl = TextEditingController(
      text: isEditing ? (product['stock']?.toString() ?? '') : '',
    );
    final imageUrlCtrl = TextEditingController(
      text: isEditing ? (product['imageUrl']?.toString() ?? '') : '',
    );

    int selectedCategoryId = isEditing
        ? (int.tryParse(product['categoryId']?.toString() ?? '') ?? 1)
        : 1;
    if (!_defaultCategories.containsKey(selectedCategoryId)) {
      selectedCategoryId = 1;
    }

    String? formError;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Editar producto' : 'Nuevo producto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (formError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          formError!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre del producto',
                        prefixIcon: const Icon(Icons.inventory_2_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Categoría',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _defaultCategories.entries
                          .map(
                            (entry) => DropdownMenuItem<int>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedCategoryId = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Precio',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Stock',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: imageUrlCtrl,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: 'URL de imagen (Supabase)',
                        hintText: 'https://...supabase.co/...',
                        prefixIcon: const Icon(Icons.image_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          FocusScope.of(dialogContext).unfocus();
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final price = double.tryParse(priceCtrl.text.trim());
                          final stock = int.tryParse(stockCtrl.text.trim());
                          final imageUrl = imageUrlCtrl.text.trim();

                          if (name.isEmpty || price == null || stock == null) {
                            setDialogState(() {
                              formError =
                                  'Completa nombre, precio válido y stock entero.';
                            });
                            return;
                          }

                          setDialogState(() {
                            formError = null;
                            isSaving = true;
                          });

                          final payload = <String, dynamic>{
                            'name': name,
                            'categoryId': selectedCategoryId,
                            'price': price,
                            'stock': stock,
                            'active': true,
                            'imageUrl': imageUrl.isEmpty ? null : imageUrl,
                          };

                          try {
                            if (isEditing) {
                              final int id = int.parse(
                                product['productId'].toString(),
                              );
                              await _updateProduct(id, payload);
                            } else {
                              await _createProduct(payload);
                            }

                            if (!dialogContext.mounted) return;
                            FocusScope.of(dialogContext).unfocus();
                            Navigator.pop(dialogContext);

                            if (!mounted) return;
                            _reloadProducts();
                            ScaffoldMessenger.of(this.context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? 'Producto "$name" actualizado correctamente.'
                                        : 'Producto "$name" creado correctamente.',
                                  ),
                                  backgroundColor: Colors.green.shade700,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              formError = e.toString().replaceAll(
                                'Exception: ',
                                '',
                              );
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isEditing ? 'Guardar cambios' : 'Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Hito 2 - B (h2-5): Confirmar y eliminar producto (DELETE /products/{id})
  Future<void> _confirmDeleteProduct(Map<String, dynamic> product) async {
    final int? productId = int.tryParse(product['productId']?.toString() ?? '');
    if (productId == null) return;
    final String name = product['name']?.toString() ?? 'este producto';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Estás segura de que deseas eliminar "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _deleteProduct(productId);
      if (!mounted) return;
      _reloadProducts();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Producto "$name" eliminado.'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  String _getCategoryName(dynamic product) {
    if (product['category'] != null &&
        product['category']['category'] != null) {
      return product['category']['category'].toString();
    }
    final int? catId = int.tryParse(product['categoryId']?.toString() ?? '');
    if (catId != null && _defaultCategories.containsKey(catId)) {
      return _defaultCategories[catId]!;
    }
    return 'Sin categoría';
  }

  String _formatPrice(dynamic rawPrice) {
    final num? value = rawPrice is num
        ? rawPrice
        : num.tryParse(rawPrice?.toString() ?? '');
    if (value == null) return '\$0.00';
    return '\$${value.toStringAsFixed(2)}';
  }

  int _parseStock(dynamic rawStock) {
    if (rawStock is int) return rawStock;
    if (rawStock is num) return rawStock.toInt();
    return int.tryParse(rawStock?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        title: const Text(
          'Catálogo de Productos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar catálogo',
            onPressed: _reloadProducts,
          ),
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
      // Hito 2 - B (h2-5): Botón flotante para crear nuevo producto (POST)
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        onPressed: () => _showProductFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
      // 6.3 FutureBuilder: espera la respuesta de la API y dibuja el resultado
      body: FutureBuilder<List<dynamic>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          // Mientras responde el servidor, mostrar indicador de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Hito 2 - B (h2-6): Vista amigable de "Servidor no disponible" con botón "Reintentar"
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_off_rounded,
                        size: 56,
                        color: Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Servidor no disponible',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No fue posible conectar con la API de Spring Boot. Verifica que el servidor esté encendido y vuelve a intentarlo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _reloadProducts,
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Reintentar',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final allProducts = snapshot.data ?? [];

          // Extraer categorías únicas para los chips de filtro (Hito 2 - B: h2-4)
          final Set<String> categorySet = {'Todas'};
          for (final p in allProducts) {
            categorySet.add(_getCategoryName(p));
          }
          final List<String> categories = categorySet.toList();

          // Filtrar por búsqueda de nombre y por categoría seleccionada (Hito 2 - B: h2-4)
          final filteredProducts = allProducts.where((product) {
            final name = (product['name'] ?? '').toString().toLowerCase();
            final category = _getCategoryName(product);
            final matchesSearch =
                _searchQuery.isEmpty ||
                name.contains(_searchQuery.toLowerCase());
            final matchesCategory =
                _selectedCategory == 'Todas' || category == _selectedCategory;
            return matchesSearch && matchesCategory;
          }).toList();

          return Column(
            children: [
              // Hito 2 - B (h2-4): Barra de búsqueda y chips de filtro por categoría
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar producto por nombre...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF0F3F8),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final isSelected = cat == _selectedCategory;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: Colors.blue.shade700,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedCategory = cat;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Hito 2 - B (h2-3): Rediseño moderno del catálogo en GridView con tarjetas
              Expanded(
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 56,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No se encontraron productos',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.64,
                            ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = Map<String, dynamic>.from(
                            filteredProducts[index] as Map,
                          );
                          final categoryName = _getCategoryName(product);
                          final imageUrl =
                              product['imageUrl']?.toString() ?? '';
                          final stock = _parseStock(product['stock']);
                          final isLowStock = stock < 50;

                          return Card(
                            elevation: 2,
                            shadowColor: Colors.black12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Imagen desde Supabase Storage con indicador de stock
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                                  color: Colors.grey.shade200,
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .image_not_supported_outlined,
                                                        size: 38,
                                                        color: Colors
                                                            .grey
                                                            .shade500,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Sin imagen',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isLowStock
                                                ? Colors.orange.shade800
                                                : Colors.green.shade700,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            isLowStock
                                                ? 'Poco stock ($stock)'
                                                : 'Stock: $stock',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Información del producto y botones de Editar / Eliminar (CRUD)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    10,
                                    8,
                                    6,
                                    6,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          categoryName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: Colors.blue.shade800,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        product['name']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _formatPrice(product['price']),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.blue.shade800,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            iconSize: 19,
                                            color: Colors.blue.shade700,
                                            tooltip: 'Editar',
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            onPressed: () =>
                                                _showProductFormDialog(
                                                  product: product,
                                                ),
                                          ),
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            iconSize: 19,
                                            color: Colors.red.shade600,
                                            tooltip: 'Eliminar',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            onPressed: () =>
                                                _confirmDeleteProduct(product),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
