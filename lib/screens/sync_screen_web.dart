import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/db_service.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  Future<Map<String, dynamic>> _buildExportData() async {
    final products = await DBService.getProducts();
    final sales = await DBService.getSalesOfDay();
    final movements = await DBService.getMovements();
    final cashSessions = await DBService.getCashSessions();

    return {
      'productos': products,
      'ventas': sales,
      'movimientos': movements,
      'caja': cashSessions,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<String?> _selectSavePath({
    required String fileName,
    required String extension,
  }) async {
    return FilePicker.platform.saveFile(
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
    );
  }

  Future<void> _writeFile(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  Future<void> _exportJson(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    try {
      final path = await _selectSavePath(
        fileName: 'backup_mipypos.json',
        extension: 'json',
      );

      if (path == null || path.isEmpty) return;

      final content = const JsonEncoder.withIndent('  ').convert(data);
      await _writeFile(path, content);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup exportado correctamente'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar el backup: $e'),
        ),
      );
    }
  }

  Future<void> _importJson(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;

      if (bytes == null) {
        throw Exception('No se pudieron leer los datos del archivo.');
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final decoded = jsonDecode(content);

      if (decoded is! Map) {
        throw Exception('El archivo JSON no contiene un objeto válido.');
      }

      final data = Map<String, dynamic>.from(decoded);

      final products = data['productos'];

      if (products is List) {
        for (final item in products) {
          if (item is Map<String, dynamic>) {
            await DBService.upsertProduct(item);
          } else if (item is Map) {
            await DBService.upsertProduct(
              Map<String, dynamic>.from(item),
            );
          }
        }
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('JSON importado correctamente'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al importar el JSON: $e'),
        ),
      );
    }
  }

  Future<void> _exportProductsCsv(BuildContext context) async {
    try {
      final products = await DBService.getProducts();
      final buffer = StringBuffer();

      buffer.writeln(
        'id;nombre;stock;price_cash;price_transfer',
      );

      for (final product in products) {
        buffer.writeln(
          '${_csvValue(product['id'])};'
          '${_