import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/experimental/scope.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ronditrack/features/contributions/domain/contribution_history.dart';
import 'package:ronditrack/features/contributions/presentation/contribution_history_screen.dart';
import 'package:ronditrack/features/home/application/home_provider.dart';
import 'package:ronditrack/features/payments/presentation/payment_screen.dart';
import 'package:ronditrack/features/proofs/domain/proof_models.dart';
import 'package:ronditrack/features/proofs/presentation/proof_upload_screen.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_actions.dart';
import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';
import 'package:ronditrack/features/stokvels/presentation/stokvel_form_screens.dart';

@Dependencies([homeRepository])
Widget? stokvelWorkflowScreenFor(
  BuildContext context, {
  String? stokvelId,
  String? cycleId,
}) {
  final route = GoRouterState.of(context);

  if (route.matchedLocation != route.uri.path) {
    return null;
  }

  final view = route.uri.queryParameters['view'];

  if (stokvelId == null && view == 'create') {
    return const CreateStokvelScreen();
  }

  if (stokvelId != null && cycleId != null) {
    if (view == 'proof') {
      final target = ProofTarget.parse(
        stokvelId: stokvelId,
        cycleId: cycleId,
        contributionId: route.uri.queryParameters['contributionId'] ?? '',
      );

      return target == null
          ? const Scaffold(body: Center(child: Text('Not found')))
          : ProofUploadScreen(target: target);
    }

    if (view == 'pay') {
      return PaymentScreen(stokvelId: stokvelId, cycleId: cycleId);
    }

    if (view == 'edit') {
      return EditCycleScreen(stokvelId: stokvelId, cycleId: cycleId);
    }
  }

  if (stokvelId != null && cycleId == null && view == 'history') {
    final filters = historyFilterFromUri(route.uri);

    return ContributionHistoryScreen(
      stokvelId: stokvelId,
      filters: filters ?? allContributions,
      invalidFilters: filters == null,
    );
  }

  return null;
}

class CreateStokvelAction extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: () => context.go('/stokvels?view=create'),
        icon: const Icon(Icons.add),
        label: const Text('Create stokvel'),
      ),
    );
  }
}

class StokvelWorkflowActions extends StatelessWidget {
  const new({required this.stokvel, required this.userId, super.key});

  final Stokvel stokvel;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final cycle = stokvel.currentCycle;

    ContributionStatus? own;
    String? contributionId;

    for (final item in stokvel.contributions) {
      if (item.userId.toLowerCase() == userId.toLowerCase() &&
          item.cycleId.toLowerCase() == cycle?.id.toLowerCase()) {
        own = item.status;
        contributionId = item.id;
        break;
      }
    }

    final actions = availableActions((
      stokvel.membership.role,
      cycle?.status,
      own,
    ));

    String location(String view, {String? contributionId}) {
      return Uri(
        pathSegments: [
          '',
          'stokvels',
          stokvel.membership.stokvelId,
          'cycles',
          cycle!.id,
        ],
        queryParameters: {
          'view': view,
          if (contributionId != null) 'contributionId': contributionId,
        },
      ).toString();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (cycle != null && actions.contains(StokvelAction.pay))
          FilledButton(
            onPressed: () => context.go(location('pay')),
            child: const Text('Pay contribution'),
          ),
        if (cycle != null &&
            contributionId != null &&
            actions.contains(StokvelAction.uploadProof))
          OutlinedButton.icon(
            onPressed: () =>
                context.go(location('proof', contributionId: contributionId)),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Upload proof'),
          ),
        if (cycle != null && stokvel.membership.role == StokvelRole.admin)
          OutlinedButton(
            onPressed: () => context.go(location('edit')),
            child: const Text('Edit cycle'),
          ),
        OutlinedButton(
          onPressed: () => context.go(
            historyLocation(stokvel.membership.stokvelId, allContributions),
          ),
          child: const Text('Contribution history'),
        ),
      ],
    );
  }
}
