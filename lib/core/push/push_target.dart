import 'dart:convert';

final class PushTarget {
  const new _(this.stokvelId, this.cycleId);

  static const type = 'cycle_updated';

  final String stokvelId;
  final String cycleId;

  static PushTarget? parse(Object? data) {
    if (data is! Map<String, Object?> ||
        data.length != 3 ||
        data['type'] != type ||
        !data.keys.toSet().containsAll(['type', 'stokvelId', 'cycleId'])) {
      return null;
    }

    final stokvel = data['stokvelId'];
    final cycle = data['cycleId'];

    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-'
      r'[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    if (stokvel is! String ||
        cycle is! String ||
        stokvel.length != 36 ||
        cycle.length != 36 ||
        !uuid.hasMatch(stokvel) ||
        !uuid.hasMatch(cycle)) {
      return null;
    }

    return PushTarget._(stokvel.toLowerCase(), cycle.toLowerCase());
  }

  static PushTarget? decode(String? value) {
    if (value == null) {
      return null;
    }

    try {
      return parse(jsonDecode(value));
    } on Object {
      return null;
    }
  }

  Map<String, String> get data => {
    'type': type,
    'stokvelId': stokvelId,
    'cycleId': cycleId,
  };

  String get payload => jsonEncode(data);

  String get location => '/stokvels/$stokvelId/cycles/$cycleId';
}
