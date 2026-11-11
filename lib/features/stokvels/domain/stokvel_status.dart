/// The lifecycle status of a contribution cycle.
enum CycleStatus {
  open,
  closed,
  paidOut,
  unknown;

  static CycleStatus fromApi(String value) => switch (value) {
    'Open' => CycleStatus.open,
    'Closed' => CycleStatus.closed,
    'PaidOut' => CycleStatus.paidOut,
    _ => CycleStatus.unknown,
  };

  String get label => switch (this) {
    CycleStatus.open => 'Open',
    CycleStatus.closed => 'Closed',
    CycleStatus.paidOut => 'Paid out',
    CycleStatus.unknown => 'Unknown cycle status',
  };
}

enum ContributionStatus {
  pending,
  paid,
  confirmed,
  unknown;

  static ContributionStatus fromApi(String value) => switch (value) {
    'Pending' => ContributionStatus.pending,
    'Paid' => ContributionStatus.paid,
    'Confirmed' => ContributionStatus.confirmed,
    _ => ContributionStatus.unknown,
  };

  String get label => switch (this) {
    ContributionStatus.pending => 'Pending',
    ContributionStatus.paid => 'Paid',
    ContributionStatus.confirmed => 'Confirmed',
    ContributionStatus.unknown => 'Unknown contribution status',
  };
}

enum StokvelRole {
  member,
  treasurer,
  admin,
  unknown;

  static StokvelRole fromApi(String value) => switch (value) {
    'Member' => StokvelRole.member,
    'Treasurer' => StokvelRole.treasurer,
    'Admin' => StokvelRole.admin,
    _ => StokvelRole.unknown,
  };

  String get label => switch (this) {
    StokvelRole.member => 'Member',
    StokvelRole.treasurer => 'Treasurer',
    StokvelRole.admin => 'Admin',
    StokvelRole.unknown => 'Unknown role',
  };
}
