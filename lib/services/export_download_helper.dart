import 'export_download_helper_stub.dart'
    if (dart.library.html) 'export_download_helper_web.dart';

Future<void> saveBytesAsDownload({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) {
  return saveBytesAsDownloadImpl(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
  );
}
