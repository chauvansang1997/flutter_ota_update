import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  static Future<File> getFileFromAsset(String assetPath) async {
    final byteData = await rootBundle.load('assets/$assetPath');
    // final tempDir = await getTemporaryDirectory();
    // final unzippedDir = Directory(path.join(tempDir.path, 'efoil'));
    // if (unzippedDir.existsSync()) {
    //   unzippedDir.deleteSync(recursive: true);
    // }
    String fileName = path.basename(assetPath);

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$fileName';

    // Write the file
    final file = File(filePath);
    if (file.existsSync()) {
      file.deleteSync();
    }

    file.createSync();
    await file.writeAsBytes(byteData.buffer.asUint8List());

    // unzippedDir.createSync();
    // final file = File('${unzippedDir.path}/abc.bin');
    // if (file.existsSync()) {
    //   file.deleteSync();
    // }
    // file.createSync();
    // file.writeAsBytes(byteData.buffer
    //     .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    // final length = await file.length();
    return file;
  }
}
