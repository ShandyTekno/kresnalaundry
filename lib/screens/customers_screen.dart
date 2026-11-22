import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../data/database.dart';
import '../models/models.dart';
import 'order_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Cari nama atau nomor pelanggan',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      Expanded(
        child: ValueListenableBuilder<int>(
          valueListenable: dataVersion,
          builder: (context, _, __) =>
              FutureBuilder<List<Map<String, Object?>>>(
            future: AppDb.instance.getCustomers(query: _search.text),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data!;
              if (list.isEmpty) {
                return const Center(
                    child: Text('Belum ada data pelanggan.\nData terbentuk dari pesanan.',
                        textAlign: TextAlign.center));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c = list[i];
                  final name = c['customer_name'] as String;
                  final phone = c['phone'] as String;
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CustomerOrdersScreen(
                                  name: name, phone: phone))),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.14),
                        child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800)),
                      ),
                      title: Text(name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${phone.isEmpty ? 'Tanpa nomor WhatsApp' : phone}\n'
                          '${c['cnt']} pesanan • terakhir ${fmtDate(DateTime.parse(c['last_date'] as String))}'),
                      isThreeLine: true,
                      trailing: Text(fmtRp((c['spent'] as num?) ?? 0),
                          style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ]);
  }
}

class CustomerOrdersScreen extends StatelessWidget {
  final String name;
  final String phone;
  const CustomerOrdersScreen(
      {super.key, required this.name, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ValueListenableBuilder<int>(
        valueListenable: dataVersion,
        builder: (context, _, __) => FutureBuilder<List<LaundryOrder>>(
          future: AppDb.instance.getOrders(customerName: name, phone: phone),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = snap.data!;
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final o = list[i];
                return Card(
                  child: ListTile(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailScreen(orderId: o.id!))),
                    title: Text('${o.code} • ${fmtDate(o.date)}'),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(spacing: 6, runSpacing: 4, children: [
                        StatusBadge(workLabels[o.workStatus],
                            workColors[o.workStatus]),
                        StatusBadge(
                            payLabels[o.payStatus], payColors[o.payStatus]),
                      ]),
                    ),
                    trailing: Text(fmtRp(o.total),
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
