import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kresna_laundry/core/app_settings.dart';
import 'package:kresna_laundry/core/theme.dart';
import 'package:kresna_laundry/core/utils.dart';
import 'package:kresna_laundry/models/models.dart';
import 'package:kresna_laundry/services/backup_service.dart';
import 'package:kresna_laundry/services/qris_service.dart';
import 'package:kresna_laundry/services/whatsapp_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  group('Utils', () {
    test('normalizePhone mengubah format nomor lokal & internasional', () {
      expect(normalizePhone('0812-3456-7890'), '6281234567890');
      expect(normalizePhone('+62 812 3456 7890'), '6281234567890');
      expect(normalizePhone('81234567890'), '6281234567890');
      expect(normalizePhone('6281234567890'), '6281234567890');
      expect(normalizePhone(''), isNull);
      expect(normalizePhone('12345'), isNull);
    });

    test('format qty, estimasi (3 hari, 1 hari, 3 jam), dan parseNum', () {
      expect(fmtQty(4.0), '4');
      expect(fmtQty(2.5), '2.5');
      expect(fmtEstimate(72), '3 hari');
      expect(fmtEstimate(24), '1 hari');
      expect(fmtEstimate(3), '3 jam');
      expect(parseNum('2,5'), 2.5);
      expect(parseNum('15000'), 15000);
    });
  });

  group('Model, Perhitungan Tarif & WhatsAppService', () {
    final estDone = DateTime(2026, 11, 23, 10, 0);
    final sample = LaundryOrder(
      id: 1,
      code: 'CGS-261122-001',
      customerName: 'Budi',
      phone: '081234567890',
      date: DateTime(2026, 11, 22),
      itemTypeId: 2,
      itemCode: 'CGS',
      itemName: 'Cuci + Gosok',
      isKiloan: true,
      qty: 4,
      packageId: 2,
      packageName: 'One Day',
      estimateHours: 24,
      estimatedDoneAt: estDone,
      unitPrice: 15000,
      total: 60000,
      workStatus: 2,
      payStatus: 0,
      payMethod: 'Tunai',
    );

    test('LaundryOrder toMap & fromMap menyimpan estimasi selesai dengan benar',
        () {
      final restored = LaundryOrder.fromMap(sample.toMap());
      expect(restored.code, 'CGS-261122-001');
      expect(restored.customerName, 'Budi');
      expect(restored.itemName, 'Cuci + Gosok');
      expect(restored.qtyLabel, '4 kg');
      expect(restored.speedLabel, 'One Day (1 hari)');
      expect(restored.estimatedDoneAt, estDone);
      expect(restored.total, 60000);
      expect(restored.isDone, isTrue);
      expect(restored.isPaid, isFalse);
    });

    test('WhatsAppService.buildMessage memuat semua info layanan & estimasi',
        () {
      final confirm =
          WhatsAppService.buildMessage(WaKind.confirm, sample, 'Kresna Laundry');
      expect(confirm, contains('Budi'));
      expect(confirm, contains('CGS-261122-001'));
      expect(confirm, contains('Cuci + Gosok'));
      expect(confirm, contains('4 kg'));
      expect(confirm, contains('One Day (1 hari)'));
      expect(confirm, contains('23 Nov 2026 10:00'));
      expect(confirm, contains('Rp 60.000'));
      expect(confirm, contains('Belum Lunas'));

      final done =
          WhatsAppService.buildMessage(WaKind.done, sample, 'Kresna Laundry');
      expect(done, contains('selesai dikerjakan'));
      expect(done, contains('siap untuk diambil'));
      expect(done, contains('Cuci + Gosok'));
      expect(done, contains('Budi'));

      final paidOrder = LaundryOrder.fromMap({
        ...sample.toMap(),
        'pay_status': 1,
        'pay_method': 'QRIS',
      });
      final paid =
          WhatsAppService.buildMessage(WaKind.paid, paidOrder, 'Kresna Laundry');
      expect(paid, contains('QRIS'));
      expect(paid, contains('CGS-261122-001'));
    });

    test('AppearanceState & buildTheme mendukung Mode Ramah Orang Tua', () {
      const normal = AppearanceState();
      expect(normal.isSeniorFriendly, isFalse);

      final senior = normal.copyWith(
        fontScale: 1.30,
        paletteId: 'teal',
        themeMode: ThemeMode.dark,
        highContrast: true,
        boldText: true,
        largeButtons: true,
      );
      expect(senior.isSeniorFriendly, isTrue);
      expect(senior.palette.name, 'Hijau Zamrud');
      final lightTheme = buildTheme(senior, brightness: Brightness.light);
      final darkTheme = buildTheme(senior, brightness: Brightness.dark);
      expect(lightTheme.brightness, Brightness.light);
      expect(darkTheme.brightness, Brightness.dark);
    });

    test('QrisService mengubah QRIS statis Kresna Laundry ke dinamis dengan CRC valid',
        () {
      const kresnaStatic =
          '00020101021126570011ID.DANA.WWW011893600915303722287402090372228740303UMI51440014ID.CO.QRIS.WWW0215ID10266448558880303UMI5204899953033605802ID5923Kresna Laundry, Service6014Bandar Lampung61053512263049EC3';
      // Verifikasi CRC asli QRIS Kresna Laundry cocok 100% (9EC3)
      expect(
        QrisService.crc16Ccitt(
            kresnaStatic.substring(0, kresnaStatic.length - 4)),
        '9EC3',
      );
      expect(QrisService.isValid(kresnaStatic), isTrue);
      expect(
          QrisService.parseMerchantName(kresnaStatic), 'Kresna Laundry, Service');
      // Verifikasi hasil salinan dengan tanda kurung/enter tetap valid
      expect(QrisService.isValid('( $kresnaStatic ).'), isTrue);

      final dyn = QrisService.toDynamic(kresnaStatic, 60000);
      expect(dyn, isNotNull);
      expect(dyn!, contains('010212')); // jadi dinamis
      expect(dyn, contains('540560000')); // nominal Rp 60.000
      final body = dyn.substring(0, dyn.length - 4);
      final crc = dyn.substring(dyn.length - 4);
      expect(crc, QrisService.crc16Ccitt(body));

      expect(QrisService.isValid('bukan-qris'), isFalse);
      expect(QrisService.toDynamic('bukan-qris', 60000), isNull);
    });

    test('BackupService encode & decode JSON cadangan valid', () {
      final raw = BackupService.encodeBackup({
        'app': 'kresna_laundry',
        'schema_version': 2,
        'orders': [sample.toMap()],
      });
      final decoded = BackupService.decodeBackup(raw);
      expect(decoded['app'], 'kresna_laundry');
      expect((decoded['orders'] as List).length, 1);

      expect(
        () => BackupService.decodeBackup('{"app":"lain"}'),
        throwsFormatException,
      );
    });
  });
}
