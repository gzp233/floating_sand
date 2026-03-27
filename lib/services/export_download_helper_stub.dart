Future<void> saveBytesAsDownloadImpl({
  required List<int> bytes,
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('当前平台不支持浏览器下载');
}
