import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

final _dateTime = DateFormat('d MMM yyyy, HH:mm');
final _date = DateFormat('d MMM yyyy');
final _number = NumberFormat('#,##0.##');

String fmtDateTime(Object? iso) {
  if (iso == null) return '-';
  final parsed = DateTime.tryParse(iso.toString());
  return parsed == null ? iso.toString() : _dateTime.format(parsed.toLocal());
}

String fmtDate(Object? iso) {
  if (iso == null) return '-';
  final parsed = DateTime.tryParse(iso.toString());
  return parsed == null ? iso.toString() : _date.format(parsed.toLocal());
}

String fmtNum(Object? value) {
  if (value == null) return '-';
  final n = value is num ? value : num.tryParse(value.toString());
  return n == null ? value.toString() : _number.format(n);
}

String fmtPkr(Object? value) => value == null ? '-' : 'Rs ${fmtNum(value)}';

/// "PENDING_APPROVAL" -> "Pending approval"
String humanize(Object? value) {
  if (value == null) return '-';
  final text = value.toString().replaceAll('_', ' ').toLowerCase();
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

String shortId(Object? id) => id == null ? '-' : id.toString().split('-').first;

Color statusColor(Object? status) {
  switch (status?.toString()) {
    case 'ACTIVE':
    case 'APPROVED':
    case 'VERIFIED':
    case 'ACCEPTED':
    case 'OPEN':
    case 'SOLD':
    case 'ABOVE':
      return AppColors.success;
    case 'PENDING':
    case 'PENDING_APPROVAL':
    case 'PENDING_VERIFICATION':
    case 'UNDER_REVIEW':
    case 'DRAFT':
    case 'CLOSED':
    case 'AT':
      return AppColors.warning;
    case 'REJECTED':
    case 'SUSPENDED':
    case 'CANCELLED':
    case 'BELOW':
      return AppColors.danger;
    default:
      return AppColors.neutral;
  }
}

const grains = ['WHEAT', 'RICE', 'PADDY', 'MAIZE'];
const units = ['KG', 'MAUND', 'QUINTAL', 'TON'];
const buyerTypes = ['TRADER', 'MILL_OWNER', 'WHOLESALER'];
const accountStatuses = ['PENDING_VERIFICATION', 'PENDING_APPROVAL', 'ACTIVE', 'REJECTED', 'SUSPENDED'];
const listingStatuses = ['DRAFT', 'OPEN', 'CLOSED', 'SOLD', 'CANCELLED'];
const bidStatuses = ['ACTIVE', 'ACCEPTED', 'REJECTED', 'WITHDRAWN', 'EXPIRED'];
