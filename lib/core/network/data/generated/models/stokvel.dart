// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'user.dart';

part 'stokvel.g.dart';

@JsonSerializable()
class Stokvel {
  const Stokvel({
    required this.name,
    required this.monthlyContribution,
    required this.currentPeriod,
    required this.totalPeriods,
    this.id,
    this.rules,
    this.version,
    this.members,
  });

  factory Stokvel.fromJson(Map<String, Object?> json) =>
      _$StokvelFromJson(json);

  final String? id;
  final String name;
  final double monthlyContribution;
  final int currentPeriod;
  final int totalPeriods;
  final String? rules;
  final int? version;
  final List<User>? members;

  Map<String, Object?> toJson() => _$StokvelToJson(this);
}
