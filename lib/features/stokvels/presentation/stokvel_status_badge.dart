import 'package:flutter/material.dart';
import 'package:ronditrack/core/theme/ronditrack_tokens.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

class CycleStatusBadge extends StatelessWidget {
  const new({required this.status, super.key});

  final CycleStatus status;

  @override
  Widget build(BuildContext context) {
    final token = switch (status) {
      CycleStatus.open => RondiTrackToken.open,
      CycleStatus.closed => RondiTrackToken.closed,
      CycleStatus.paidOut => RondiTrackToken.paidOut,
      CycleStatus.unknown => RondiTrackToken.unknown,
    };

    return StokvelBadge(label: status.label, token: token);
  }
}

class ContributionStatusBadge extends StatelessWidget {
  const new({required this.status, super.key});

  final ContributionStatus status;

  @override
  Widget build(BuildContext context) {
    final token = switch (status) {
      ContributionStatus.pending => RondiTrackToken.pending,
      ContributionStatus.paid => RondiTrackToken.paid,
      ContributionStatus.confirmed => RondiTrackToken.open,
      ContributionStatus.unknown => RondiTrackToken.unknown,
    };

    return StokvelBadge(label: status.label, token: token);
  }
}

class StokvelBadge extends StatelessWidget {
  const new({required this.label, required this.token, super.key});

  final String label;
  final RondiTrackToken token;

  @override
  Widget build(BuildContext context) {
    final colors = RondiTrackTokens.of(context)[token];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: colors.foreground,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}