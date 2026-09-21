import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/db_service.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  Future<Map<String, dynamic>> _buildExportData() async {
    final productos = await DBService.getProducts();
    final ventas = await DBService.getSalesOfDay();
    final movimientos = await DBService.getMovements();
    final caja = await DBService.getCashSessions();

    return {
      'productos': productos,
      'ventas': ventas,
      'movimientos': movimientos,
      'caja': caja,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _exportJson(BuildContext context, Map<String, dynamic> data) async {
    final jsonString = jsonEncode(data);
    final path = await FilePicker.platform.saveFile(
      fileName: 'backup_mipypos.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (path == null) return;

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonString);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup exportado correctamente')),
      );
    }
  }

  Future<void> _openJsonUpload(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

    if (data['productos'] is List) {
      for (final item in List.from(data['productos'])) {
        if (item is Map<String, dynamic>) {
          await DBService.upsertProduct(item);
        } else if (item is Map) {
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

  Future<void> _exportProductsCsv(BuildContext context) async {
    final products = await DBService.getProducts();
    final buffer = StringBuffer();
    buffer.writeln('id;nombre;stock;price_cash;price_transfer');

    for (final p in products) {
      buffer.writeln(
        '${p['id']};${p['name']};${p['stock']};${p['price_cash']};${p['price_transfer']}',
      );
    }

    final path = await FilePicker.platform.saveFile(
      fileName: 'productos_mipypos.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (path == null) return;

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(buffer.toString());

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV exportado correctamente')),
      );
    }
  }

  Future<void> _exportShiftCsv(BuildContext context) async {
    final openSession = await DBService.getOpenCash();
    final summary = openSession == null
        ? <String, double>{
            'total': 0,
            'ventas': 0,
            'efectivo': 0,
            'transferencia': 0,
            'tarjeta': 0,
          }
        : await DBService.getSessionPaymentSummary(
            (openSession['id'] is int)
                ? openSession['id'] as int
                : int.tryParse('${openSession['id']}') ?? -1,
          );

    final buffer = StringBuffer();
    buffer.writeln('fecha;ventas;efectivo;transferencia;tarjeta');
    buffer.writeln(
      '${DateTime.now().toIso8601String()};'
      '${summary['ventas'] ?? 0};'
      '${summary['efectivo'] ?? 0};'
      '${summary['transferencia'] ?? 0};'
      '${summary['tarjeta'] ?? 0}',
    );

    final path = await FilePicker.platform.saveFile(
      fileName: 'cierre_turno_mipypos.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (path == null) return;

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(buffer.toString());

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cierre exportado correctamente')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronización')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                final data = await _buildExportData();
                await _exportJson(context, data);
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
              onPressed: () => _exportProductsCsv(context),
              child: const Text('Exportar productos (CSV)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _exportShiftCsv(context),
              child: const Text('Exportar cierre de turno (CSV)'),
            ),
          ],
        ),
      ),
    );
  }
}
