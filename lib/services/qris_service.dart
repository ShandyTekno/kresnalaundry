/// Utilitas standar EMVCo / Bank Indonesia QRIS untuk mengubah
/// QRIS Statis (DANA Bisnis, GoPay Merchant, BRI, BCA, Mandiri, dll.)
/// menjadi QRIS Dinamis dengan nominal tagihan otomatis + CRC16-CCITT.
class QrisService {
  /// Membersihkan spasi/tanda kurung/enter yang sering ikut tersalin dari Google Lens.
  static String sanitize(String raw) {
    var s = raw.trim();
    // Hapus tanda kurung/titik di awal/akhir hasil salinan AI Overview.
    s = s.replaceFirst(RegExp(r'^[\(\["\s]+'), '');
    s = s.replaceFirst(RegExp(r'[\)\]\."\s]+$'), '');
    // Hapus enter/baris baru di tengah kode (tetap pertahankan spasi nama merchant).
    s = s.replaceAll(RegExp(r'[\r\n]+'), '');
    return s.trim();
  }

  static bool isValid(String raw) {
    final s = sanitize(raw);
    if (s.length < 24 || !s.startsWith('000201')) return false;
    final tags = _parseTlv(s);
    if (tags == null || tags.isEmpty) return false;
    final hasCountry = tags.any((t) => t.tag == '58');
    final hasMerchant = tags.any((t) => t.tag == '59');
    return hasCountry && hasMerchant;
  }

  static String? parseMerchantName(String raw) {
    final tags = _parseTlv(sanitize(raw));
    if (tags == null) return null;
    for (final t in tags) {
      if (t.tag == '59') return t.value;
    }
    return null;
  }

  /// Mengubah string QRIS Statis menjadi QRIS Dinamis dengan nominal [amount] (Rupiah bulat).
  /// Mengembalikan null jika string QRIS tidak valid.
  static String? toDynamic(String staticQris, int amount) {
    final s = sanitize(staticQris);
    if (amount <= 0) return null;
    final tags = _parseTlv(s);
    if (tags == null || tags.isEmpty || !s.startsWith('000201')) return null;

    final out = <_Tlv>[];
    var insertedAmount = false;
    final amountStr = amount.toString();

    for (final t in tags) {
      if (t.tag == '63') continue; // CRC lama dibuang, akan dihitung ulang
      if (t.tag == '54') continue; // Nominal lama dibuang, diganti baru
      if (t.tag == '01') {
        // 11 = statis, 12 = dinamis
        out.add(const _Tlv('01', '12'));
        continue;
      }
      if (t.tag == '58' && !insertedAmount) {
        out.add(_Tlv('54', amountStr));
        insertedAmount = true;
      }
      out.add(t);
    }
    if (!insertedAmount) {
      out.add(_Tlv('54', amountStr));
    }

    final body = StringBuffer();
    for (final t in out) {
      final len = t.value.length.toString().padLeft(2, '0');
      body.write('${t.tag}$len${t.value}');
    }
    body.write('6304');
    final payload = body.toString();
    final crc = crc16Ccitt(payload);
    return '$payload$crc';
  }

  /// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF), hasil 4 digit hex huruf besar.
  static String crc16Ccitt(String input) {
    var crc = 0xFFFF;
    for (var i = 0; i < input.length; i++) {
      crc ^= (input.codeUnitAt(i) & 0xFF) << 8;
      for (var b = 0; b < 8; b++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  static List<_Tlv>? _parseTlv(String s) {
    final result = <_Tlv>[];
    var i = 0;
    while (i < s.length) {
      if (i + 4 > s.length) return null;
      final tag = s.substring(i, i + 2);
      final len = int.tryParse(s.substring(i + 2, i + 4));
      if (len == null || len < 0 || i + 4 + len > s.length) return null;
      final val = s.substring(i + 4, i + 4 + len);
      result.add(_Tlv(tag, val));
      i += 4 + len;
    }
    return result;
  }
}

class _Tlv {
  final String tag;
  final String value;
  const _Tlv(this.tag, this.value);
}
