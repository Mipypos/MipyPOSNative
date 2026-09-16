import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/db_service.dart';

class ProductsScreen extends StatefulWidget { const ProductsScreen({super.key}); @override State<ProductsScreen> createState() => _ProductsScreenState(); }
class _ProductsScreenState extends State<ProductsScreen> {
  List<Map<String, dynamic>> products = [];
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { products = await DBService.getProducts(); if (mounted) setState(() {}); }
  Future<void> _create() async {
    final n = TextEditingController(), s = TextEditingController(text: '0'), c = TextEditingController(text: '0'), t = TextEditingController(text: '0');
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Nuevo producto'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'Nombre')), TextField(controller: s, decoration: const InputDecoration(labelText: 'Stock')), TextField(controller: c, decoration: const InputDecoration(labelText: 'Precio efectivo')), TextField(controller: t, decoration: const InputDecoration(labelText: 'Precio transferencia'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar'))]));
    if (ok == true) { await DBService.insertProduct({'name': n.text.trim(), 'stock': int.tryParse(s.text) ?? 0, 'price_cash': double.tryParse(c.text) ?? 0, 'price_transfer': double.tryParse(t.text) ?? 0, 'foto': ''}); await _load(); }
  }
  Future<void> _import() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    final path = r?.files.single.path; if (path == null) return;
    final lines = await File(path).readAsLines();
    for (final line in lines.skip(1)) { final p = line.split(','); if (p.length >= 4) await DBService.insertProduct({'name': p[0].trim(), 'stock': int.tryParse(p[1].trim()) ?? 0, 'price_cash': double.tryParse(p[2].trim()) ?? 0, 'price_transfer': double.tryParse(p[3].trim()) ?? 0, 'foto': ''}); }
    await _load();
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Productos'), actions: [IconButton(onPressed: _create, icon: const Icon(Icons.add)), IconButton(onPressed: _import, icon: const Icon(Icons.upload_file))]), body: ListView.builder(itemCount: products.length, itemBuilder: (_, i) { final p = products[i]; return ListTile(title: Text('${p['name']}'), subtitle: Text('Stock: ${p['stock']} | Efectivo: ${p['price_cash']} | Transferencia: ${p['price_transfer']}')); }));
}
