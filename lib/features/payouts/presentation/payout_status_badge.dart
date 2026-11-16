import 'package:flutter/material.dart';
import 'package:ronditrack/core/theme/ronditrack_tokens.dart';
import 'package:ronditrack/features/payouts/domain/payout_order.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_status_badge.dart';

class PayoutStatusBadge extends StatelessWidget {
  const new({required this.status, super.key});

  final PayoutStatus status;

  @override
  Widget build(BuildContext context) {
    final token = switch (status) {
      PayoutStatus.waiting => RondiTrackToken.pending,
      PayoutStatus.next => RondiTrackToken.open,
      PayoutStatus.paid => RondiTrackToken.paidOut,
      PayoutStatus.unknown => RondiTrackToken.unknown,
    };

    return StokvelBadge(label: status.label, token: token);
  }
}
