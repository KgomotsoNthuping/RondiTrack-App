import 'package:ronditrack/features/stokvels/domain/stokvel_status.dart';

enum StokvelAction {
  pay,
  uploadProof,
  confirmContributions,
  closeCycle,
  recordPayout,
}

typedef StokvelActionContext = (
  StokvelRole role,
  CycleStatus? cycleStatus,
  ContributionStatus? ownContributionStatus,
);

Set<StokvelAction> availableActions(StokvelActionContext context) {
  return switch (context) {
    (
      StokvelRole.unknown,
      CycleStatus.open ||
          CycleStatus.closed ||
          CycleStatus.paidOut ||
          CycleStatus.unknown ||
          null,
      ContributionStatus.pending ||
          ContributionStatus.paid ||
          ContributionStatus.confirmed ||
          ContributionStatus.unknown ||
          null,
    ) =>
      const <StokvelAction>{},
    (
      StokvelRole.member || StokvelRole.treasurer || StokvelRole.admin,
      CycleStatus.paidOut || CycleStatus.unknown || null,
      ContributionStatus.pending ||
          ContributionStatus.paid ||
          ContributionStatus.confirmed ||
          ContributionStatus.unknown ||
          null,
    ) =>
      const <StokvelAction>{},
    (
      StokvelRole.member || StokvelRole.treasurer || StokvelRole.admin,
      CycleStatus.open || CycleStatus.closed,
      ContributionStatus.unknown,
    ) =>
      const <StokvelAction>{},
    (
      StokvelRole.member || StokvelRole.treasurer,
      CycleStatus.closed,
      ContributionStatus.pending ||
          ContributionStatus.paid ||
          ContributionStatus.confirmed ||
          null,
    ) =>
      const <StokvelAction>{},
    (
      StokvelRole.admin,
      CycleStatus.closed,
      ContributionStatus.pending ||
          ContributionStatus.paid ||
          ContributionStatus.confirmed ||
          null,
    ) =>
      const {StokvelAction.recordPayout},
    (StokvelRole.member, CycleStatus.open, null) => const {StokvelAction.pay},
    (
      StokvelRole.member,
      CycleStatus.open,
      ContributionStatus.pending ||
          ContributionStatus.paid ||
          ContributionStatus.confirmed,
    ) =>
      const {StokvelAction.uploadProof},
    (StokvelRole.treasurer, CycleStatus.open, null) => const {
      StokvelAction.pay,
      StokvelAction.closeCycle,
    },
    (
      StokvelRole.treasurer,
      CycleStatus.open,
      ContributionStatus.pending ||
          ContributionStatus.paid ||
          ContributionStatus.confirmed,
    ) =>
      const {StokvelAction.uploadProof, StokvelAction.closeCycle},
    (StokvelRole.admin, CycleStatus.open, null) => const {
      StokvelAction.pay,
      StokvelAction.recordPayout,
    },
    (
      StokvelRole.admin,
      CycleStatus.open,
      ContributionStatus.pending ||
          ContributionStatus.paid ||
          ContributionStatus.confirmed,
    ) =>
      const {StokvelAction.uploadProof, StokvelAction.recordPayout},
  };
}
