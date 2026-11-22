import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../data/database.dart';
import '../models/models.dart';
import '../services/qris_service.dart';
import '../services/whatsapp_service.dart';
import 'order_form_screen.dart';
import 'receipt_screen.dart';
import 'settings_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: dataVersion,
      builder: (context, _, __) => FutureBuilder<LaundryOrder?>(
        future: AppDb.instance.getOrder(orderId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return Scaffold(
                appBar: AppBar(title: const Text('Detail Pesanan')),
                body: const Center(child: CircularProgressIndicator()));
          }
          final o = snap.data;
          if (o == null) {
            return Scaffold(
                appBar: AppBar(title: const Text('Detail Pesanan')),
                body: const Center(child: Text('Pesanan tidak ditemukan.')));
          }
          return _Body(order: o);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final LaundryOrder order;
  const _Body({required this.order});

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus pesanan?'),
        content: Text('Pesanan ${order.code} atas nama ${order.customerName} '
            'akan dihapus permanen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) {
      await AppDb.instance.deleteOrder(order.id!);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _showQrisFullscreen(BuildContext context) async {
    final rawQris = await AppDb.instance.getSetting('qris_static');
    if (!context.mounted) return;
    final dynamicQris = QrisService.toDynamic(rawQris, order.total.round());
    final merchant = QrisService.parseMerchantName(rawQris);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bayar dengan QRIS', textAlign: TextAlign.center),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fmtRp(order.total),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
                Text(
                  '${order.customerName} • ${order.code}',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                if (dynamicQris != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        if (merchant != null && merchant.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              merchant,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        QrImageView(
                          data: dynamicQris,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'QRIS Dinamis — Nominal otomatis terisi\n(DANA / GoPay / OVO / m-Banking)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.qr_code_2, size: 48),
                        const SizedBox(height: 8),
                        const Text(
                          'Kode QRIS DANA Bisnis / Bank belum diatur.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Masukkan kode QRIS statis Anda 1 kali di menu Pengaturan agar barcode otomatis sesuai nominal tagihan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen()),
                            );
                          },
                          icon: const Icon(Icons.settings),
                          label: const Text('Atur QRIS Sekarang'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          if (!order.isPaid && dynamicQris != null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF15803D),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await AppDb.instance
                    .markPaid(order.id!, 'QRIS', DateTime.now());
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Dana Masuk, Lunas'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmPayment(BuildContext context,
      {String? initialMethod}) async {
    final rawQris = await AppDb.instance.getSetting('qris_static');
    if (!context.mounted) return;
    final dynamicQris = QrisService.toDynamic(rawQris, order.total.round());
    final merchant = QrisService.parseMerchantName(rawQris);

    String method = initialMethod ??
        (payMethods.contains(order.payMethod) ? order.payMethod! : 'Tunai');
    DateTime paidAt = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Konfirmasi Pembayaran'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total tagihan'),
                  Text(fmtRp(order.total),
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(ctx).colorScheme.primary)),
                  const SizedBox(height: 14),
                  const Text('Metode pembayaran',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: [
                        for (final m in payMethods)
                          ButtonSegment(
                              value: m,
                              label: Text(m),
                              icon: Icon(m == 'QRIS'
                                  ? Icons.qr_code_2
                                  : Icons.payments_outlined)),
                      ],
                      selected: {method},
                      onSelectionChanged: (s) => setS(() => method = s.first),
                    ),
                  ),
                  if (method == 'QRIS') ...[
                    const SizedBox(height: 12),
                    if (dynamicQris != null)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              if (merchant != null && merchant.isNotEmpty)
                                Text(
                                  merchant,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              QrImageView(
                                data: dynamicQris,
                                size: 170,
                                backgroundColor: Colors.white,
                              ),
                              const Text(
                                'Scan QRIS — nominal terisi otomatis.\nPastikan dana sudah masuk sebelum klik Lunas.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11.5, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Barcode QRIS belum diatur di Pengaturan. Pastikan dana QRIS sudah masuk sebelum konfirmasi, atau atur kode QRIS sekarang.',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx, false);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const SettingsScreen()),
                                );
                              },
                              icon: const Icon(Icons.settings, size: 18),
                              label: const Text('Atur Kode QRIS'),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text('Tanggal bayar: ${fmtDate(paidAt)}'),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: paidAt,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d != null) {
                        final n = DateTime.now();
                        setS(() => paidAt =
                            DateTime(d.year, d.month, d.day, n.hour, n.minute));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF15803D),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check_circle),
                label: const Text('Konfirmasi Lunas')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await AppDb.instance.markPaid(order.id!, method, paidAt);
    }
  }

  Future<void> _undoPayment(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan status Lunas?'),
        content: const Text(
            'Status pembayaran kembali menjadi Belum Lunas dan data pembayaran dihapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Tidak')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ya, batalkan')),
        ],
      ),
    );
    if (ok == true) await AppDb.instance.markUnpaid(order.id!);
  }

  Widget _card(BuildContext context, String title, List<Widget> children) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 15)),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );

  Widget _row(BuildContext context, String l, String v, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 120,
              child: Text(l,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(
              child: Text(v,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final o = order;
    return Scaffold(
      appBar: AppBar(
        title: Text(o.code),
        actions: [
          IconButton(
            tooltip: 'Ubah',
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => OrderFormScreen(order: o))),
          ),
          IconButton(
            tooltip: 'Hapus',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      bottomNavigationBar: o.isPaid
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showQrisFullscreen(context),
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('QRIS'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF15803D),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () => _confirmPayment(context),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(
                          'Konfirmasi Pembayaran • ${fmtRp(o.total)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card(context, 'Informasi Pesanan', [
                _row(context, 'Pelanggan', o.customerName, bold: true),
                _row(context, 'WhatsApp', o.phone.isEmpty ? '-' : o.phone),
                _row(context, 'Tanggal', fmtDate(o.date)),
                _row(context, 'Jenis Layanan', o.itemName, bold: true),
                _row(context, 'Waktu Pengerjaan', o.speedLabel),
                _row(context, 'Estimasi Selesai', o.estimatedDoneLabel),
                _row(context, o.isKiloan ? 'Berat' : 'Jumlah', o.qtyLabel),
                _row(context, 'Tarif',
                    '${fmtRp(o.unitPrice)} / ${o.isKiloan ? 'kg' : 'pcs'}'),
                _row(context, 'Total Biaya', fmtRp(o.total), bold: true),
                if (o.notes.isNotEmpty) _row(context, 'Catatan', o.notes),
              ]),
              const SizedBox(height: 12),
              _card(context, 'Status Pengerjaan', [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var i = 0; i < workLabels.length; i++)
                    ChoiceChip(
                      label: Text(workLabels[i]),
                      selected: o.workStatus == i,
                      selectedColor: workColors[i].withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                          color: o.workStatus == i ? workColors[i] : null,
                          fontWeight: FontWeight.w600),
                      onSelected: (_) =>
                          AppDb.instance.setWorkStatus(o.id!, i),
                    ),
                ]),
              ]),
              const SizedBox(height: 12),
              _card(context, 'Pembayaran', [
                Row(children: [
                  StatusBadge(payLabels[o.payStatus], payColors[o.payStatus]),
                  const Spacer(),
                  Text(fmtRp(o.total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 20)),
                ]),
                if (o.isPaid) ...[
                  const SizedBox(height: 8),
                  _row(context, 'Metode', o.payMethod ?? '-'),
                  _row(context, 'Tanggal bayar',
                      o.paidAt == null ? '-' : fmtDateTime(o.paidAt!)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _undoPayment(context),
                      icon: const Icon(Icons.undo),
                      label: const Text('Batalkan Lunas'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: () => _confirmPayment(context),
                      icon: const Icon(Icons.check_circle_rounded, size: 22),
                      label: const Text(
                        'Konfirmasi Pembayaran',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showQrisFullscreen(context),
                      icon: const Icon(Icons.qr_code_2),
                      label: Text('Tampilkan Barcode QRIS (${fmtRp(o.total)})'),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 12),
              _card(context, 'Pemberitahuan WhatsApp', [
                if (o.phone.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Nomor WhatsApp belum tersedia. Ubah pesanan untuk menambahkannya.',
                      style: TextStyle(color: Color(0xFFC62828)),
                    ),
                  ),
                _waButton(context, 'Konfirmasi Pesanan', WaKind.confirm, true,
                    null),
                _waButton(context, 'Laundry Selesai', WaKind.done, o.isDone,
                    'Tersedia setelah status pengerjaan Selesai'),
                _waButton(context, 'Pembayaran Berhasil', WaKind.paid,
                    o.isPaid, 'Tersedia setelah status pembayaran Lunas'),
              ]),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ReceiptScreen(order: o))),
                icon: const Icon(Icons.receipt),
                label: const Text('Lihat Nota Digital'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _waButton(BuildContext context, String label, WaKind kind,
      bool enabled, String? hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1FA855),
                foregroundColor: Colors.white),
            onPressed: enabled
                ? () => WhatsAppService.compose(context, kind, order)
                : null,
            icon: const Icon(Icons.chat),
            label: Text(label),
          ),
        ),
        if (!enabled && hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Text(hint,
                style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
      ]),
    );
  }
}
