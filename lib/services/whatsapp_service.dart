import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils.dart';
import '../data/database.dart';
import '../models/models.dart';

enum WaKind { confirm, done, paid }

class WhatsAppService {
  static String buildMessage(WaKind kind, LaundryOrder o, String store) {
    final upperStore = store.toUpperCase();
    const line = '────────────────────────';
    switch (kind) {
      case WaKind.confirm:
        return '*KONFIRMASI PESANAN — $upperStore*\n'
            '$line\n\n'
            'Halo Kak *${o.customerName}*,\n'
            'Terima kasih telah mempercayakan cucian Kakak kepada kami. Pesanan Kakak telah resmi kami catat dengan rincian berikut:\n\n'
            '• Kode Pesanan : *${o.code}*\n'
            '• Jenis Layanan : ${o.itemName}\n'
            '• Berat Cucian : ${o.qtyLabel}\n'
            '• Waktu Pengerjaan : ${o.speedLabel}\n'
            '• Estimasi Selesai : ${o.estimatedDoneLabel}\n'
            '• Total Biaya : *${fmtRp(o.total)}*\n'
            '• Status Pembayaran : ${payLabels[o.payStatus]}\n\n'
            '$line\n'
            'Cucian Kakak akan segera kami proses dengan bersih, rapi, dan wangi. Terima kasih atas kepercayaannya.';
      case WaKind.done:
        return '*PESANAN SIAP DIAMBIL — $upperStore*\n'
            '$line\n\n'
            'Halo Kak *${o.customerName}*,\n'
            'Kami informasikan bahwa cucian Kakak sudah selesai dikerjakan dan siap untuk diambil.\n\n'
            '• Kode Pesanan : *${o.code}*\n'
            '• Jenis Layanan : ${o.itemName} (${o.qtyLabel})\n'
            '• Waktu Pengerjaan : ${o.speedLabel}\n'
            '• Total Biaya : *${fmtRp(o.total)}*\n'
            '• Status Pembayaran : ${payLabels[o.payStatus]}\n\n'
            '$line\n'
            'Silakan datang ke *$store* untuk pengambilan cucian. Terima kasih telah menggunakan layanan kami.';
      case WaKind.paid:
        return '*BUKTI PEMBAYARAN — $upperStore*\n'
            '$line\n\n'
            'Halo Kak *${o.customerName}*,\n'
            'Pembayaran laundry Kakak telah berhasil kami terima.\n\n'
            '• Kode Pesanan : *${o.code}*\n'
            '• Jenis Layanan : ${o.itemName} (${o.qtyLabel})\n'
            '• Waktu Pengerjaan : ${o.speedLabel}\n'
            '• Total Pembayaran : *${fmtRp(o.total)}*\n'
            '• Metode Pembayaran : ${o.payMethod ?? '-'}\n'
            '• Status : *LUNAS*\n\n'
            '$line\n'
            'Terima kasih atas pembayaran dan kepercayaan Kakak. Sampai jumpa di pesanan berikutnya.';
    }
  }

  /// Tampilkan pesan yang bisa diedit, lalu buka WhatsApp (wa.me).
  /// Admin tetap menekan tombol Kirim sendiri di WhatsApp.
  static Future<void> compose(
      BuildContext context, WaKind kind, LaundryOrder o) async {
    final messenger = ScaffoldMessenger.of(context);
    final phone = normalizePhone(o.phone);
    if (phone == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Nomor WhatsApp belum tersedia atau tidak valid. Ubah pesanan untuk melengkapinya.'),
      ));
      return;
    }
    final store = await AppDb.instance.getSetting('store_name', 'Kresna Laundry');
    if (!context.mounted) return;

    final title = switch (kind) {
      WaKind.confirm => 'Konfirmasi Pesanan',
      WaKind.done => 'Laundry Selesai',
      WaKind.paid => 'Pembayaran Berhasil',
    };

    final text = await showDialog<String>(
      context: context,
      builder: (_) => _WaComposeDialog(
        title: title,
        phone: phone,
        customerName: o.customerName,
        initialText: buildMessage(kind, o, store),
      ),
    );
    if (text == null || text.trim().isEmpty) return;

    final uri =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Tidak dapat membuka WhatsApp di perangkat ini.')));
    }
  }
}

class _WaComposeDialog extends StatefulWidget {
  final String title;
  final String phone;
  final String customerName;
  final String initialText;

  const _WaComposeDialog({
    required this.title,
    required this.phone,
    required this.customerName,
    required this.initialText,
  });

  @override
  State<_WaComposeDialog> createState() => _WaComposeDialogState();
}

class _WaComposeDialogState extends State<_WaComposeDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('WhatsApp: ${widget.title}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ke: +${widget.phone} (${widget.customerName})',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text(
                'Pesan dapat diedit. Anda tetap menekan tombol Kirim di WhatsApp.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(controller: _ctrl, maxLines: 12, minLines: 6),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          icon: const Icon(Icons.chat),
          label: const Text('Buka WhatsApp'),
        ),
      ],
    );
  }
}
