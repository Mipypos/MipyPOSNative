// lib/screens/sync_screen_web.dart
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../services/db_service.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  Future<Map<String, dynamic>> _buildExportData() async {
    return {
      'productos': await DBService.getProducts(),
      'ventas': await DBService.getSalesOfDay(),
      'movimientos': await DBService.getMovements(),
      'caja': await DBService.getCashSessions(),
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  void _download(String content, String filename, String mimeType) {
    final blob = html.Blob([content], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = filename
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _importJson(BuildContext context, Map<String, dynamic> data) async {
    final products = data['productos'];
    if (products is List) {
      for (final item in products) {
        if (item is Map) {
          await DBService.upsertProduct(Map<String, dynamic>.from(item));
        }
      }
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('JSON importado correctamente')),
      );
    }
  }

  void _openJsonUpload(BuildContext context) {
    final input = html.FileUploadInputElement()..accept = '.json';
    input.click();
    input.onChange.listen((_) {
      final file = input.files?.first;
      if (file == null) return;
      final reader = html.FileReader()..readAsText(file);
      reader.onLoadEnd.listen((_) async {
        final result = reader.result;
        if (result is! String) return;
        final decoded = jsonDecode(result);
        if (decoded is Map) {
          await _importJson(context, Map<String, dynamic>.from(decoded));
        }
      });
    });
  }

  Future<void> _exportProductsCsv() async {
    final products = await DBService.getProducts();
    final buffer = StringBuffer('id;nombre;stock;price_cash;price_transfer\n');
    for (final p in products) {
      buffer.writeln('${p['id']};${p['name']};${p['stock']};${p['price_cash']};${p['price_transfer']}');
    }
    _download(buffer.toString(), 'productos_mipypos.csv', 'text/csv');
  }

  Future<void> _exportShiftCsv() async {
    final sales = await DBService.getSalesOfDay();
    double total = 0;
    double cash = 0;
    double transfer = 0;
    for (final sale in sales) {
      final amount = sale['total'] is num ? (sale['total'] as num).toDouble() : double.tryParse('${sale['total']}') ?? 0;
      total += amount;
      final method = '${sale['method'] ?? ''}'.toLowerCase();
      if (method.contains('efectivo')) {
        cash += amount;
      } else {
        transfer += amount;
      }
    }
    final buffer = StringBuffer('fecha;ventas;efectivo;transferencia\n');
    buffer.writeln('${DateTime.now().toIso8601String()};$total;$cash;$transfer');
    _download(buffer.toString(), 'cierre_turno_mipypos.csv', 'text/csv');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronización (Web)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                final data = await _buildExportData();
                _download(jsonEncode(data), 'backup_mipypos.json', 'application/json');
              },
              child: const Text('Exportar JSON (backup)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _openJsonUpload(context),
              child: const Text('Importar JSON (restore)'),
            ),
            const Divider(height: 32),
            ElevatedButton(
              onPressed: _exportProductsCsv,
              child: const Text('Exportar productos (CSV)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _exportShiftCsv,
              child: const Text('Exportar cierre de turno (CSV)'),
            ),
          ],
        ),
      ),
    );
  }
}
