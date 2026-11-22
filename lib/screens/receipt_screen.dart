import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../data/database.dart';
import '../models/models.dart';

class ReceiptScreen extends StatefulWidget {
  final LaundryOrder order;
  const ReceiptScreen({super.key, required this.order});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _key = GlobalKey();
  bool _saving = false;
  String _store = 'Kresna Laundry';
  String _address = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    final db = AppDb.instance;
    final n = await db.getSetting('store_name', 'Kresna Laundry');
    final a = await db.getSetting('store_address');
    final p = await db.getSetting('store_phone');
    if (mounted) {
      setState(() {
        _store = n;
        _address = a;
        _phone = p;
      });
    }
  }

  Future<void> _saveJpg() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        if (!await Gal.requestAccess(toAlbum: true)) {
          messenger.showSnackBar(const SnackBar(
              content: Text('Izin penyimpanan galeri ditolak.')));
          return;
        }
      }
      final boundary =
          _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final decoded = img.decodePng(data!.buffer.asUint8List());
      if (decoded == null) throw Exception('Gagal membuat gambar');
      final jpg = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
      await Gal.putImageBytes(
        jpg,
        album: 'Kresna Laundry',
        name: 'nota_${widget.order.code}',
      );
      messenger.showSnackBar(
          const SnackBar(content: Text('Nota JPG tersimpan di galeri.')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Gagal menyimpan nota: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nota Digital')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: RepaintBoundary(
                  key: _key,
                  child: _ReceiptCard(
                    order: widget.order,
                    store: _store,
                    address: _address,
                    phone: _phone,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveJpg,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download),
                    label: const Text('Simpan Nota (JPG) ke Galeri'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final LaundryOrder order;
  final String store;
  final String address;
  final String phone;
  const _ReceiptCard({
    required this.order,
    required this.store,
    required this.address,
    required this.phone,
  });

  Widget _row(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 100,
                child: Text(l,
                    style: const TextStyle(color: Colors.black54, fontSize: 13))),
            Expanded(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                      color: Colors.black87)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Container(
      width: 360,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black87),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(children: [
                const Icon(Icons.local_laundry_service, color: kBlue, size: 34),
                Text(store.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kBlue)),
                if (address.isNotEmpty)
                  Text(address,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12)),
                if (phone.isNotEmpty)
                  Text('Telp/WA: $phone', style: const TextStyle(fontSize: 12)),
              ]),
            ),
            const Divider(height: 24),
            _row('Kode Pesanan', o.code, bold: true),
            _row('Tanggal', fmtDate(o.date)),
            _row('Pelanggan', o.customerName),
            _row('No. WhatsApp', o.phone.isEmpty ? '-' : o.phone),
            const Divider(height: 24),
            _row('Jenis Layanan', o.itemName, bold: true),
            _row('Waktu Pengerjaan', o.speedLabel),
            _row(o.isKiloan ? 'Berat' : 'Jumlah', o.qtyLabel),
            _row('Tarif', '${fmtRp(o.unitPrice)} / ${o.isKiloan ? 'kg' : 'pcs'}'),
            _row('Estimasi Selesai', o.estimatedDoneLabel),
            if (o.notes.isNotEmpty) _row('Catatan', o.notes),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text(fmtRp(o.total),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kBlue)),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                o.isPaid
                    ? 'LUNAS (${o.payMethod ?? '-'})'
                    : 'BELUM LUNAS',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: payColors[o.payStatus]),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: QrImageView(
                data: 'KRESNA-LAUNDRY|${o.code}|${o.customerName}|${o.total.toInt()}',
                size: 120,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Center(
                child: Text(o.code, style: const TextStyle(fontSize: 12))),
            const SizedBox(height: 10),
            const Center(
              child: Text('Terima kasih atas kepercayaan Anda',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }
}
