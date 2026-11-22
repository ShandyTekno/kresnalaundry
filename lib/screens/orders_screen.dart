import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../data/database.dart';
import '../models/models.dart';
import 'app_shell.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _search = TextEditingController();
  DateTimeRange? _range;
  int? _work;
  int? _pay;

  @override
  void initState() {
    super.initState();
    quickOrderFilter.addListener(_onQuickFilter);
  }

  void _onQuickFilter() {
    final f = quickOrderFilter.value;
    if (f == null || !mounted) return;
    setState(() {
      _work = f.work;
      _pay = f.pay;
      _range = null;
      _search.clear();
    });
    quickOrderFilter.value = null;
  }

  @override
  void dispose() {
    quickOrderFilter.removeListener(_onQuickFilter);
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Cari nama pelanggan atau kode pesanan',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(_search.clear)),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            InputChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: Text(_range == null
                  ? 'Semua tanggal'
                  : '${fmtDate(_range!.start)} - ${fmtDate(_range!.end)}'),
              onPressed: _pickRange,
              onDeleted:
                  _range == null ? null : () => setState(() => _range = null),
            ),
            const SizedBox(width: 8),
            _dropdown('Pengerjaan', workLabels, _work,
                (v) => setState(() => _work = v)),
            const SizedBox(width: 8),
            _dropdown(
                'Pembayaran', payLabels, _pay, (v) => setState(() => _pay = v)),
          ]),
        ),
      ]),
    );
  }

  Widget _dropdown(String hint, List<String> labels, int? value,
      ValueChanged<int?> onChanged) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          hint: Text(hint),
          isDense: true,
          items: [
            DropdownMenuItem<int?>(value: null, child: Text('Semua $hint')),
            for (var i = 0; i < labels.length; i++)
              DropdownMenuItem<int?>(value: i, child: Text(labels[i])),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _open(LaundryOrder o) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id!)));

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _filters(),
      Expanded(
        child: ValueListenableBuilder<int>(
          valueListenable: dataVersion,
          builder: (context, _, __) => FutureBuilder<List<LaundryOrder>>(
            future: AppDb.instance.getOrders(
              query: _search.text,
              from: _range?.start,
              to: _range?.end,
              work: _work,
              pay: _pay,
            ),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data!;
              if (list.isEmpty) {
                return const Center(child: Text('Tidak ada pesanan ditemukan.'));
              }
              final wide = MediaQuery.of(context).size.width >= 800;
              return wide ? _table(list) : _cards(list);
            },
          ),
        ),
      ),
    ]);
  }

  Widget _cards(List<LaundryOrder> list) {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final o = list[i];
        final accent = workColors[o.workStatus];
        return Card(
          child: InkWell(
            onTap: () => _open(o),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(o.customerName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16)),
                                    const SizedBox(height: 2),
                                    Text('${o.code} • ${fmtDate(o.date)}',
                                        style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(fmtRp(o.total),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: cs.primary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${o.itemName} (${o.qtyLabel}) • ${o.speedLabel}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (o.estimatedDoneAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Row(
                                children: [
                                  Icon(Icons.schedule,
                                      size: 14, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'Estimasi selesai: ${fmtDateTime(o.estimatedDoneAt!)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            StatusBadge(workLabels[o.workStatus],
                                workColors[o.workStatus]),
                            StatusBadge(
                                payLabels[o.payStatus], payColors[o.payStatus]),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _table(List<LaundryOrder> list) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      child: Card(
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
              columns: const [
                DataColumn(label: Text('Kode')),
                DataColumn(label: Text('Tanggal')),
                DataColumn(label: Text('Pelanggan')),
                DataColumn(label: Text('Layanan')),
                DataColumn(label: Text('Waktu Pengerjaan')),
                DataColumn(label: Text('Estimasi Selesai')),
                DataColumn(label: Text('Total'), numeric: true),
                DataColumn(label: Text('Pengerjaan')),
                DataColumn(label: Text('Pembayaran')),
              ],
              rows: [
                for (final o in list)
                  DataRow(
                    onSelectChanged: (_) => _open(o),
                    cells: [
                      DataCell(Text(o.code)),
                      DataCell(Text(fmtDate(o.date))),
                      DataCell(Text(o.customerName)),
                      DataCell(Text('${o.itemName} (${o.qtyLabel})')),
                      DataCell(Text(o.speedLabel)),
                      DataCell(Text(o.estimatedDoneLabel)),
                      DataCell(Text(fmtRp(o.total))),
                      DataCell(StatusBadge(
                          workLabels[o.workStatus], workColors[o.workStatus])),
                      DataCell(StatusBadge(
                          payLabels[o.payStatus], payColors[o.payStatus])),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
