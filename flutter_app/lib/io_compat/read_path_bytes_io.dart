import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readLocalPathBytesImpl(String path) =>
    File(path).readAsBytes();
