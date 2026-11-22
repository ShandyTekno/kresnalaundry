import 'package:intl/intl.dart';

final NumberFormat _rupiah =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

String fmtRp(num v) => _rupiah.format(v);

String fmtDate(DateTime d) => DateFormat('dd MMM yyyy', 'id_ID').format(d);

String fmtDateTime(DateTime d) =>
    DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(d);

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String fmtQty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toString();

String fmtEstimate(int hours) {
  if (hours >= 24 && hours % 24 == 0) return '${hours ~/ 24} hari';
  return '$hours jam';
}

/// Mengubah nomor lokal (08xx / 8xx / +62xx / 62xx) ke format internasional
/// tanpa tanda plus, sesuai kebutuhan URL wa.me. Mengembalikan null jika kosong
/// atau tidak valid.
String? normalizePhone(String? raw) {
  if (raw == null) return null;
  var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('62')) {
    // sudah internasional
  } else if (d.startsWith('0')) {
    d = '62${d.substring(1)}';
  } else if (d.startsWith('8')) {
    d = '62$d';
  }
  if (d.length < 10 || d.length > 15) return null;
  return d;
}

double parseNum(String s) =>
    double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;
