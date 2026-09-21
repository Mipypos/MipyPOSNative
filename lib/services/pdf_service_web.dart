import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PdfService {
  static Future<void> generateTicket(Uint8List bytes) async {
    if (kIsWeb) {
      return;
    }

    final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
    final file = File('${dir.path}/ticket.pdf');

    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }
}