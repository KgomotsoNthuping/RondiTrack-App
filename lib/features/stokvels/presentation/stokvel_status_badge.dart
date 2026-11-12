import 'package:flutter/material.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

/// Shows a cycle status using its label and the web palette.
class CycleStatusBadge extends StatelessWidget {
  /// Creates a cycle status badge.
  const new({required this.status, super.key});

  /// The cycle status to display.
  final CycleStatus status;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (fill, ink) = switch (status) {
      CycleStatus.open => _lime(dark: dark),
      CycleStatus.closed => (
        dark ? const Color(0xFF314158) : const Color(0xFFE2E8F0),
        dark ? Colors.white : const Color(0xFF0F172B),
      ),
      CycleStatus.paidOut => (
        dark ? const Color(0xFF8EC5FF) : const Color(0xFFDBEAFE),
        const Color(0xFF162456),
      ),
      CycleStatus.unknown => _unknown(dark: dark),
    };
    return _badge(status.label, fill, ink);
  }
}

/// Shows a contribution status using its label and the web palette.
class ContributionStatusBadge extends StatelessWidget {
  /// Creates a contribution status badge.
  const new({required this.status, super.key});

  /// The contribution status to display.
  final ContributionStatus status;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (fill, ink) = switch (status) {
      ContributionStatus.pending => (
        dark ? const Color(0xFFFFD230) : const Color(0xFFFEF3C6),
        const Color(0xFF461901),
      ),
      ContributionStatus.paid => (
        dark ? const Color(0xFF74D4FF) : const Color(0xFFDFF2FE),
        const Color(0xFF052F4A),
      ),
      ContributionStatus.confirmed => _lime(dark: dark),
      ContributionStatus.unknown => _unknown(dark: dark),
    };
    return _badge(status.label, fill, ink);
  }
}

(Color, Color) _lime({required bool dark}) => (
  dark ? const Color(0xFFBBF451) : const Color(0xFFD8F999),
  const Color(0xFF192E03),
);

(Color, Color) _unknown({required bool dark}) => (
  dark ? const Color(0xFF314158) : const Color(0xFFF1F5F9),
  dark ? Colors.white : const Color(0xFF0F172B),
);

Widget _badge(String label, Color fill, Color ink) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label,
        style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
