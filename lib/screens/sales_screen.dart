import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cart_controller.dart';
import '../controllers/auth_controller.dart';
import '../core/session_manager.dart';
import '../services/db_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Map<String, dynamic>> products = <Map<String, dynamic>>[];
  bool loading = true;
  String method = 'Efectivo';
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    search.addListener(_onSearch);
    _load();
  }

  @override
  void dispose() {
    search.removeListener(_onSearch);
    search.dispose();
    super.dispose();
  }

  void _onSearch() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      products = await DBService.getProducts();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _checkout() async {
    final cart = context.read<CartController>();
    final session = context.read<SessionManager>();
    if (!session.isOpen || cart.items.isEmpty) return;

    try {
      final user = context.read<AuthController>().user?['user']?.toString() ?? 'desconocido';
      await cart.checkout(
        method: method,
        user: user,
        sessionId: session.sessionId!,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venta registrada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final session = context.watch<SessionManager>();
    final query = search.text.trim().toLowerCase();
    final shown = products
        .where((p) => (p['name'] ?? '').toString().toLowerCase().contains(query))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextField(
                          controller: search,
                          decoration: const InputDecoration(
                            labelText: 'Buscar producto',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.2,
                          ),
                          itemCount: shown.length,
                          itemBuilder: (_, i) {
                            final p = shown[i];
                            final stock = int.tryParse('${p['stock']}') ?? 0;
                            final raw = method == 'Efectivo' ? p['price_cash'] : p['price_transfer'];
                            final price = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0.0;

                            return Card(
                              child: ListTile(
                                title: Text('${p['name']}'),
                                subtitle: Text('Stock: $stock  Precio: \$${price.toStringAsFixed(2)}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_shopping_cart),
                                  onPressed: stock > 0
                                      ? () => cart.add({
                                          'id': p['id'],
                                          'name': p['name'],
                                          'price': price,
                                        })
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 330,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        DropdownButton<String>(
                          value: method,
                          isExpanded: true,
                          items: ['Efectivo', 'Tarjeta', 'Transferencia']
                              .map(
                                (x) => DropdownMenuItem(value: x, child: Text(x)),
                              )
                              .toList(),
                          onChanged: (x) {
                            if (x != null) setState(() => method = x);
                          },
                        ),
                        Expanded(
                          child: ListView(
                            children: cart.items
                                .map(
                                  (x) => ListTile(
                                    title: Text(x.name),
                                    trailing: Text('${x.qty} x \$${x.price.toStringAsFixed(2)}'),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        Text(
                          'Total: \$${cart.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: session.isOpen && cart.items.isNotEmpty ? _checkout : null,
                          icon: const Icon(Icons.payment),
                          label: const Text('COBRAR'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
