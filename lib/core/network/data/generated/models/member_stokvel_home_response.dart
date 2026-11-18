// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'member_stokvel_home_response.g.dart';

@JsonSerializable()
class MemberStokvelHomeResponse {
  const MemberStokvelHomeResponse({
    required this.stokvelId,
    required this.name,
    required this.role,
    required this.currentCycle,
    required this.cycleStatus,
    required this.cycleDueDate,
    required this.paidThisCycleInCents,
    required this.stillOwedInCents,
    required this.nextPayoutDateUtc,
    required this.arrearsInCents,
  });

  factory MemberStokvelHomeResponse.fromJson(Map<String, Object?> json) =>
      _$MemberStokvelHomeResponseFromJson(json);

  final String stokvelId;
  final String name;
  final String role;
  final int? currentCycle;
  final String? cycleStatus;
  final DateTime? cycleDueDate;
  final int? paidThisCycleInCents;
  final int? stillOwedInCents;
  final DateTime? nextPayoutDateUtc;
  final int arrearsInCents;

  Map<String, Object?> toJson() => _$MemberStokvelHomeResponseToJson(this);
}
