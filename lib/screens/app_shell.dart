import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'order_form_screen.dart';
import 'orders_screen.dart';
import 'reports_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';

/// Indeks tab aktif; dipakai dashboard untuk berpindah menu.
final ValueNotifier<int> navIndex = ValueNotifier<int>(0);

/// Filter cepat yang dikirim dari kartu Dashboard ke layar Pesanan.
final ValueNotifier<({int? work, int? pay})?> quickOrderFilter =
    ValueNotifier<({int? work, int? pay})?>(null);

void openOrdersWithFilter({int? work, int? pay}) {
  quickOrderFilter.value = (work: work, pay: pay);
  navIndex.value = 1;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DateTime? _lastBackAt;

  static const _titles = [
    'Kresna Laundry',
    'Pesanan & Riwayat',
    'Pelanggan',
    'Layanan & Tarif',
    'Laporan',
  ];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.receipt_long_outlined,
    Icons.people_outline,
    Icons.local_laundry_service_outlined,
    Icons.bar_chart_outlined,
  ];
  static const _selIcons = [
    Icons.dashboard,
    Icons.receipt_long,
    Icons.people,
    Icons.local_laundry_service,
    Icons.bar_chart,
  ];
  static const _labels = [
    'Beranda',
    'Pesanan',
    'Pelanggan',
    'Layanan',
    'Laporan',
  ];

  void _handleBack(bool didPop) {
    if (didPop) return;
    if (navIndex.value != 0) {
      navIndex.value = 0;
      return;
    }
    final now = DateTime.now();
    if (_lastBackAt == null ||
        now.difference(_lastBackAt!) > const Duration(seconds: 2)) {
      _lastBackAt = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('Geser atau tekan kembali sekali lagi untuk keluar.'),
          ),
        );
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
      child: ValueListenableBuilder<int>(
        valueListenable: navIndex,
        builder: (context, idx, _) {
          final width = MediaQuery.of(context).size.width;
          final wide = width >= 760;
          final extendedRail = width >= 1100;
          const pages = [
            DashboardScreen(),
            OrdersScreen(),
            CustomersScreen(),
            ServicesScreen(),
            ReportsScreen(),
          ];
          final body = IndexedStack(index: idx, children: pages);

          return Scaffold(
            appBar: AppBar(
              title: Text(_titles[idx]),
              actions: [
                IconButton(
                  tooltip: 'Atur Huruf & Warna',
                  icon: const Icon(Icons.text_fields),
                  onPressed: () => showQuickAppearanceSheet(context),
                ),
                IconButton(
                  tooltip: 'Pengaturan',
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
            floatingActionButton: (idx == 0 || idx == 1)
                ? FloatingActionButton.extended(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OrderFormScreen()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Pesanan Baru'),
                  )
                : null,
            body: wide
                ? Row(children: [
                    NavigationRail(
                      selectedIndex: idx,
                      extended: extendedRail,
                      labelType: extendedRail
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      onDestinationSelected: (i) => navIndex.value = i,
                      destinations: [
                        for (var i = 0; i < _labels.length; i++)
                          NavigationRailDestination(
                            icon: Icon(_icons[i]),
                            selectedIcon: Icon(_selIcons[i]),
                            label: Text(_labels[i]),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ])
                : body,
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: idx,
                    onDestinationSelected: (i) => navIndex.value = i,
                    destinations: [
                      for (var i = 0; i < _labels.length; i++)
                        NavigationDestination(
                          icon: Icon(_icons[i]),
                          selectedIcon: Icon(_selIcons[i]),
                          label: _labels[i],
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
