class ExportService {
  Future<void> exportPdf(Map<String, dynamic> data) async {
    await Future.delayed(const Duration(seconds: 1));
    print('Exported PDF for data: $data');
  }
}
