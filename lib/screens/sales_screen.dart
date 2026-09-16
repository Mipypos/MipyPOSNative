import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/cart_controller.dart';
import '../controllers/auth_controller.dart';
import '../core/session_manager.dart';
import '../services/db_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Map<String,dynamic>> products = [];
  bool loading = true;
  String method = 'Efectivo';
  final search = TextEditingController();
  @override void initState() { super.initState(); search.addListener(() => setState(() {})); _load(); }
  @override void dispose() { search.dispose(); super.dispose(); }
  Future<void> _load() async { try { products = await DBService.getProducts(); } finally { if (mounted) setState(() => loading=false); } }
  @override Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final session = context.watch<SessionManager>();
    final q = search.text.toLowerCase();
    final shown = products.where((p) => '${p['name']}'.toLowerCase().contains(q)).toList();
    return Scaffold(appBar: AppBar(title: const Text('Ventas'), actions:[IconButton(onPressed:_load, icon:const Icon(Icons.refresh))]), body: loading ? const Center(child:CircularProgressIndicator()) : Row(children:[
      Expanded(child: Column(children:[Padding(padding:const EdgeInsets.all(8), child:TextField(controller:search, decoration:const InputDecoration(labelText:'Buscar producto', prefixIcon:Icon(Icons.search)))), Expanded(child:GridView.builder(gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2, childAspectRatio:2.2), itemCount:shown.length, itemBuilder:(_,i){final p=shown[i]; final stock=int.tryParse('${p['stock']}')??0; final price=method=='Efectivo' ? (p['price_cash']??0) : (p['price_transfer']??0); return Card(child:ListTile(title:Text('${p['name']}'), subtitle:Text('Stock: $stock  Precio: \$${price}'), trailing:IconButton(icon:const Icon(Icons.add_shopping_cart), onPressed:stock>0?()=>cart.add({'id':p['id'],'name':p['name'],'price':price is num?(price as num).toDouble():double.tryParse('$price')??0}):null)));}))])),
      SizedBox(width:330, child:Padding(padding:const EdgeInsets.all(12), child:Column(children:[DropdownButton<String>(value:method, isExpanded:true, items:['Efectivo','Tarjeta','Transferencia'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(), onChanged:(x)=>setState(()=>method=x!)), Expanded(child:ListView(children:cart.items.map((x)=>ListTile(title:Text(x.name), trailing:Text('${x.qty} x \$${x.price}'))).toList())), Text('Total: \$${cart.total.toStringAsFixed(2)}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)), const SizedBox(height:12), FilledButton.icon(onPressed:session.isOpen&&cart.items.isNotEmpty?() async { try { await cart.checkout(method:method,user:context.read<AuthController>().user?['user']??'desconocido',sessionId:session.sessionId!); if(mounted){await _load(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Venta registrada')));}} catch(e){if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Error: $e')));}}, icon:const Icon(Icons.payment), label:const Text('COBRAR'))]))),
    ]));
  }
}
