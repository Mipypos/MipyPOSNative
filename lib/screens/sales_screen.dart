// lib/screens/sales_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cart_controller.dart';
import '../controllers/auth_controller.dart';
import '../core/session_manager.dart';
import '../services/db_service.dart';
import '../services/pdf_service.dart';
import '../widgets/branding_widgets.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];
  bool loadingProducts = true;
  bool processingSale = false;

  String selectedPayment = 'Efectivo';
  final TextEditingController searchController = TextEditingController();

  // Controles para búsqueda y pagos mixtos
  final TextEditingController cashAmountCtrl = TextEditingController();
  final TextEditingController transferAmountCtrl = TextEditingController();

  final List<String> paymentMethods = ['Efectivo', 'Tarjeta', 'Transferencia', 'Mixto'];

  @override
  void initState() {
    super.initState();
    loadProducts();
    searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    searchController.removeListener(_filterProducts);
    searchController.dispose();
    cashAmountCtrl.dispose();
    transferAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> loadProducts() async {
    setState(() => loadingProducts = true);
    try {
      products = await DBService.getProducts();
      _filterProducts();
    } catch (e) {
      products = [];
      filteredProducts = [];
    } finally {
      if (mounted) setState(() => loadingProducts = false);
    }
  }

  void _filterProducts() {
    final query = searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredProducts = List.from(products);
      } else {
        filteredProducts = products.where((p) {
          final name = (p['name'] ?? '').toString().toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> checkout() async {
    final cart = context.read<CartController>();
    final auth = context.read<AuthController>();
    final sessionManager = context.read<SessionManager>();

    if (cart.items.isEmpty || processingSale) return;

    if (!sessionManager.isOpen) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ No hay caja abierta. Abra caja en Dashboard.')),
        );
      }
      return;
    }

    final itemsSnapshot = cart.items.map((it) {
      return {
        'name': it.name,
        'qty': it.qty,
        'price': it.price,
      };
    }).toList();

    List<Map<String, dynamic>>? paymentsToSend;
    if (selectedPayment == 'Mixto') {
      final cash = double.tryParse(cashAmountCtrl.text) ?? 0.0;
      final transfer = double.tryParse(transferAmountCtrl.text) ?? 0.0;
      final sum = double.parse((cash + transfer).toStringAsFixed(2));
      final totalAmount = double.parse(cart.total.toStringAsFixed(2));
      if (sum != totalAmount) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Los montos mixtos deben sumar el total de la compra')),
          );
        }
        return;
      }
      paymentsToSend = [];
      if (cash > 0) paymentsToSend.add({'method': 'Efectivo', 'amount': cash});
      if (transfer > 0) paymentsToSend.add({'method': 'Transferencia', 'amount': transfer});
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar venta'),
        content: Text(
          "Total: \$${cart.total.toStringAsFixed(2)}\n"
          "${selectedPayment == 'Mixto' ? 'Método: Mixto (ver detalle)' : 'Método: $selectedPayment'}\n"
          "Usuario: ${auth.user?['user'] ?? 'desconocido'}",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cobrar')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => processingSale = true);

    try {
      final openSession = await DBService.getOpenCash();
      final sidMemory = sessionManager.sessionId;
      if (openSession == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ La caja fue cerrada. No se puede procesar la venta.')),
          );
        }
        return;
      }
      final sidDb = (openSession['id'] is int) ? openSession['id'] as int : int.tryParse('${openSession['id']}');
      if (sidMemory == null || sidDb != sidMemory) {
        await sessionManager.loadSession();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Sesión de caja desincronizada. Recargue y vuelva a intentar.')),
          );
        }
        return;
      }

      final ticketTextBuffer = StringBuffer();
      ticketTextBuffer.writeln('MipyPOS - Ticket de Venta');
      ticketTextBuffer.writeln('-------------------------');
      ticketTextBuffer.writeln('Método: $selectedPayment');
      ticketTextBuffer.writeln('Usuario: ${auth.user?['user'] ?? 'desconocido'}');
      ticketTextBuffer.writeln('Total: \$${cart.total.toStringAsFixed(2)}');
      ticketTextBuffer.writeln('');
      ticketTextBuffer.writeln('Productos:');
      for (var it in itemsSnapshot) {
        final name = it['name']?.toString() ?? 'Producto';
        final qty = (it['qty'] is int) ? it['qty'] as int : int.tryParse('${it['qty']}') ?? 0;
        final price = (it['price'] is num) ? (it['price'] as num).toDouble() : double.tryParse('${it['price']}') ?? 0.0;
        final lineTotal = price * qty;
        ticketTextBuffer.writeln('- $name x$qty = \$${lineTotal.toStringAsFixed(2)}');
      }

      if (paymentsToSend != null && paymentsToSend.isNotEmpty) {
        ticketTextBuffer.writeln('');
        ticketTextBuffer.writeln('Pagos:');
        for (var p in paymentsToSend) {
          ticketTextBuffer.writeln('- ${p['method']}: \$${(p['amount'] as num).toDouble().toStringAsFixed(2)}');
        }
      }

      final saleId = await cart.checkout(
        method: selectedPayment,
        user: auth.user?['user'] ?? 'desconocido',
        sessionId: sidMemory,
        payments: paymentsToSend,
      );

      final ticketBytes = ticketTextBuffer.toString().codeUnits;
      try {
        await PdfService.generateTicket(ticketBytes);
      } catch (e) {
        debugPrint('Ticket write failed: $e');
      }

      await loadProducts();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('✅ Venta exitosa'),
            content: Text('Venta registrada: $saleId\nTicket guardado localmente si el sistema lo permitió.'),
            actions: [
              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Aceptar')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al procesar venta: $e')));
      }
    } finally {
      if (mounted) setState(() => processingSale = false);
    }
  }

  String _generateTicketText() {
    final cart = context.read<CartController>();
    final auth = context.read<AuthController>();
    final buffer = StringBuffer();
    buffer.writeln('MipyPOS - Ticket de Venta (PREVIEW)');
    buffer.writeln('Usuario: ${auth.user?['user'] ?? 'desconocido'}');
    buffer.writeln('Método: $selectedPayment');
    buffer.writeln('-------------------------');
    for (var it in cart.items) {
      final name = it.name;
      final qty = it.qty;
      final price = it.price;
      buffer.writeln('- $name x$qty = \$${(price * qty).toStringAsFixed(2)}');
    }
    buffer.writeln('');
    buffer.writeln('Total: \$${cart.total.toStringAsFixed(2)}');
    if (selectedPayment == 'Mixto') {
      final cash = double.tryParse(cashAmountCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final transfer = double.tryParse(transferAmountCtrl.text.replaceAll(',', '.')) ?? 0.0;
      buffer.writeln('Pagos:');
      if (cash > 0) buffer.writeln('- Efectivo: \$${cash.toStringAsFixed(2)}');
      if (transfer > 0) buffer.writeln('- Transferencia: \$${transfer.toStringAsFixed(2)}');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final sessionManager = context.watch<SessionManager>();

    final bool canSell = sessionManager.isOpen && !processingSale && cart.items.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            BrandLogo(height: 28),
            SizedBox(width: 12),
            Text(
              'MipyPOS',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -1),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadProducts, tooltip: 'Actualizar productos'),
        ],
      ),
      body: loadingProducts
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 900;
              return Row(
                children: [
                  Expanded(
                    flex: isWide ? 3 : 1,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextField(
                            controller: searchController,
                            decoration: const InputDecoration(labelText: 'Buscar producto', prefixIcon: Icon(Icons.search)),
                          ),
                        ),
                        Expanded(
                          child: filteredProducts.isEmpty
                              ? const Center(child: Text('No se encontraron productos.'))
                              : GridView.builder(
                                  padding: const EdgeInsets.all(10),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: isWide ? 3 : 1,
                                    childAspectRatio: isWide ? 1.4 : 4.5,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 8,
                                  ),
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (_, i) {
                                    final p = filteredProducts[i];
                                    final stock = (p['stock'] is int) ? p['stock'] as int : int.tryParse('${p['stock']}') ?? 0;

                                    final priceValue = selectedPayment == 'Efectivo'
                                        ? (p['price_cash'] ?? p['price_transfer'] ?? 0.0)
                                        : (p['price_transfer'] ?? p['price_cash'] ?? 0.0);

                                    final price = (priceValue is num) ? (priceValue as num).toDouble() : double.tryParse('$priceValue') ?? 0.0;

                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                      child: InkWell(
                                        onTap: stock > 0
                                            ? () {
                                                context.read<CartController>().add({
                                                  'id': p['id'],
                                                  'name': p['name'],
                                                  'price': price,
                                                });
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Añadido: ${p['name']}')));
                                              }
                                            : null,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.inventory_2, color: Theme.of(context).colorScheme.primary),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                                ],
                                              ),
                                              const Spacer(),
                                              Text('Stock: $stock', style: const TextStyle(fontSize: 12)),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text('\$${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                                  ElevatedButton(
                                                    onPressed: stock > 0 ? () => context.read<CartController>().add({'id': p['id'], 'name': p['name'], 'price': price}) : null,
                                                    child: const Text('Añadir'),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: isWide ? 420 : 360,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(-2, 0))],
                    ),
                    child: Column(
                      children: [
                        if (cart.items.isNotEmpty)
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              itemCount: cart.items.length,
                              itemBuilder: (_, i) {
                                final item = cart.items[i];
                                return Card(
                                  margin: const EdgeInsets.only(right: 6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.shopping_cart, color: Colors.green),
                                        const SizedBox(height: 6),
                                        Text('${item.name} x${item.qty}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        InkWell(onTap: () => context.read<CartController>().remove(item.productId), child: const Icon(Icons.close, size: 18, color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Text('Método:'),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: selectedPayment,
                                items: paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                onChanged: (v) => setState(() => selectedPayment = v!),
                              ),
                              const Spacer(),
                              Text('\$${cart.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),

                        if (selectedPayment == 'Mixto')
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: cashAmountCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Efectivo (\$)',
                                      prefixIcon: const Icon(Icons.attach_money),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: transferAmountCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Transferencia (\$)',
                                      prefixIcon: const Icon(Icons.swap_horiz),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: canSell ? Colors.green : Colors.grey,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              onPressed: canSell ? checkout : null,
                              icon: processingSale
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.payment, size: 22),
                              label: Text(processingSale ? 'Procesando...' : 'COBRAR'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
    );
  }
}
