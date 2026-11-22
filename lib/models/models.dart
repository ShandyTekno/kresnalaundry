import 'package:flutter/material.dart';

import '../core/utils.dart';

const workLabels = [
  'Belum Diproses',
  'Sedang Diproses',
  'Selesai',
  'Sudah Diambil',
];
const workColors = [
  Color(0xFFEF6C00),
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
];
const payLabels = ['Belum Lunas', 'Lunas'];
const payColors = [Color(0xFFC62828), Color(0xFF2E7D32)];
const payMethods = ['Tunai', 'QRIS'];

/// Pilihan waktu pengerjaan (Reguler, One Day, Quick Express).
class LaundryPackage {
  final int id;
  final String name;
  final int estimateHours;
  final bool active;
  const LaundryPackage(
    this.id,
    this.name,
    this.estimateHours, {
    this.active = true,
  });

  String get durationLabel => fmtEstimate(estimateHours);

  factory LaundryPackage.fromMap(Map<String, Object?> m) => LaundryPackage(
        m['id'] as int,
        m['name'] as String,
        m['estimate_hours'] as int,
        active: ((m['active'] as int?) ?? 1) == 1,
      );
}

/// Jenis layanan laundry (Cuci Saja, Cuci + Gosok, Gosok Saja).
class ItemType {
  final int id;
  final String code;
  final String name;
  final bool isKiloan;
  final String description;
  final bool active;
  const ItemType(
    this.id,
    this.code,
    this.name,
    this.isKiloan, {
    this.description = '',
    this.active = true,
  });

  String get unit => isKiloan ? 'kg' : 'pcs';

  factory ItemType.fromMap(Map<String, Object?> m) => ItemType(
        m['id'] as int,
        m['code'] as String,
        m['name'] as String,
        (m['kind'] as String) == 'kiloan',
        description: (m['description'] as String?) ?? '',
        active: ((m['active'] as int?) ?? 1) == 1,
      );
}

class LaundryOrder {
  final int? id;
  final String code;
  final String customerName;
  final String phone;
  final DateTime date;
  final int itemTypeId;
  final String itemCode;
  final String itemName;
  final bool isKiloan;
  final double qty;
  final int packageId;
  final String packageName;
  final int estimateHours;
  final DateTime? estimatedDoneAt;
  final double unitPrice;
  final double total;
  final String notes;
  final int workStatus;
  final int payStatus;
  final String? payMethod;
  final DateTime? paidAt;

  const LaundryOrder({
    this.id,
    required this.code,
    required this.customerName,
    required this.phone,
    required this.date,
    required this.itemTypeId,
    required this.itemCode,
    required this.itemName,
    required this.isKiloan,
    required this.qty,
    required this.packageId,
    required this.packageName,
    required this.estimateHours,
    this.estimatedDoneAt,
    required this.unitPrice,
    required this.total,
    this.notes = '',
    this.workStatus = 0,
    this.payStatus = 0,
    this.payMethod,
    this.paidAt,
  });

  bool get isPaid => payStatus == 1;
  bool get isDone => workStatus >= 2;
  String get qtyLabel => '${qtyText(qty)} ${isKiloan ? 'kg' : 'pcs'}';
  String get serviceLabel => itemName;
  String get speedLabel => '$packageName (${fmtEstimate(estimateHours)})';
  String get estimatedDoneLabel => estimatedDoneAt != null
      ? fmtDateTime(estimatedDoneAt!)
      : fmtEstimate(estimateHours);

  static String qtyText(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  factory LaundryOrder.fromMap(Map<String, Object?> m) => LaundryOrder(
        id: m['id'] as int,
        code: m['code'] as String,
        customerName: m['customer_name'] as String,
        phone: (m['phone'] as String?) ?? '',
        date: DateTime.parse(m['date'] as String),
        itemTypeId: m['item_type_id'] as int,
        itemCode: m['item_code'] as String,
        itemName: m['item_name'] as String,
        isKiloan: (m['kind'] as String) == 'kiloan',
        qty: (m['qty'] as num).toDouble(),
        packageId: m['package_id'] as int,
        packageName: m['package_name'] as String,
        estimateHours: m['estimate_hours'] as int,
        estimatedDoneAt: m['estimated_done_at'] == null
            ? null
            : DateTime.parse(m['estimated_done_at'] as String),
        unitPrice: (m['unit_price'] as num).toDouble(),
        total: (m['total'] as num).toDouble(),
        notes: (m['notes'] as String?) ?? '',
        workStatus: m['work_status'] as int,
        payStatus: m['pay_status'] as int,
        payMethod: m['pay_method'] as String?,
        paidAt: m['paid_at'] == null
            ? null
            : DateTime.parse(m['paid_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'code': code,
        'customer_name': customerName,
        'phone': phone,
        'date': date.toIso8601String().substring(0, 10),
        'item_type_id': itemTypeId,
        'item_code': itemCode,
        'item_name': itemName,
        'kind': isKiloan ? 'kiloan' : 'satuan',
        'qty': qty,
        'package_id': packageId,
        'package_name': packageName,
        'estimate_hours': estimateHours,
        'estimated_done_at': estimatedDoneAt?.toIso8601String(),
        'unit_price': unitPrice,
        'total': total,
        'notes': notes,
        'work_status': workStatus,
        'pay_status': payStatus,
        'pay_method': payMethod,
        'paid_at': paidAt?.toIso8601String(),
      };
}
