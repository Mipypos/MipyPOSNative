import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../services/db_service.dart';

class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key});

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  List<Map<String, dynamic>> areas = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> movements = [];
  bool loading = true;
  int? selectedAreaId;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    setState(() => loading = true);

    areas = await DBService.getAreas();
    products = await DBService.getProducts();
    movements = await DBService.getMovementsOfDay();

    if (selectedAreaId != null &&
        !areas.any((area) => area['id'] == selectedAreaId)) {
      selectedAreaId = null;
    }

    if (mounted) setState(() => loading = false);
  }

  void crearArea() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Crear área'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nombre del área'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              await DBService.addArea(name);
              if (!context.mounted) return;
              Navigator.pop(context);
              await cargarDatos();
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void moverProducto() {
    final auth = context.read<AuthController>();

    if (auth.user?['role'] != 'storekeeper') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo el almacenista puede enviar productos')),
      );
      return;
    }

    int? productoId;
    int? fromArea;
    int? toArea;
    final qtyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mover producto entre áreas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Producto'),
              items: products.map((p) {
                return DropdownMenuItem<int>(
                  value: p['id'] as int,
                  child: Text(p['name'] ?? ''),
                );
              }).toList(),
              onChanged: (v) => productoId = v,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Desde área'),
              items: areas.map((a) {
                return DropdownMenuItem<int>(
                  value: a['id'] as int,
                  child: Text(a['name'] ?? ''),
                );
              }).toList(),
              onChanged: (v) => fromArea = v,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Hacia área'),
              items: areas.map((a) {
                return DropdownMenuItem<int>(
                  value: a['id'] as int,
                  child: Text(a['name'] ?? ''),
                );
              }).toList(),
              onChanged: (v) => toArea = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (productoId == null || fromArea == null || toArea == null) return;

              await DBService.createMovement(
                productIndex: productoId!,
                fromAreaId: fromArea!,
                toAreaId: toArea!,
                qty: int.tryParse(qtyCtrl.text) ?? 0,
                fromUser: auth.user?['user'] ?? 'almacenista',
                toUser: 'pendiente',
                confirmedBySeller: false,
              );

              if (!context.mounted) return;
              Navigator.pop(context);
              await cargarDatos();
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void confirmarMovimiento(Map<String, dynamic> mov) async {
    final auth = context.read<AuthController>();

    if (auth.user?['role'] != 'seller') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo el cajero puede confirmar entradas')),
      );
      return;
    }

    await DBService.createMovement(
      productIndex: mov['product_index'],
      fromAreaId: mov['from_area'],
      toAreaId: mov['to_area'],
      qty: mov['qty'],
      fromUser: mov['from_user'],
      toUser: auth.user?['user'] ?? 'cajero',
      confirmedBySeller: true,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrada confirmada')),
    );

    await cargarDatos();
  }

  List<Map<String, dynamic>> get filteredMovements {
    if (selectedAreaId == null) return movements;
    return movements.where((movement) {
      return movement['from_area'] == selectedAreaId ||
          movement['to_area'] == selectedAreaId;
    }).toList();
  }

  String areaName(dynamic id) {
    final area = areas.where((item) => item['id'] == id).firstOrNull;
    return area?['name']?.toString() ?? 'Área desconocida';
  }

  String productName(dynamic id) {
    final product = products.where((item) => item['id'] == id).firstOrNull;
    return product?['name']?.toString() ?? 'Producto desconocido';
  }

  void selectArea(int? areaId) {
    setState(() => selectedAreaId = areaId);
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _buildAreasDrawer(AuthController auth) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.warehouse, color: Colors.white, size: 28),
                    SizedBox(height: 8),
                    Text(
                      'Áreas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Todas las áreas'),
              selected: selectedAreaId == null,
              onTap: () => selectArea(null),
            ),
            const Divider(),
            Expanded(
              child: areas.isEmpty
                  ? const Center(child: Text('No hay áreas registradas'))
                  : ListView.builder(
                      itemCount: areas.length,
                      itemBuilder: (_, index) {
                        final area = areas[index];
                        final id = area['id'] as int?;
                        return ListTile(
                          leading: const Icon(Icons.home_work_outlined),
                          title: Text(area['name']?.toString() ?? 'Sin nombre'),
                          selected: selectedAreaId == id,
                          trailing: selectedAreaId == id ? const Icon(Icons.check) : null,
                          onTap: () => selectArea(id),
                        );
                      },
                    ),
            ),
            const Divider(),
            if (auth.isAdmin)
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Crear área'),
                onTap: () {
                  Navigator.pop(context);
                  crearArea();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final visibleMovements = filteredMovements;

    return Scaffold(
      drawer: _buildAreasDrawer(auth),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Mostrar áreas',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          selectedAreaId == null
              ? 'Áreas e Inventarios'
              : areaName(selectedAreaId),
        ),
        actions: [
          if (auth.user?['role'] == 'storekeeper')
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Mover producto',
              onPressed: moverProducto,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: cargarDatos,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : visibleMovements.isEmpty
              ? const Center(child: Text('No hay movimientos para esta área'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: visibleMovements.length,
                  itemBuilder: (_, index) {
                    final movement = visibleMovements[index];
                    final confirmed = movement['confirmed_by_seller'] == true;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.swap_horiz),
                        title: Text(
                          '${productName(movement['product_index'])} (${movement['qty']})',
                        ),
                        subtitle: Text(
                          'De: ${areaName(movement['from_area'])} → '
                          'A: ${areaName(movement['to_area'])}\n'
                          'Enviado por: ${movement['from_user']}\n'
                          'Confirmado: ${confirmed ? 'Sí' : 'No'}',
                        ),
                        trailing: (!confirmed && auth.user?['role'] == 'seller')
                            ? ElevatedButton(
                                onPressed: () => confirmarMovimiento(movement),
                                child: const Text('Confirmar'),
                              )
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}
