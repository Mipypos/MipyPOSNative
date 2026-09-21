import 'package:flutter/material.dart';

import '../services/db_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  double todayTotal = 0;
  double todayProfit = 0;
  int todaySalesCount = 0;
  List<Map<String, dynamic>> topProducts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  Future<void> loadReport() async {
    setState(() => loading = true);

    try {
      todayTotal = await DBService.todaySales();
      topProducts = await DBService.topProducts();

      final sales = await DBService.getSalesOfDay();
      final saleItems = await DBService.getSaleItems();

      double profit = 0;
      int count = 0;

      for (final sale in sales) {
        final saleId = (sale['id'] is int)
            ? sale['id'] as int
            : int.tryParse('${sale['id']}') ?? -1;

        if (saleId < 0) continue;
        count++;

        for (final item in saleItems) {
          final itemSaleId = (item['sale_id'] is int)
              ? item['sale_id'] as int
              : int.tryParse('${item['sale_id']}') ?? -1;

          if (itemSaleId != saleId) continue;

          final price = (item['price'] is num)
              ? (item['price'] as num).toDouble()
              : double.tryParse('${item['price']}') ?? 0.0;

          final qty = (item['quantity'] is num)
              ? (item['quantity'] as num).toDouble()
              : double.tryParse('${item['quantity']}') ?? 0.0;

          profit += price * qty;
        }
      }

      todayProfit = profit;
      todaySalesCount = count;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar reportes: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadReport,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadReport,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCard(
                    'Ventas del día',
                    '\$${todayTotal.toStringAsFixed(2)}',
                    '$todaySalesCount ventas realizadas',
                    Colors.blue,
                    Icons.today,
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryCard(
                    'Ganancia estimada',
                    '\$${todayProfit.toStringAsFixed(2)}',
                    'Ingreso total (sin costo)',
                    Colors.green,
                    Icons.trending_up,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Productos más vendidos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (topProducts.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay ventas registradas hoy.'),
                      ),
                    )
                  else
                    Card(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('#')),
                          DataColumn(label: Text('Producto')),
                          DataColumn(label: Text('Cant. Vendida')),
                        ],
                        rows: topProducts.asMap().entries.map((entry) {
                          final index = entry.key + 1;
                          final product = entry.value;

                          return DataRow(cells: [
                            DataCell(Text('$index')),
                            DataCell(Text(product['name'] ?? '')),
                            DataCell(Text('${product['total_qty'] ?? 0}')),
                          ]);
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withAlpha(51),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}