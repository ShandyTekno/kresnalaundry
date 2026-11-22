import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../data/database.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month, now.day));
  }

  Future<void> _pick() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      valueListenable: dataVersion,
      builder: (context, _, __) => FutureBuilder<Map<String, Object>>(
        future: AppDb.instance.report(_range.start, _range.end),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = snap.data!;
          final daily = r['daily'] as List<Map<String, Object?>>;
          final tiles = [
            _tile(context, 'Total Transaksi', '${r['total']}',
                Icons.receipt_long, cs.primary),
            _tile(context, 'Pesanan Selesai', '${r['selesai']}',
                Icons.check_circle_outline, const Color(0xFF2E7D32)),
            _tile(context, 'Belum Dibayar', '${r['unpaid']}', Icons.money_off,
                const Color(0xFFC62828)),
            _tile(context, 'Total Pendapatan', fmtRp(r['revenue'] as num),
                Icons.account_balance_wallet, const Color(0xFF00838F)),
          ];

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  OutlinedButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                        'Periode: ${fmtDate(_range.start)} - ${fmtDate(_range.end)}'),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final cols = w >= 860 ? 4 : 2;
                      const gap = 12.0;
                      final cardWidth = (w - gap * (cols - 1)) / cols;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final t in tiles)
                            SizedBox(width: cardWidth, child: t),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text('Rincian Metode Pembayaran',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: cs.primary)),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(children: [
                      ListTile(
                        leading:
                            Icon(Icons.payments_outlined, color: cs.primary),
                        title: const Text('Tunai'),
                        trailing: Text(fmtRp(r['cash'] as num),
                            style: const TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w700)),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.qr_code_2, color: cs.primary),
                        title: const Text('QRIS'),
                        trailing: Text(fmtRp(r['qris'] as num),
                            style: const TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Text('Rekap Pendapatan per Hari',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: cs.primary)),
                  const SizedBox(height: 8),
                  if (daily.isEmpty)
                    const Card(
                        child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                          child: Text('Belum ada pembayaran pada periode ini.')),
                    ))
                  else
                    Card(
                      child: Column(children: [
                        for (var i = 0; i < daily.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            title: Text(fmtDate(
                                DateTime.parse(daily[i]['d'] as String))),
                            subtitle: Text('${daily[i]['c']} pesanan lunas'),
                            trailing: Text(fmtRp(daily[i]['s'] as num),
                                style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]
                      ]),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Transaksi, selesai, dan belum dibayar dihitung menurut tanggal pesanan. '
                    'Pendapatan dihitung menurut tanggal pembayaran.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, String label, String value, IconData icon,
      Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Color.lerp(color, Colors.white, 0.3)! : color;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
