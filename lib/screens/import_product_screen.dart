import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/db_service.dart';

class ImportProductsScreen extends StatefulWidget {
  const ImportProductsScreen({super.key});

  @override
  State<ImportProductsScreen> createState() => _ImportProductsScreenState();
}

class _ImportProductsScreenState extends State<ImportProductsScreen> {
  String status = 'Seleccione un archivo CSV';

  Future<void> importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;

    if (bytes == null) {
      if (mounted) {
        setState(() => status = 'No se pudieron leer los datos del archivo.');
      }
      return;
    }

    final content = utf8.decode(bytes, allowMalformed: true);
    final lines = const LineSplitter().convert(content);

    var count = 0;

    for (final line in lines.skip(1)) {
      final parts = line.split(',');
      if (parts.length < 4) continue;

      final name = parts[0].trim();
      final stock = int.tryParse(parts[1].trim()) ?? 0;
      final priceCash = double.tryParse(parts[2].trim()) ?? 0.0;
      final priceTransfer = double.tryParse(parts[3].trim()) ?? 0.0;

      await DBService.insertProduct({
        'name': name,
        'stock': stock,
        'price_cash': priceCash,
        'price_transfer': priceTransfer,
      });

      count++;
    }

    if (mounted) {
      setState(() => status = 'Importación completada: $count productos');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar productos CSV')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: importCsv,
              child: const Text('Seleccionar archivo CSV'),
            ),
          ],
        ),
      ),
    );
  }
}