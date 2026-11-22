import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../core/app_settings.dart';
import '../data/database.dart';

class BackupService {
  static String encodeBackup(Map<String, Object?> map) =>
      const JsonEncoder.withIndent('  ').convert(map);

  static Map<String, dynamic> decodeBackup(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic> ||
        decoded['app'] != 'kresna_laundry') {
      throw const FormatException('File bukan cadangan Kresna Laundry.');
    }
    return decoded;
  }

  /// Mengekspor seluruh database ke file JSON lalu membuka menu bagikan
  /// Android/iOS agar admin bisa langsung memilih "Google Drive" (atau WhatsApp).
  static Future<DateTime> backupToDrive() async {
    final now = DateTime.now();
    final map = await AppDb.instance.exportBackupMap();
    final content = encodeBackup(map);
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(now);
    final fileName = 'kresna_laundry_backup_$stamp.json';
    final file = File(p.join(Directory.systemTemp.path, fileName));
    await file.writeAsString(content, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Cadangan Data Kresna Laundry ($stamp)',
        text: 'File cadangan database Kresna Laundry. Simpan ke Google Drive Anda agar data aman.',
      ),
    );

    await AppDb.instance.setSetting('last_backup_at', now.toIso8601String());
    return now;
  }

  /// Memilih file JSON cadangan (bisa langsung dari Google Drive di pemilih file HP)
  /// dan memulihkan seluruh data ke SQLite lokal.
  /// Mengembalikan jumlah pesanan yang dipulihkan, atau null jika dibatalkan.
  static Future<int?> restoreFromFile() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked.isEmpty) return null;

    final pf = picked.first;
    final path = pf.path;
    if (path == null) {
      throw const FormatException('Gagal membaca file cadangan.');
    }
    final raw = await File(path).readAsString();

    final map = decodeBackup(raw);
    final count = await AppDb.instance.importBackupMap(map);
    await AppAppearance.instance.load();
    return count;
  }
}
