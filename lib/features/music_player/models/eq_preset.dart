import 'dart:convert';

class EqPreset {
  final int? id;
  final String name;
  final List<double> gains;
  final bool isBuiltIn;
  final DateTime createdAt;

  static const int bandCount = 8;
  static const double minGain = -12.0;
  static const double maxGain = 12.0;

  static const List<double> bandFrequencies = [
    32, 64, 125, 250, 500, 1000, 2000, 4000,
  ];

  static String formatFrequency(double hz) {
    if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(0)}k';
    return hz.toStringAsFixed(0);
  }

  const EqPreset({
    this.id,
    required this.name,
    required this.gains,
    required this.isBuiltIn,
    required this.createdAt,
  }) : assert(gains.length == bandCount,
            'gains must have exactly $bandCount values');

  EqPreset copyWith({
    int? id,
    String? name,
    List<double>? gains,
    bool? isBuiltIn,
    DateTime? createdAt,
  }) {
    return EqPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      gains: gains ?? this.gains,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory EqPreset.custom({
    int? id,
    required String name,
    required List<double> gains,
  }) {
    return EqPreset(
      id: id,
      name: name,
      gains: gains,
      isBuiltIn: false,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gains_json': jsonEncode(gains),
        'is_builtin': isBuiltIn ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory EqPreset.fromJson(Map<String, dynamic> map) {
    final gainsList = (jsonDecode(map['gains_json'] as String) as List)
        .map((e) => (e as num).toDouble())
        .toList();
    return EqPreset(
      id: map['id'] as int?,
      name: map['name'] as String,
      gains: gainsList,
      isBuiltIn: (map['is_builtin'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  static List<EqPreset> get builtInPresets => [
        EqPreset(
          name: 'Flat',
          gains: [0, 0, 0, 0, 0, 0, 0, 0],
          isBuiltIn: true,
          createdAt: _epoch,
        ),
        EqPreset(
          name: 'Rock',
          gains: [5, 4, 2, 0, -1, 0, 1, 3],
          isBuiltIn: true,
          createdAt: _epoch,
        ),
        EqPreset(
          name: 'Pop',
          gains: [-1, 2, 4, 3, 0, -1, -1, 1],
          isBuiltIn: true,
          createdAt: _epoch,
        ),
        EqPreset(
          name: 'Jazz',
          gains: [4, 2, 0, 0, -1, -1, 0, 2],
          isBuiltIn: true,
          createdAt: _epoch,
        ),
        EqPreset(
          name: 'Classical',
          gains: [5, 4, 3, 0, -1, -1, 0, 2],
          isBuiltIn: true,
          createdAt: _epoch,
        ),
        EqPreset(
          name: 'Hip-Hop',
          gains: [5, 4, 1, 2, -1, -1, 1, -1],
          isBuiltIn: true,
          createdAt: _epoch,
        ),
        EqPreset(
          name: 'Electronic',
          gains: [4, 3, 1, 0, -2, 1, 2, 4],
          isBuiltIn: true,
          createdAt: _epoch,
        ),
        EqPreset(
          name: 'Bass Boost',
          gains: [6, 5, 3, 1, 0, 0, 0, 0],
          isBuiltIn: true,
          createdAt: _epoch,
        ),
        EqPreset(
          name: 'Vocal Boost',
          gains: [0, 0, -1, -2, -1, 2, 4, 2],
          isBuiltIn: true,
          createdAt: _epoch,
        ),
      ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EqPreset && id == other.id && name == other.name;

  @override
  int get hashCode => Object.hash(id, name);
}
