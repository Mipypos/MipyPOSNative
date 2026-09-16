import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'db_service.dart';

class ExportService {
 static Future<Directory> _dir() async => await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
 static Future<void> _write(String name,List<List<dynamic>> rows) async { final d=await _dir(); await d.create(recursive:true); await File('${d.path}/$name.csv').writeAsString(rows.map((r)=>r.join(',')).join('\n')); final x=Excel.createExcel(); final s=x['Reporte']; for(final r in rows){s.appendRow(r);} await File('${d.path}/$name.xlsx').writeAsBytes(x.encode()!); }
 static Future<void> exportVentasDia() async { final rows=<List<dynamic>>[['ID','Usuario','Método','Total','Fecha']]; for(final v in await DBService.getSalesOfDay()){rows.add([v['id'],v['user'],v['method'],v['total'],v['date']]);} await _write('ventas_dia',rows); }
 static Future<void> exportMovimientosDia() async { final rows=<List<dynamic>>[['Producto','Cantidad','Origen','Destino','Fecha']]; for(final m in await DBService.getMovementsOfDay()){rows.add([m['product_name'],m['qty'],m['from_area'],m['to_area'],m['date']]);} await _write('movimientos_dia',rows); }
 static Future<void> exportInventario() async { final rows=<List<dynamic>>[['Producto','Stock','Efectivo','Transferencia']]; for(final p in await DBService.getProducts()){rows.add([p['name'],p['stock'],p['price_cash'],p['price_transfer']]);} await _write('inventario',rows); }
 static Future<void> exportProductosVendidos() async { final rows=<List<dynamic>>[['Producto','Cantidad','Total']]; final map=<String,List<num>>{}; for(final i in await DBService.getSaleItems()){final n='${i['name']}'; final q=(i['quantity'] as num?)??0; final total=(i['subtotal'] as num?)??q*((i['price'] as num?)??0); map[n]=[(map[n]?.first??0)+q,(map[n]?.last??0)+total];} for(final e in map.entries){rows.add([e.key,e.value[0],e.value[1]]);} await _write('productos_vendidos',rows); }
 static Future<void> exportTodo() async {await exportVentasDia();await exportMovimientosDia();await exportInventario();await exportProductosVendidos();}
}
