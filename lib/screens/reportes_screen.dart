import 'package:flutter/material.dart';

import '../services/db_service.dart';
import '../widgets/branding_widgets.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  bool loading = true;

  List<Map<String, dynamic>> ventas = [];
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> productos = [];
  List<Map<String, dynamic>> areas = [];
  List<Map<String, dynamic>> movimientos = [];

  String filtroUsuario = 'Todos';
  String filtroMetodo = 'Todos';

  double totalGeneral = 0;
  double totalEfectivo = 0;
  double totalTransferencia = 0;

  Map<String, double> totalPorUsuario = {};
  Map<String, double> totalPorProducto = {};
  Map<String, double> totalPorArea = {};

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final loadedProducts = await DBService.getProducts();
      final loadedAreas = await DBService.getAreas();
      final loadedSales = await DBService.getSalesOfDay();
      final loadedItems = await DBService.getSaleItems();
      final loadedMovements = await DBService.getMovementsOfDay();

      productos = loadedProducts;
      areas = loadedAreas;
      ventas = loadedSales;
      items = loadedItems;
      movimientos = loadedMovements;

      calcularTotales();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar reportes: $e'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  void calcularTotales() {
    totalGeneral = 0;
    totalEfectivo = 0;
    totalTransferencia = 0;

    totalPorUsuario = {};
    totalPorProducto = {};
    totalPorArea = {};

    for (final venta in ventas) {
      final total = _toDouble(venta['total']);
      final user = '${venta['user'] ?? 'desconocido'}';
      final method = '${venta['method'] ?? ''}'.toLowerCase();

      totalGeneral += total;

      if (method.contains('efectivo')) {
        totalEfectivo += total;
      }

      if (method.contains('transferencia') ||
          method.contains('tarjeta')) {
        totalTransferencia += total;
      }

      totalPorUsuario[user] =
          (totalPorUsuario[user] ?? 0.0) + total;
    }

    for (final item in items) {
      final productId = _toInt(item['product_id']);
      final productName = _productName(productId);
      final quantity = _toDouble(item['quantity']);
      final price = _toDouble(item['price']);

      totalPorProducto[productName] =
          (totalPorProducto[productName] ?? 0.0) +
              (quantity * price);
    }

    for (final movement in movimientos) {
      final areaId = _toInt(movement['to_area']);
      final areaName = _areaName(areaId);
      final quantity = _toDouble(movement['qty']);

      totalPorArea[areaName] =
          (totalPorArea[areaName] ?? 0.0) + quantity;
    }
  }

  List<Map<String, dynamic>> aplicarFiltros() {
    return ventas.where((venta) {
      final user = '${venta['user'] ?? ''}';
      final method = '${venta['method'] ?? ''}';

      if (filtroUsuario != 'Todos' &&
          filtroUsuario != user) {
        return false;
      }

      if (filtroMetodo != 'Todos' &&
          filtroMetodo != method) {
        return false;
      }

      return true;
    }).toList();
  }

  List<Map<String, dynamic>> itemsDeVenta(int saleId) {
    return items.where((item) {
      return _toInt(item['sale_id']) == saleId;
    }).toList();
  }

  String _productName(int productId) {
    for (final product in productos) {
      if (_toInt(product['id']) == productId) {
        return '${product['name'] ?? 'Producto desconocido'}';
      }
    }

    return 'Producto desconocido';
  }

  String _areaName(int areaId) {
    for (final area in areas) {
      if (_toInt(area['id']) == areaId) {
        return '${area['name'] ?? 'Área desconocida'}';
      }
    }

    return 'Área desconocida';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? -1;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0.0;
  }

  String _money(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final ventasFiltradas = aplicarFiltros();

    final users = ventas
        .map((venta) => '${venta['user'] ?? ''}')
        .where((user) => user.isNotEmpty)
        .toSet()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: cargarDatos,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: cargarDatos,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: BrandLogo(height: 56),
                  ),
                  const Text(
                    'Filtros',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: filtroUsuario,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'Todos',
                        child: Text('Todos'),
                      ),
                      ...users.map(
                        (user) => DropdownMenuItem(
                          value: user,
                          child: Text(user),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => filtroUsuario = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: filtroMetodo,
                    decoration: const InputDecoration(
                      labelText: 'Método de pago',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Todos',
                        child: Text('Todos'),
                      ),
                      DropdownMenuItem(
                        value: 'Efectivo',
                        child: Text('Efectivo'),
                      ),
                      DropdownMenuItem(
                        value: 'Transferencia',
                        child: Text('Transferencia'),
                      ),
                      DropdownMenuItem(
                        value: 'Tarjeta',
                        child: Text('Tarjeta'),
                      ),
                      DropdownMenuItem(
                        value: 'Mixto',
                        child: Text('Mixto'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => filtroMetodo = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Resumen del día',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Total general: ${_money(totalGeneral)}'),
                          Text('Efectivo: ${_money(totalEfectivo)}'),
                          Text(
                            'Transferencia/tarjeta: '
                            '${_money(totalTransferencia)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Totales por usuario',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (totalPorUsuario.isEmpty)
                            const Text('Sin datos')
                          else
                            ...totalPorUsuario.entries.map(
                              (entry) => Text(
                                '${entry.key}: ${_money(entry.value)}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Totales por producto',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (totalPorProducto.isEmpty)
                            const Text('Sin datos')
                          else
                            ...totalPorProducto.entries.map(
                              (entry) => Text(
                                '${entry.key}: ${_money(entry.value)}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Entradas por área',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (totalPorArea.isEmpty)
                            const Text('Sin datos')
                          else
                            ...totalPorArea.entries.map(
                              (entry) => Text(
                                '${entry.key}: '
                                '${entry.value.toStringAsFixed(0)} unidades',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ventas filtradas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (ventasFiltradas.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay ventas para mostrar.'),
                      ),
                    )
                  else
                    ...ventasFiltradas.map(_buildSaleCard),
                  const SizedBox(height: 16),
                  const CopyrightText(),
                ],
              ),
            ),
    );
  }

  Widget _buildSaleCard(Map<String, dynamic> sale) {
    final saleId = _toInt(sale['id']);
    final saleItems = itemsDeVenta(saleId);
    final total = _toDouble(sale['total']);

    return Card(
      child: ExpansionTile(
        title: Text(
          'Venta #$saleId - ${_money(total)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${sale['method'] ?? ''} • '
          '${sale['user'] ?? ''} • '
          '${sale['date'] ?? ''}',
        ),
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Productos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ...saleItems.map((item) {
            final productName =
                item['name']?.toString() ??
                _productName(_toInt(item['product_id']));
            final quantity = _toDouble(item['quantity']);
            final price = _toDouble(item['price']);

            return ListTile(
              leading: const Icon(Icons.shopping_bag),
              title: Text(
                '$productName x${quantity.toStringAsFixed(0)}',
              ),
              subtitle: Text(
                'Precio: ${_money(price)}',
              ),
            );
          }),
        ],
      ),
    );
  }
}