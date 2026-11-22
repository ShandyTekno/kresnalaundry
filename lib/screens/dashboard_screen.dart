import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../data/database.dart';
import '../models/models.dart';
import 'app_shell.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      valueListenable: dataVersion,
      builder: (context, _, __) => FutureBuilder<List<Object>>(
        future: Future.wait<Object>([
          AppDb.instance.dashboardStats(),
          AppDb.instance.getOrders(limit: 8),
          AppDb.instance.getSetting('store_name', 'Kresna Laundry'),
        ]),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snap.data![0] as Map<String, num>;
          final recent = snap.data![1] as List<LaundryOrder>;
          final storeName = snap.data![2] as String;

          final countCards = [
            _Stat(
              'Total Pesanan',
              '${stats['total']}',
              Icons.receipt_long,
              cs.primary,
              () => openOrdersWithFilter(),
            ),
            _Stat(
              'Sedang Diproses',
              '${stats['proses']}',
              Icons.autorenew,
              const Color(0xFFEF6C00),
              () => openOrdersWithFilter(work: 1),
            ),
            _Stat(
              'Pesanan Selesai',
              '${stats['selesai']}',
              Icons.check_circle_outline,
              const Color(0xFF2E7D32),
              () => openOrdersWithFilter(work: 2),
            ),
            _Stat(
              'Belum Dibayar',
              '${stats['unpaid']}',
              Icons.money_off,
              const Color(0xFFC62828),
              () => openOrdersWithFilter(pay: 0),
            ),
          ];

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hero Banner Modern (Total Pendapatan + Aksi Cepat)
                  _HeroBanner(
                    storeName: storeName,
                    revenue: fmtRp(stats['revenue']!),
                    onNewOrder: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OrderFormScreen()),
                    ),
                    onAppearance: () => showQuickAppearanceSheet(context),
                  ),
                  const SizedBox(height: 16),

                  // Kartu Statistik Interaktif & Responsif (aman untuk huruf ekstra besar)
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
                          for (final c in countCards)
                            SizedBox(width: cardWidth, child: _StatCard(c)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Pintasan Menu
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final e in const [
                      ('Pesanan', 1, Icons.receipt_long),
                      ('Pelanggan', 2, Icons.people),
                      ('Layanan & Tarif', 3, Icons.local_laundry_service),
                      ('Laporan', 4, Icons.bar_chart),
                    ])
                      ActionChip(
                        avatar: Icon(e.$3, size: 18, color: cs.primary),
                        label: Text(e.$1),
                        onPressed: () => navIndex.value = e.$2,
                      ),
                  ]),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Transaksi Terbaru',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (recent.isNotEmpty)
                        TextButton(
                          onPressed: () => openOrdersWithFilter(),
                          child: const Text('Lihat Semua'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (recent.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Belum ada pesanan. Tekan "Pesanan Baru" untuk mencatat transaksi.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Column(children: [
                        for (var i = 0; i < recent.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _OrderTile(recent[i]),
                        ]
                      ]),
                    ),
                  const SizedBox(height: 88),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final String storeName;
  final String revenue;
  final VoidCallback onNewOrder;
  final VoidCallback onAppearance;

  const _HeroBanner({
    required this.storeName,
    required this.revenue,
    required this.onNewOrder,
    required this.onAppearance,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gradStart = cs.primary;
    final gradEnd = Color.lerp(cs.primary, Colors.black, 0.28)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradStart, gradEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_laundry_service,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Atur Huruf & Tampilan',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.text_fields, size: 19),
                onPressed: onAppearance,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Pendapatan (Lunas)',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        revenue,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: gradStart,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: onNewOrder,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Catat'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _Stat(this.label, this.value, this.icon, this.color, this.onTap);
}

class _StatCard extends StatelessWidget {
  final _Stat s;
  const _StatCard(this.s);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Color.lerp(s.color, Colors.white, 0.3)! : s.color;
    return Card(
      child: InkWell(
        onTap: s.onTap,
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
                child: Icon(s.icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        s.value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    Text(
                      s.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final LaundryOrder o;
  const _OrderTile(this.o);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id!))),
      title: Text('${o.customerName} • ${o.code}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${o.itemName} (${o.qtyLabel}) • ${o.speedLabel}',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              StatusBadge(workLabels[o.workStatus], workColors[o.workStatus]),
              StatusBadge(payLabels[o.payStatus], payColors[o.payStatus]),
            ]),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fmtRp(o.total),
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
