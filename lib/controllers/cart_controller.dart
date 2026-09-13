// Restored CartController from main branch to replace placeholder content.

import 'package:flutter/foundation.dart';
import '../services/db_service.dart';
import '../core/session_manager.dart';
import '../services/sync_service.dart';

class CartItem {
  final int productId;
  final String name;
  int qty;
  double price;

  CartItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.price,
  });

  Map<String, dynamic> toMap(int saleId) {
    return {
      'sale_id': saleId,
      'product_id': productId,
      'name': name,
      'quantity': qty,
      'price': price,
      'subtotal': qty * price,
    };
  }

  dynamic operator [](String key) {
    switch (key) {
      case 'product_id':
      case 'id':
        return productId;
      case 'name':
        return name;
      case 'quantity':
      case 'qty':
        return qty;
      case 'price':
        return price;
      case 'subtotal':
        return qty * price;
      default:
        return null;
    }
  }
}

class CartController extends ChangeNotifier {
  final List<CartItem> items = [];

  // ------------------------------------------------------------
  // AGREGAR PRODUCTO AL CARRITO
  // ------------------------------------------------------------
  void add(Map<String, dynamic> item) {
    final id = item['id'];
    final name = item['name'];
    final price = item['price'];

    for (var i in items) {
      if (i.productId == id) {
        i.qty++;
        notifyListeners();
        return;
      }
    }

    items.add(
      CartItem(
        productId: id,
        name: name,
        qty: 1,
        price: price,
      ),
    );

    notifyListeners();
  }

  // ------------------------------------------------------------
  // REMOVER PRODUCTO POR ID
  // ------------------------------------------------------------
  void remove(int productId) {
    items.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  // ------------------------------------------------------------
  // LIMPIAR CARRITO
  // ------------------------------------------------------------
  void clear() {
    items.clear();
    notifyListeners();
  }

  // ------------------------------------------------------------
  // TOTAL DEL CARRITO
  // ------------------------------------------------------------
  double get total {
    double t = 0;
    for (var i in items) {
      t += i.price * i.qty;
    }
    return t;
  }

  // ------------------------------------------------------------
  // CHECKOUT PROFESIONAL
  // ------------------------------------------------------------
  Future<int> checkout({
    String? method,
    required String user,
    required int sessionId,
    List<Map<String, dynamic>>? payments,
  }) async {
    final saleMethod =
        (payments != null && payments.isNotEmpty) ? 'Mixto' : (method ?? 'Efectivo');
    final totalAmount = total;

    final saleId = await DBService.createSale(
      totalAmount,
      saleMethod,
      user,
      sessionId: sessionId,
      payments: payments,
    );

    // Sincronización P2P
    SyncService().syncSale({
      'total': totalAmount,
      'method': saleMethod,
      'user': user,
      'sessionId': sessionId,
      'payments': payments,
    });

    // Registrar items y descontar stock
    for (var it in items) {
      final itemMap = it.toMap(saleId);
      await DBService.insertSaleItem(itemMap);

      try {
        await DBService.removeStock(it.productId, it.qty);
      } catch (_) {}
    }

    clear();
    return saleId;
  }
}
