import 'dart:typed_data';

import 'read_path_bytes_io.dart' if (dart.library.html) 'read_path_bytes_stub.dart'
    as path_bytes;

Future<Uint8List> readLocalPathBytes(String path) =>
    path_bytes.readLocalPathBytesImpl(path);
