// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class Settings extends Table with TableInfo<Settings, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Settings(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  Settings createAlias(String alias) {
    return Settings(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  bool get dontWriteConstraints => true;
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Missions extends Table with TableInfo<Missions, Mission> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Missions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(name) BETWEEN 1 AND 120)',
  );
  static const VerificationMeta _isSimulationMeta = const VerificationMeta(
    'isSimulation',
  );
  late final GeneratedColumn<int> isSimulation = GeneratedColumn<int>(
    'is_simulation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (is_simulation IN (0, 1))',
  );
  static const VerificationMeta _simulationSeedMeta = const VerificationMeta(
    'simulationSeed',
  );
  late final GeneratedColumn<int> simulationSeed = GeneratedColumn<int>(
    'simulation_seed',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _simulatedDayMeta = const VerificationMeta(
    'simulatedDay',
  );
  late final GeneratedColumn<int> simulatedDay = GeneratedColumn<int>(
    'simulated_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  late final GeneratedColumn<Uint8List> subjectId = GeneratedColumn<Uint8List>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(subject_id) = 16)',
  );
  static const VerificationMeta _subjectLabelMeta = const VerificationMeta(
    'subjectLabel',
  );
  late final GeneratedColumn<String> subjectLabel = GeneratedColumn<String>(
    'subject_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _startAtUsMeta = const VerificationMeta(
    'startAtUs',
  );
  late final GeneratedColumn<int> startAtUs = GeneratedColumn<int>(
    'start_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _referenceDaysMeta = const VerificationMeta(
    'referenceDays',
  );
  late final GeneratedColumn<int> referenceDays = GeneratedColumn<int>(
    'reference_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (reference_days >= 0)',
  );
  static const VerificationMeta _plannedDaysMeta = const VerificationMeta(
    'plannedDays',
  );
  late final GeneratedColumn<int> plannedDays = GeneratedColumn<int>(
    'planned_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (planned_days > 0)',
  );
  static const VerificationMeta _createdAtUsMeta = const VerificationMeta(
    'createdAtUs',
  );
  late final GeneratedColumn<int> createdAtUs = GeneratedColumn<int>(
    'created_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    isSimulation,
    simulationSeed,
    simulatedDay,
    subjectId,
    subjectLabel,
    startAtUs,
    referenceDays,
    plannedDays,
    createdAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'missions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Mission> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_simulation')) {
      context.handle(
        _isSimulationMeta,
        isSimulation.isAcceptableOrUnknown(
          data['is_simulation']!,
          _isSimulationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isSimulationMeta);
    }
    if (data.containsKey('simulation_seed')) {
      context.handle(
        _simulationSeedMeta,
        simulationSeed.isAcceptableOrUnknown(
          data['simulation_seed']!,
          _simulationSeedMeta,
        ),
      );
    }
    if (data.containsKey('simulated_day')) {
      context.handle(
        _simulatedDayMeta,
        simulatedDay.isAcceptableOrUnknown(
          data['simulated_day']!,
          _simulatedDayMeta,
        ),
      );
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('subject_label')) {
      context.handle(
        _subjectLabelMeta,
        subjectLabel.isAcceptableOrUnknown(
          data['subject_label']!,
          _subjectLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectLabelMeta);
    }
    if (data.containsKey('start_at_us')) {
      context.handle(
        _startAtUsMeta,
        startAtUs.isAcceptableOrUnknown(data['start_at_us']!, _startAtUsMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtUsMeta);
    }
    if (data.containsKey('reference_days')) {
      context.handle(
        _referenceDaysMeta,
        referenceDays.isAcceptableOrUnknown(
          data['reference_days']!,
          _referenceDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_referenceDaysMeta);
    }
    if (data.containsKey('planned_days')) {
      context.handle(
        _plannedDaysMeta,
        plannedDays.isAcceptableOrUnknown(
          data['planned_days']!,
          _plannedDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plannedDaysMeta);
    }
    if (data.containsKey('created_at_us')) {
      context.handle(
        _createdAtUsMeta,
        createdAtUs.isAcceptableOrUnknown(
          data['created_at_us']!,
          _createdAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Mission map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Mission(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isSimulation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_simulation'],
      )!,
      simulationSeed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}simulation_seed'],
      ),
      simulatedDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}simulated_day'],
      ),
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}subject_id'],
      )!,
      subjectLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_label'],
      )!,
      startAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_at_us'],
      )!,
      referenceDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reference_days'],
      )!,
      plannedDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_days'],
      )!,
      createdAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_us'],
      )!,
    );
  }

  @override
  Missions createAlias(String alias) {
    return Missions(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => const [
    'CHECK((is_simulation = 1)=(simulation_seed IS NOT NULL))',
    'CHECK(is_simulation = 1 OR simulated_day IS NULL)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class Mission extends DataClass implements Insertable<Mission> {
  final String id;
  final String name;
  final int isSimulation;

  /// Generator seed; present exactly when the mission is a simulation.
  final int? simulationSeed;

  /// Current day of a simulation's clock; real missions derive it from time.
  final int? simulatedDay;
  final Uint8List subjectId;
  final String subjectLabel;

  /// 00:00 UTC on mission day 1, microseconds since the Unix epoch.
  final int startAtUs;
  final int referenceDays;
  final int plannedDays;
  final int createdAtUs;
  const Mission({
    required this.id,
    required this.name,
    required this.isSimulation,
    this.simulationSeed,
    this.simulatedDay,
    required this.subjectId,
    required this.subjectLabel,
    required this.startAtUs,
    required this.referenceDays,
    required this.plannedDays,
    required this.createdAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['is_simulation'] = Variable<int>(isSimulation);
    if (!nullToAbsent || simulationSeed != null) {
      map['simulation_seed'] = Variable<int>(simulationSeed);
    }
    if (!nullToAbsent || simulatedDay != null) {
      map['simulated_day'] = Variable<int>(simulatedDay);
    }
    map['subject_id'] = Variable<Uint8List>(subjectId);
    map['subject_label'] = Variable<String>(subjectLabel);
    map['start_at_us'] = Variable<int>(startAtUs);
    map['reference_days'] = Variable<int>(referenceDays);
    map['planned_days'] = Variable<int>(plannedDays);
    map['created_at_us'] = Variable<int>(createdAtUs);
    return map;
  }

  MissionsCompanion toCompanion(bool nullToAbsent) {
    return MissionsCompanion(
      id: Value(id),
      name: Value(name),
      isSimulation: Value(isSimulation),
      simulationSeed: simulationSeed == null && nullToAbsent
          ? const Value.absent()
          : Value(simulationSeed),
      simulatedDay: simulatedDay == null && nullToAbsent
          ? const Value.absent()
          : Value(simulatedDay),
      subjectId: Value(subjectId),
      subjectLabel: Value(subjectLabel),
      startAtUs: Value(startAtUs),
      referenceDays: Value(referenceDays),
      plannedDays: Value(plannedDays),
      createdAtUs: Value(createdAtUs),
    );
  }

  factory Mission.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Mission(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isSimulation: serializer.fromJson<int>(json['is_simulation']),
      simulationSeed: serializer.fromJson<int?>(json['simulation_seed']),
      simulatedDay: serializer.fromJson<int?>(json['simulated_day']),
      subjectId: serializer.fromJson<Uint8List>(json['subject_id']),
      subjectLabel: serializer.fromJson<String>(json['subject_label']),
      startAtUs: serializer.fromJson<int>(json['start_at_us']),
      referenceDays: serializer.fromJson<int>(json['reference_days']),
      plannedDays: serializer.fromJson<int>(json['planned_days']),
      createdAtUs: serializer.fromJson<int>(json['created_at_us']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'is_simulation': serializer.toJson<int>(isSimulation),
      'simulation_seed': serializer.toJson<int?>(simulationSeed),
      'simulated_day': serializer.toJson<int?>(simulatedDay),
      'subject_id': serializer.toJson<Uint8List>(subjectId),
      'subject_label': serializer.toJson<String>(subjectLabel),
      'start_at_us': serializer.toJson<int>(startAtUs),
      'reference_days': serializer.toJson<int>(referenceDays),
      'planned_days': serializer.toJson<int>(plannedDays),
      'created_at_us': serializer.toJson<int>(createdAtUs),
    };
  }

  Mission copyWith({
    String? id,
    String? name,
    int? isSimulation,
    Value<int?> simulationSeed = const Value.absent(),
    Value<int?> simulatedDay = const Value.absent(),
    Uint8List? subjectId,
    String? subjectLabel,
    int? startAtUs,
    int? referenceDays,
    int? plannedDays,
    int? createdAtUs,
  }) => Mission(
    id: id ?? this.id,
    name: name ?? this.name,
    isSimulation: isSimulation ?? this.isSimulation,
    simulationSeed: simulationSeed.present
        ? simulationSeed.value
        : this.simulationSeed,
    simulatedDay: simulatedDay.present ? simulatedDay.value : this.simulatedDay,
    subjectId: subjectId ?? this.subjectId,
    subjectLabel: subjectLabel ?? this.subjectLabel,
    startAtUs: startAtUs ?? this.startAtUs,
    referenceDays: referenceDays ?? this.referenceDays,
    plannedDays: plannedDays ?? this.plannedDays,
    createdAtUs: createdAtUs ?? this.createdAtUs,
  );
  Mission copyWithCompanion(MissionsCompanion data) {
    return Mission(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isSimulation: data.isSimulation.present
          ? data.isSimulation.value
          : this.isSimulation,
      simulationSeed: data.simulationSeed.present
          ? data.simulationSeed.value
          : this.simulationSeed,
      simulatedDay: data.simulatedDay.present
          ? data.simulatedDay.value
          : this.simulatedDay,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      subjectLabel: data.subjectLabel.present
          ? data.subjectLabel.value
          : this.subjectLabel,
      startAtUs: data.startAtUs.present ? data.startAtUs.value : this.startAtUs,
      referenceDays: data.referenceDays.present
          ? data.referenceDays.value
          : this.referenceDays,
      plannedDays: data.plannedDays.present
          ? data.plannedDays.value
          : this.plannedDays,
      createdAtUs: data.createdAtUs.present
          ? data.createdAtUs.value
          : this.createdAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Mission(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isSimulation: $isSimulation, ')
          ..write('simulationSeed: $simulationSeed, ')
          ..write('simulatedDay: $simulatedDay, ')
          ..write('subjectId: $subjectId, ')
          ..write('subjectLabel: $subjectLabel, ')
          ..write('startAtUs: $startAtUs, ')
          ..write('referenceDays: $referenceDays, ')
          ..write('plannedDays: $plannedDays, ')
          ..write('createdAtUs: $createdAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    isSimulation,
    simulationSeed,
    simulatedDay,
    $driftBlobEquality.hash(subjectId),
    subjectLabel,
    startAtUs,
    referenceDays,
    plannedDays,
    createdAtUs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mission &&
          other.id == this.id &&
          other.name == this.name &&
          other.isSimulation == this.isSimulation &&
          other.simulationSeed == this.simulationSeed &&
          other.simulatedDay == this.simulatedDay &&
          $driftBlobEquality.equals(other.subjectId, this.subjectId) &&
          other.subjectLabel == this.subjectLabel &&
          other.startAtUs == this.startAtUs &&
          other.referenceDays == this.referenceDays &&
          other.plannedDays == this.plannedDays &&
          other.createdAtUs == this.createdAtUs);
}

class MissionsCompanion extends UpdateCompanion<Mission> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> isSimulation;
  final Value<int?> simulationSeed;
  final Value<int?> simulatedDay;
  final Value<Uint8List> subjectId;
  final Value<String> subjectLabel;
  final Value<int> startAtUs;
  final Value<int> referenceDays;
  final Value<int> plannedDays;
  final Value<int> createdAtUs;
  final Value<int> rowid;
  const MissionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isSimulation = const Value.absent(),
    this.simulationSeed = const Value.absent(),
    this.simulatedDay = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.subjectLabel = const Value.absent(),
    this.startAtUs = const Value.absent(),
    this.referenceDays = const Value.absent(),
    this.plannedDays = const Value.absent(),
    this.createdAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MissionsCompanion.insert({
    required String id,
    required String name,
    required int isSimulation,
    this.simulationSeed = const Value.absent(),
    this.simulatedDay = const Value.absent(),
    required Uint8List subjectId,
    required String subjectLabel,
    required int startAtUs,
    required int referenceDays,
    required int plannedDays,
    required int createdAtUs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       isSimulation = Value(isSimulation),
       subjectId = Value(subjectId),
       subjectLabel = Value(subjectLabel),
       startAtUs = Value(startAtUs),
       referenceDays = Value(referenceDays),
       plannedDays = Value(plannedDays),
       createdAtUs = Value(createdAtUs);
  static Insertable<Mission> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? isSimulation,
    Expression<int>? simulationSeed,
    Expression<int>? simulatedDay,
    Expression<Uint8List>? subjectId,
    Expression<String>? subjectLabel,
    Expression<int>? startAtUs,
    Expression<int>? referenceDays,
    Expression<int>? plannedDays,
    Expression<int>? createdAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isSimulation != null) 'is_simulation': isSimulation,
      if (simulationSeed != null) 'simulation_seed': simulationSeed,
      if (simulatedDay != null) 'simulated_day': simulatedDay,
      if (subjectId != null) 'subject_id': subjectId,
      if (subjectLabel != null) 'subject_label': subjectLabel,
      if (startAtUs != null) 'start_at_us': startAtUs,
      if (referenceDays != null) 'reference_days': referenceDays,
      if (plannedDays != null) 'planned_days': plannedDays,
      if (createdAtUs != null) 'created_at_us': createdAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MissionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? isSimulation,
    Value<int?>? simulationSeed,
    Value<int?>? simulatedDay,
    Value<Uint8List>? subjectId,
    Value<String>? subjectLabel,
    Value<int>? startAtUs,
    Value<int>? referenceDays,
    Value<int>? plannedDays,
    Value<int>? createdAtUs,
    Value<int>? rowid,
  }) {
    return MissionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isSimulation: isSimulation ?? this.isSimulation,
      simulationSeed: simulationSeed ?? this.simulationSeed,
      simulatedDay: simulatedDay ?? this.simulatedDay,
      subjectId: subjectId ?? this.subjectId,
      subjectLabel: subjectLabel ?? this.subjectLabel,
      startAtUs: startAtUs ?? this.startAtUs,
      referenceDays: referenceDays ?? this.referenceDays,
      plannedDays: plannedDays ?? this.plannedDays,
      createdAtUs: createdAtUs ?? this.createdAtUs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isSimulation.present) {
      map['is_simulation'] = Variable<int>(isSimulation.value);
    }
    if (simulationSeed.present) {
      map['simulation_seed'] = Variable<int>(simulationSeed.value);
    }
    if (simulatedDay.present) {
      map['simulated_day'] = Variable<int>(simulatedDay.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<Uint8List>(subjectId.value);
    }
    if (subjectLabel.present) {
      map['subject_label'] = Variable<String>(subjectLabel.value);
    }
    if (startAtUs.present) {
      map['start_at_us'] = Variable<int>(startAtUs.value);
    }
    if (referenceDays.present) {
      map['reference_days'] = Variable<int>(referenceDays.value);
    }
    if (plannedDays.present) {
      map['planned_days'] = Variable<int>(plannedDays.value);
    }
    if (createdAtUs.present) {
      map['created_at_us'] = Variable<int>(createdAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MissionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isSimulation: $isSimulation, ')
          ..write('simulationSeed: $simulationSeed, ')
          ..write('simulatedDay: $simulatedDay, ')
          ..write('subjectId: $subjectId, ')
          ..write('subjectLabel: $subjectLabel, ')
          ..write('startAtUs: $startAtUs, ')
          ..write('referenceDays: $referenceDays, ')
          ..write('plannedDays: $plannedDays, ')
          ..write('createdAtUs: $createdAtUs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Measurements extends Table with TableInfo<Measurements, Measurement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Measurements(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<Uint8List> id = GeneratedColumn<Uint8List>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(id) = 16)',
  );
  static const VerificationMeta _missionIdMeta = const VerificationMeta(
    'missionId',
  );
  late final GeneratedColumn<String> missionId = GeneratedColumn<String>(
    'mission_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES missions(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  late final GeneratedColumn<Uint8List> subjectId = GeneratedColumn<Uint8List>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(subject_id) = 16)',
  );
  static const VerificationMeta _metricCodeMeta = const VerificationMeta(
    'metricCode',
  );
  late final GeneratedColumn<String> metricCode = GeneratedColumn<String>(
    'metric_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(metric_code) BETWEEN 1 AND 64)',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(unit) BETWEEN 1 AND 32)',
  );
  static const VerificationMeta _observedAtUsMeta = const VerificationMeta(
    'observedAtUs',
  );
  late final GeneratedColumn<int> observedAtUs = GeneratedColumn<int>(
    'observed_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  late final GeneratedColumn<int> method = GeneratedColumn<int>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (method BETWEEN 1 AND 4)',
  );
  static const VerificationMeta _provenanceMeta = const VerificationMeta(
    'provenance',
  );
  late final GeneratedColumn<int> provenance = GeneratedColumn<int>(
    'provenance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (provenance BETWEEN 1 AND 3)',
  );
  static const VerificationMeta _qualityFlagsMeta = const VerificationMeta(
    'qualityFlags',
  );
  late final GeneratedColumn<int> qualityFlags = GeneratedColumn<int>(
    'quality_flags',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (quality_flags >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _supersedesIdMeta = const VerificationMeta(
    'supersedesId',
  );
  late final GeneratedColumn<Uint8List> supersedesId =
      GeneratedColumn<Uint8List>(
        'supersedes_id',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
        $customConstraints: 'REFERENCES measurements(id)',
      );
  static const VerificationMeta _clientSeqMeta = const VerificationMeta(
    'clientSeq',
  );
  late final GeneratedColumn<int> clientSeq = GeneratedColumn<int>(
    'client_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (client_seq >= 1)',
  );
  static const VerificationMeta _prevHashMeta = const VerificationMeta(
    'prevHash',
  );
  late final GeneratedColumn<Uint8List> prevHash = GeneratedColumn<Uint8List>(
    'prev_hash',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(prev_hash) = 32)',
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  late final GeneratedColumn<Uint8List> hash = GeneratedColumn<Uint8List>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(hash) = 32)',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    missionId,
    subjectId,
    metricCode,
    value,
    unit,
    observedAtUs,
    method,
    provenance,
    qualityFlags,
    supersedesId,
    clientSeq,
    prevHash,
    hash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'measurements';
  @override
  VerificationContext validateIntegrity(
    Insertable<Measurement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mission_id')) {
      context.handle(
        _missionIdMeta,
        missionId.isAcceptableOrUnknown(data['mission_id']!, _missionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_missionIdMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('metric_code')) {
      context.handle(
        _metricCodeMeta,
        metricCode.isAcceptableOrUnknown(data['metric_code']!, _metricCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_metricCodeMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('observed_at_us')) {
      context.handle(
        _observedAtUsMeta,
        observedAtUs.isAcceptableOrUnknown(
          data['observed_at_us']!,
          _observedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_observedAtUsMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('provenance')) {
      context.handle(
        _provenanceMeta,
        provenance.isAcceptableOrUnknown(data['provenance']!, _provenanceMeta),
      );
    } else if (isInserting) {
      context.missing(_provenanceMeta);
    }
    if (data.containsKey('quality_flags')) {
      context.handle(
        _qualityFlagsMeta,
        qualityFlags.isAcceptableOrUnknown(
          data['quality_flags']!,
          _qualityFlagsMeta,
        ),
      );
    }
    if (data.containsKey('supersedes_id')) {
      context.handle(
        _supersedesIdMeta,
        supersedesId.isAcceptableOrUnknown(
          data['supersedes_id']!,
          _supersedesIdMeta,
        ),
      );
    }
    if (data.containsKey('client_seq')) {
      context.handle(
        _clientSeqMeta,
        clientSeq.isAcceptableOrUnknown(data['client_seq']!, _clientSeqMeta),
      );
    } else if (isInserting) {
      context.missing(_clientSeqMeta);
    }
    if (data.containsKey('prev_hash')) {
      context.handle(
        _prevHashMeta,
        prevHash.isAcceptableOrUnknown(data['prev_hash']!, _prevHashMeta),
      );
    } else if (isInserting) {
      context.missing(_prevHashMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {missionId, clientSeq},
  ];
  @override
  Measurement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Measurement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}id'],
      )!,
      missionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_id'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}subject_id'],
      )!,
      metricCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metric_code'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      observedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}observed_at_us'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}method'],
      )!,
      provenance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}provenance'],
      )!,
      qualityFlags: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality_flags'],
      )!,
      supersedesId: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}supersedes_id'],
      ),
      clientSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_seq'],
      )!,
      prevHash: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}prev_hash'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}hash'],
      )!,
    );
  }

  @override
  Measurements createAlias(String alias) {
    return Measurements(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => const [
    'UNIQUE(mission_id, client_seq)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class Measurement extends DataClass implements Insertable<Measurement> {
  final Uint8List id;
  final String missionId;
  final Uint8List subjectId;
  final String metricCode;
  final double value;
  final String unit;
  final int observedAtUs;

  /// rakia_method: 1 measured, 2 manual, 3 estimated, 4 derived.
  final int method;

  /// rakia_provenance: 1 real, 2 imported, 3 simulated.
  final int provenance;

  /// Bit 0: the device reported a sensor fault for this reading.
  final int qualityFlags;
  final Uint8List? supersedesId;
  final int clientSeq;
  final Uint8List prevHash;
  final Uint8List hash;
  const Measurement({
    required this.id,
    required this.missionId,
    required this.subjectId,
    required this.metricCode,
    required this.value,
    required this.unit,
    required this.observedAtUs,
    required this.method,
    required this.provenance,
    required this.qualityFlags,
    this.supersedesId,
    required this.clientSeq,
    required this.prevHash,
    required this.hash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<Uint8List>(id);
    map['mission_id'] = Variable<String>(missionId);
    map['subject_id'] = Variable<Uint8List>(subjectId);
    map['metric_code'] = Variable<String>(metricCode);
    map['value'] = Variable<double>(value);
    map['unit'] = Variable<String>(unit);
    map['observed_at_us'] = Variable<int>(observedAtUs);
    map['method'] = Variable<int>(method);
    map['provenance'] = Variable<int>(provenance);
    map['quality_flags'] = Variable<int>(qualityFlags);
    if (!nullToAbsent || supersedesId != null) {
      map['supersedes_id'] = Variable<Uint8List>(supersedesId);
    }
    map['client_seq'] = Variable<int>(clientSeq);
    map['prev_hash'] = Variable<Uint8List>(prevHash);
    map['hash'] = Variable<Uint8List>(hash);
    return map;
  }

  MeasurementsCompanion toCompanion(bool nullToAbsent) {
    return MeasurementsCompanion(
      id: Value(id),
      missionId: Value(missionId),
      subjectId: Value(subjectId),
      metricCode: Value(metricCode),
      value: Value(value),
      unit: Value(unit),
      observedAtUs: Value(observedAtUs),
      method: Value(method),
      provenance: Value(provenance),
      qualityFlags: Value(qualityFlags),
      supersedesId: supersedesId == null && nullToAbsent
          ? const Value.absent()
          : Value(supersedesId),
      clientSeq: Value(clientSeq),
      prevHash: Value(prevHash),
      hash: Value(hash),
    );
  }

  factory Measurement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Measurement(
      id: serializer.fromJson<Uint8List>(json['id']),
      missionId: serializer.fromJson<String>(json['mission_id']),
      subjectId: serializer.fromJson<Uint8List>(json['subject_id']),
      metricCode: serializer.fromJson<String>(json['metric_code']),
      value: serializer.fromJson<double>(json['value']),
      unit: serializer.fromJson<String>(json['unit']),
      observedAtUs: serializer.fromJson<int>(json['observed_at_us']),
      method: serializer.fromJson<int>(json['method']),
      provenance: serializer.fromJson<int>(json['provenance']),
      qualityFlags: serializer.fromJson<int>(json['quality_flags']),
      supersedesId: serializer.fromJson<Uint8List?>(json['supersedes_id']),
      clientSeq: serializer.fromJson<int>(json['client_seq']),
      prevHash: serializer.fromJson<Uint8List>(json['prev_hash']),
      hash: serializer.fromJson<Uint8List>(json['hash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<Uint8List>(id),
      'mission_id': serializer.toJson<String>(missionId),
      'subject_id': serializer.toJson<Uint8List>(subjectId),
      'metric_code': serializer.toJson<String>(metricCode),
      'value': serializer.toJson<double>(value),
      'unit': serializer.toJson<String>(unit),
      'observed_at_us': serializer.toJson<int>(observedAtUs),
      'method': serializer.toJson<int>(method),
      'provenance': serializer.toJson<int>(provenance),
      'quality_flags': serializer.toJson<int>(qualityFlags),
      'supersedes_id': serializer.toJson<Uint8List?>(supersedesId),
      'client_seq': serializer.toJson<int>(clientSeq),
      'prev_hash': serializer.toJson<Uint8List>(prevHash),
      'hash': serializer.toJson<Uint8List>(hash),
    };
  }

  Measurement copyWith({
    Uint8List? id,
    String? missionId,
    Uint8List? subjectId,
    String? metricCode,
    double? value,
    String? unit,
    int? observedAtUs,
    int? method,
    int? provenance,
    int? qualityFlags,
    Value<Uint8List?> supersedesId = const Value.absent(),
    int? clientSeq,
    Uint8List? prevHash,
    Uint8List? hash,
  }) => Measurement(
    id: id ?? this.id,
    missionId: missionId ?? this.missionId,
    subjectId: subjectId ?? this.subjectId,
    metricCode: metricCode ?? this.metricCode,
    value: value ?? this.value,
    unit: unit ?? this.unit,
    observedAtUs: observedAtUs ?? this.observedAtUs,
    method: method ?? this.method,
    provenance: provenance ?? this.provenance,
    qualityFlags: qualityFlags ?? this.qualityFlags,
    supersedesId: supersedesId.present ? supersedesId.value : this.supersedesId,
    clientSeq: clientSeq ?? this.clientSeq,
    prevHash: prevHash ?? this.prevHash,
    hash: hash ?? this.hash,
  );
  Measurement copyWithCompanion(MeasurementsCompanion data) {
    return Measurement(
      id: data.id.present ? data.id.value : this.id,
      missionId: data.missionId.present ? data.missionId.value : this.missionId,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      metricCode: data.metricCode.present
          ? data.metricCode.value
          : this.metricCode,
      value: data.value.present ? data.value.value : this.value,
      unit: data.unit.present ? data.unit.value : this.unit,
      observedAtUs: data.observedAtUs.present
          ? data.observedAtUs.value
          : this.observedAtUs,
      method: data.method.present ? data.method.value : this.method,
      provenance: data.provenance.present
          ? data.provenance.value
          : this.provenance,
      qualityFlags: data.qualityFlags.present
          ? data.qualityFlags.value
          : this.qualityFlags,
      supersedesId: data.supersedesId.present
          ? data.supersedesId.value
          : this.supersedesId,
      clientSeq: data.clientSeq.present ? data.clientSeq.value : this.clientSeq,
      prevHash: data.prevHash.present ? data.prevHash.value : this.prevHash,
      hash: data.hash.present ? data.hash.value : this.hash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Measurement(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('subjectId: $subjectId, ')
          ..write('metricCode: $metricCode, ')
          ..write('value: $value, ')
          ..write('unit: $unit, ')
          ..write('observedAtUs: $observedAtUs, ')
          ..write('method: $method, ')
          ..write('provenance: $provenance, ')
          ..write('qualityFlags: $qualityFlags, ')
          ..write('supersedesId: $supersedesId, ')
          ..write('clientSeq: $clientSeq, ')
          ..write('prevHash: $prevHash, ')
          ..write('hash: $hash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    $driftBlobEquality.hash(id),
    missionId,
    $driftBlobEquality.hash(subjectId),
    metricCode,
    value,
    unit,
    observedAtUs,
    method,
    provenance,
    qualityFlags,
    $driftBlobEquality.hash(supersedesId),
    clientSeq,
    $driftBlobEquality.hash(prevHash),
    $driftBlobEquality.hash(hash),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Measurement &&
          $driftBlobEquality.equals(other.id, this.id) &&
          other.missionId == this.missionId &&
          $driftBlobEquality.equals(other.subjectId, this.subjectId) &&
          other.metricCode == this.metricCode &&
          other.value == this.value &&
          other.unit == this.unit &&
          other.observedAtUs == this.observedAtUs &&
          other.method == this.method &&
          other.provenance == this.provenance &&
          other.qualityFlags == this.qualityFlags &&
          $driftBlobEquality.equals(other.supersedesId, this.supersedesId) &&
          other.clientSeq == this.clientSeq &&
          $driftBlobEquality.equals(other.prevHash, this.prevHash) &&
          $driftBlobEquality.equals(other.hash, this.hash));
}

class MeasurementsCompanion extends UpdateCompanion<Measurement> {
  final Value<Uint8List> id;
  final Value<String> missionId;
  final Value<Uint8List> subjectId;
  final Value<String> metricCode;
  final Value<double> value;
  final Value<String> unit;
  final Value<int> observedAtUs;
  final Value<int> method;
  final Value<int> provenance;
  final Value<int> qualityFlags;
  final Value<Uint8List?> supersedesId;
  final Value<int> clientSeq;
  final Value<Uint8List> prevHash;
  final Value<Uint8List> hash;
  final Value<int> rowid;
  const MeasurementsCompanion({
    this.id = const Value.absent(),
    this.missionId = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.metricCode = const Value.absent(),
    this.value = const Value.absent(),
    this.unit = const Value.absent(),
    this.observedAtUs = const Value.absent(),
    this.method = const Value.absent(),
    this.provenance = const Value.absent(),
    this.qualityFlags = const Value.absent(),
    this.supersedesId = const Value.absent(),
    this.clientSeq = const Value.absent(),
    this.prevHash = const Value.absent(),
    this.hash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MeasurementsCompanion.insert({
    required Uint8List id,
    required String missionId,
    required Uint8List subjectId,
    required String metricCode,
    required double value,
    required String unit,
    required int observedAtUs,
    required int method,
    required int provenance,
    this.qualityFlags = const Value.absent(),
    this.supersedesId = const Value.absent(),
    required int clientSeq,
    required Uint8List prevHash,
    required Uint8List hash,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       missionId = Value(missionId),
       subjectId = Value(subjectId),
       metricCode = Value(metricCode),
       value = Value(value),
       unit = Value(unit),
       observedAtUs = Value(observedAtUs),
       method = Value(method),
       provenance = Value(provenance),
       clientSeq = Value(clientSeq),
       prevHash = Value(prevHash),
       hash = Value(hash);
  static Insertable<Measurement> custom({
    Expression<Uint8List>? id,
    Expression<String>? missionId,
    Expression<Uint8List>? subjectId,
    Expression<String>? metricCode,
    Expression<double>? value,
    Expression<String>? unit,
    Expression<int>? observedAtUs,
    Expression<int>? method,
    Expression<int>? provenance,
    Expression<int>? qualityFlags,
    Expression<Uint8List>? supersedesId,
    Expression<int>? clientSeq,
    Expression<Uint8List>? prevHash,
    Expression<Uint8List>? hash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (missionId != null) 'mission_id': missionId,
      if (subjectId != null) 'subject_id': subjectId,
      if (metricCode != null) 'metric_code': metricCode,
      if (value != null) 'value': value,
      if (unit != null) 'unit': unit,
      if (observedAtUs != null) 'observed_at_us': observedAtUs,
      if (method != null) 'method': method,
      if (provenance != null) 'provenance': provenance,
      if (qualityFlags != null) 'quality_flags': qualityFlags,
      if (supersedesId != null) 'supersedes_id': supersedesId,
      if (clientSeq != null) 'client_seq': clientSeq,
      if (prevHash != null) 'prev_hash': prevHash,
      if (hash != null) 'hash': hash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MeasurementsCompanion copyWith({
    Value<Uint8List>? id,
    Value<String>? missionId,
    Value<Uint8List>? subjectId,
    Value<String>? metricCode,
    Value<double>? value,
    Value<String>? unit,
    Value<int>? observedAtUs,
    Value<int>? method,
    Value<int>? provenance,
    Value<int>? qualityFlags,
    Value<Uint8List?>? supersedesId,
    Value<int>? clientSeq,
    Value<Uint8List>? prevHash,
    Value<Uint8List>? hash,
    Value<int>? rowid,
  }) {
    return MeasurementsCompanion(
      id: id ?? this.id,
      missionId: missionId ?? this.missionId,
      subjectId: subjectId ?? this.subjectId,
      metricCode: metricCode ?? this.metricCode,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      observedAtUs: observedAtUs ?? this.observedAtUs,
      method: method ?? this.method,
      provenance: provenance ?? this.provenance,
      qualityFlags: qualityFlags ?? this.qualityFlags,
      supersedesId: supersedesId ?? this.supersedesId,
      clientSeq: clientSeq ?? this.clientSeq,
      prevHash: prevHash ?? this.prevHash,
      hash: hash ?? this.hash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<Uint8List>(id.value);
    }
    if (missionId.present) {
      map['mission_id'] = Variable<String>(missionId.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<Uint8List>(subjectId.value);
    }
    if (metricCode.present) {
      map['metric_code'] = Variable<String>(metricCode.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (observedAtUs.present) {
      map['observed_at_us'] = Variable<int>(observedAtUs.value);
    }
    if (method.present) {
      map['method'] = Variable<int>(method.value);
    }
    if (provenance.present) {
      map['provenance'] = Variable<int>(provenance.value);
    }
    if (qualityFlags.present) {
      map['quality_flags'] = Variable<int>(qualityFlags.value);
    }
    if (supersedesId.present) {
      map['supersedes_id'] = Variable<Uint8List>(supersedesId.value);
    }
    if (clientSeq.present) {
      map['client_seq'] = Variable<int>(clientSeq.value);
    }
    if (prevHash.present) {
      map['prev_hash'] = Variable<Uint8List>(prevHash.value);
    }
    if (hash.present) {
      map['hash'] = Variable<Uint8List>(hash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeasurementsCompanion(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('subjectId: $subjectId, ')
          ..write('metricCode: $metricCode, ')
          ..write('value: $value, ')
          ..write('unit: $unit, ')
          ..write('observedAtUs: $observedAtUs, ')
          ..write('method: $method, ')
          ..write('provenance: $provenance, ')
          ..write('qualityFlags: $qualityFlags, ')
          ..write('supersedesId: $supersedesId, ')
          ..write('clientSeq: $clientSeq, ')
          ..write('prevHash: $prevHash, ')
          ..write('hash: $hash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$RakiaDatabase extends GeneratedDatabase {
  _$RakiaDatabase(QueryExecutor e) : super(e);
  $RakiaDatabaseManager get managers => $RakiaDatabaseManager(this);
  late final Settings settings = Settings(this);
  late final Missions missions = Missions(this);
  late final Measurements measurements = Measurements(this);
  late final Index measurementsByMetric = Index(
    'measurements_by_metric',
    'CREATE INDEX measurements_by_metric ON measurements (mission_id, metric_code, observed_at_us)',
  );
  late final Trigger measurementsImmutable = Trigger(
    'CREATE TRIGGER measurements_immutable BEFORE UPDATE ON measurements BEGIN SELECT RAISE (ABORT, \'rakia: measurements are immutable\');END',
    'measurements_immutable',
  );
  late final Trigger measurementsSimulationFirewall = Trigger(
    'CREATE TRIGGER measurements_simulation_firewall BEFORE INSERT ON measurements WHEN(NEW.provenance = 3)<> (SELECT is_simulation = 1 FROM missions WHERE id = NEW.mission_id) BEGIN SELECT RAISE (ABORT, \'rakia: simulation firewall\');END',
    'measurements_simulation_firewall',
  );
  late final Trigger measurementsSubjectMatchesMission = Trigger(
    'CREATE TRIGGER measurements_subject_matches_mission BEFORE INSERT ON measurements WHEN NEW.subject_id IS NOT (SELECT subject_id FROM missions WHERE id = NEW.mission_id) BEGIN SELECT RAISE (ABORT, \'rakia: subject does not match the mission\');END',
    'measurements_subject_matches_mission',
  );
  late final Trigger measurementsChainContinuity = Trigger(
    'CREATE TRIGGER measurements_chain_continuity BEFORE INSERT ON measurements WHEN NEW.client_seq <> COALESCE((SELECT MAX(client_seq) FROM measurements WHERE mission_id = NEW.mission_id), 0) + 1 OR NEW.prev_hash IS NOT COALESCE((SELECT hash FROM measurements WHERE mission_id = NEW.mission_id AND client_seq = NEW.client_seq - 1), zeroblob(32)) BEGIN SELECT RAISE (ABORT, \'rakia: ledger chain is not continuous\');END',
    'measurements_chain_continuity',
  );
  late final Trigger measurementsDeleteSimulationOnly = Trigger(
    'CREATE TRIGGER measurements_delete_simulation_only BEFORE DELETE ON measurements WHEN (SELECT is_simulation FROM missions WHERE id = OLD.mission_id) = 0 BEGIN SELECT RAISE (ABORT, \'rakia: only simulation data can be deleted\');END',
    'measurements_delete_simulation_only',
  );
  late final Trigger missionsIdentityImmutable = Trigger(
    'CREATE TRIGGER missions_identity_immutable BEFORE UPDATE OF id, is_simulation, simulation_seed, subject_id, start_at_us ON missions BEGIN SELECT RAISE (ABORT, \'rakia: a mission\'\'s identity cannot change\');END',
    'missions_identity_immutable',
  );
  late final Trigger missionsDeleteSimulationOnly = Trigger(
    'CREATE TRIGGER missions_delete_simulation_only BEFORE DELETE ON missions WHEN OLD.is_simulation = 0 BEGIN SELECT RAISE (ABORT, \'rakia: only simulation missions can be deleted\');END',
    'missions_delete_simulation_only',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settings,
    missions,
    measurements,
    measurementsByMetric,
    measurementsImmutable,
    measurementsSimulationFirewall,
    measurementsSubjectMatchesMission,
    measurementsChainContinuity,
    measurementsDeleteSimulationOnly,
    missionsIdentityImmutable,
    missionsDeleteSimulationOnly,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'missions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('measurements', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'measurements',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'measurements',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'measurements',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'measurements',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'measurements',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'missions',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'missions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [],
    ),
  ]);
}

typedef $SettingsCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $SettingsUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $SettingsFilterComposer extends Composer<_$RakiaDatabase, Settings> {
  $SettingsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $SettingsOrderingComposer extends Composer<_$RakiaDatabase, Settings> {
  $SettingsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SettingsAnnotationComposer extends Composer<_$RakiaDatabase, Settings> {
  $SettingsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $SettingsTableManager
    extends
        RootTableManager<
          _$RakiaDatabase,
          Settings,
          Setting,
          $SettingsFilterComposer,
          $SettingsOrderingComposer,
          $SettingsAnnotationComposer,
          $SettingsCreateCompanionBuilder,
          $SettingsUpdateCompanionBuilder,
          (Setting, BaseReferences<_$RakiaDatabase, Settings, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $SettingsTableManager(_$RakiaDatabase db, Settings table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SettingsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SettingsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SettingsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Settings, Setting>(table),
                  BaseReferences<_$RakiaDatabase, Settings, Setting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SettingsProcessedTableManager =
    ProcessedTableManager<
      _$RakiaDatabase,
      Settings,
      Setting,
      $SettingsFilterComposer,
      $SettingsOrderingComposer,
      $SettingsAnnotationComposer,
      $SettingsCreateCompanionBuilder,
      $SettingsUpdateCompanionBuilder,
      (Setting, BaseReferences<_$RakiaDatabase, Settings, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $MissionsCreateCompanionBuilder = MissionsCompanion Function({
  required String id,
  required String name,
  required int isSimulation,
  Value<int?> simulationSeed,
  Value<int?> simulatedDay,
  required Uint8List subjectId,
  required String subjectLabel,
  required int startAtUs,
  required int referenceDays,
  required int plannedDays,
  required int createdAtUs,
  Value<int> rowid,
});
typedef $MissionsUpdateCompanionBuilder = MissionsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> isSimulation,
  Value<int?> simulationSeed,
  Value<int?> simulatedDay,
  Value<Uint8List> subjectId,
  Value<String> subjectLabel,
  Value<int> startAtUs,
  Value<int> referenceDays,
  Value<int> plannedDays,
  Value<int> createdAtUs,
  Value<int> rowid,
});

final class $MissionsReferences
    extends BaseReferences<_$RakiaDatabase, Missions, Mission> {
  $MissionsReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<Measurements, List<Measurement>>
  _measurementsRefsTable(_$RakiaDatabase db) => MultiTypedResultKey.fromTable(
    db.measurements,
    aliasName: 'missions__id__measurements__mission_id',
  );

  $MeasurementsProcessedTableManager get measurementsRefs {
    final manager = $MeasurementsTableManager(
      $_db,
      $_db.measurements,
    ).filter((f) => f.missionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_measurementsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $MissionsFilterComposer extends Composer<_$RakiaDatabase, Missions> {
  $MissionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isSimulation => $composableBuilder(
    column: $table.isSimulation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get simulationSeed => $composableBuilder(
    column: $table.simulationSeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get simulatedDay => $composableBuilder(
    column: $table.simulatedDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectLabel => $composableBuilder(
    column: $table.subjectLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startAtUs => $composableBuilder(
    column: $table.startAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get referenceDays => $composableBuilder(
    column: $table.referenceDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedDays => $composableBuilder(
    column: $table.plannedDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> measurementsRefs(
    Expression<bool> Function($MeasurementsFilterComposer f) f,
  ) {
    final $MeasurementsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.measurements,
      getReferencedColumn: (t) => t.missionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MeasurementsFilterComposer(
            $db: $db,
            $table: $db.measurements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $MissionsOrderingComposer extends Composer<_$RakiaDatabase, Missions> {
  $MissionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isSimulation => $composableBuilder(
    column: $table.isSimulation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get simulationSeed => $composableBuilder(
    column: $table.simulationSeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get simulatedDay => $composableBuilder(
    column: $table.simulatedDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectLabel => $composableBuilder(
    column: $table.subjectLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startAtUs => $composableBuilder(
    column: $table.startAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get referenceDays => $composableBuilder(
    column: $table.referenceDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedDays => $composableBuilder(
    column: $table.plannedDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $MissionsAnnotationComposer extends Composer<_$RakiaDatabase, Missions> {
  $MissionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get isSimulation => $composableBuilder(
    column: $table.isSimulation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get simulationSeed => $composableBuilder(
    column: $table.simulationSeed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get simulatedDay => $composableBuilder(
    column: $table.simulatedDay,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get subjectLabel => $composableBuilder(
    column: $table.subjectLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startAtUs =>
      $composableBuilder(column: $table.startAtUs, builder: (column) => column);

  GeneratedColumn<int> get referenceDays => $composableBuilder(
    column: $table.referenceDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plannedDays => $composableBuilder(
    column: $table.plannedDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUs => $composableBuilder(
    column: $table.createdAtUs,
    builder: (column) => column,
  );

  Expression<T> measurementsRefs<T extends Object>(
    Expression<T> Function($MeasurementsAnnotationComposer a) f,
  ) {
    final $MeasurementsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.measurements,
      getReferencedColumn: (t) => t.missionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MeasurementsAnnotationComposer(
            $db: $db,
            $table: $db.measurements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $MissionsTableManager
    extends
        RootTableManager<
          _$RakiaDatabase,
          Missions,
          Mission,
          $MissionsFilterComposer,
          $MissionsOrderingComposer,
          $MissionsAnnotationComposer,
          $MissionsCreateCompanionBuilder,
          $MissionsUpdateCompanionBuilder,
          (Mission, $MissionsReferences),
          Mission,
          PrefetchHooks Function({bool measurementsRefs})
        > {
  $MissionsTableManager(_$RakiaDatabase db, Missions table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MissionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MissionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MissionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> isSimulation = const Value.absent(),
                Value<int?> simulationSeed = const Value.absent(),
                Value<int?> simulatedDay = const Value.absent(),
                Value<Uint8List> subjectId = const Value.absent(),
                Value<String> subjectLabel = const Value.absent(),
                Value<int> startAtUs = const Value.absent(),
                Value<int> referenceDays = const Value.absent(),
                Value<int> plannedDays = const Value.absent(),
                Value<int> createdAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MissionsCompanion(
                id: id,
                name: name,
                isSimulation: isSimulation,
                simulationSeed: simulationSeed,
                simulatedDay: simulatedDay,
                subjectId: subjectId,
                subjectLabel: subjectLabel,
                startAtUs: startAtUs,
                referenceDays: referenceDays,
                plannedDays: plannedDays,
                createdAtUs: createdAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int isSimulation,
                Value<int?> simulationSeed = const Value.absent(),
                Value<int?> simulatedDay = const Value.absent(),
                required Uint8List subjectId,
                required String subjectLabel,
                required int startAtUs,
                required int referenceDays,
                required int plannedDays,
                required int createdAtUs,
                Value<int> rowid = const Value.absent(),
              }) => MissionsCompanion.insert(
                id: id,
                name: name,
                isSimulation: isSimulation,
                simulationSeed: simulationSeed,
                simulatedDay: simulatedDay,
                subjectId: subjectId,
                subjectLabel: subjectLabel,
                startAtUs: startAtUs,
                referenceDays: referenceDays,
                plannedDays: plannedDays,
                createdAtUs: createdAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Missions, Mission>(table),
                  $MissionsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({measurementsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (measurementsRefs) db.measurements],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (measurementsRefs)
                    await $_getPrefetchedDataByColumns<
                      Mission,
                      Missions,
                      Measurement,
                      Measurements
                    >(
                      currentTable: table,
                      referencedTable: $MissionsReferences
                          ._measurementsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $MissionsReferences(db, table, p0).measurementsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'mission_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $MissionsProcessedTableManager =
    ProcessedTableManager<
      _$RakiaDatabase,
      Missions,
      Mission,
      $MissionsFilterComposer,
      $MissionsOrderingComposer,
      $MissionsAnnotationComposer,
      $MissionsCreateCompanionBuilder,
      $MissionsUpdateCompanionBuilder,
      (Mission, $MissionsReferences),
      Mission,
      PrefetchHooks Function({bool measurementsRefs})
    >;
typedef $MeasurementsCreateCompanionBuilder = MeasurementsCompanion Function({
  required Uint8List id,
  required String missionId,
  required Uint8List subjectId,
  required String metricCode,
  required double value,
  required String unit,
  required int observedAtUs,
  required int method,
  required int provenance,
  Value<int> qualityFlags,
  Value<Uint8List?> supersedesId,
  required int clientSeq,
  required Uint8List prevHash,
  required Uint8List hash,
  Value<int> rowid,
});
typedef $MeasurementsUpdateCompanionBuilder = MeasurementsCompanion Function({
  Value<Uint8List> id,
  Value<String> missionId,
  Value<Uint8List> subjectId,
  Value<String> metricCode,
  Value<double> value,
  Value<String> unit,
  Value<int> observedAtUs,
  Value<int> method,
  Value<int> provenance,
  Value<int> qualityFlags,
  Value<Uint8List?> supersedesId,
  Value<int> clientSeq,
  Value<Uint8List> prevHash,
  Value<Uint8List> hash,
  Value<int> rowid,
});

final class $MeasurementsReferences
    extends BaseReferences<_$RakiaDatabase, Measurements, Measurement> {
  $MeasurementsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Missions _missionIdTable(_$RakiaDatabase db) =>
      db.missions.createAlias('measurements__mission_id__missions__id');

  $MissionsProcessedTableManager get missionId {
    final $_column = $_itemColumn<String>('mission_id')!;

    final manager = $MissionsTableManager(
      $_db,
      $_db.missions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_missionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static Measurements _supersedesIdTable(_$RakiaDatabase db) => db.measurements
      .createAlias('measurements__supersedes_id__measurements__id');

  $MeasurementsProcessedTableManager? get supersedesId {
    final $_column = $_itemColumn<Uint8List>('supersedes_id');
    if ($_column == null) return null;
    final manager = $MeasurementsTableManager(
      $_db,
      $_db.measurements,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_supersedesIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $MeasurementsFilterComposer
    extends Composer<_$RakiaDatabase, Measurements> {
  $MeasurementsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metricCode => $composableBuilder(
    column: $table.metricCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get observedAtUs => $composableBuilder(
    column: $table.observedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get provenance => $composableBuilder(
    column: $table.provenance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get qualityFlags => $composableBuilder(
    column: $table.qualityFlags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clientSeq => $composableBuilder(
    column: $table.clientSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get prevHash => $composableBuilder(
    column: $table.prevHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  $MissionsFilterComposer get missionId {
    final $MissionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MissionsFilterComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $MeasurementsFilterComposer get supersedesId {
    final $MeasurementsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supersedesId,
      referencedTable: $db.measurements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MeasurementsFilterComposer(
            $db: $db,
            $table: $db.measurements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MeasurementsOrderingComposer
    extends Composer<_$RakiaDatabase, Measurements> {
  $MeasurementsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metricCode => $composableBuilder(
    column: $table.metricCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get observedAtUs => $composableBuilder(
    column: $table.observedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get provenance => $composableBuilder(
    column: $table.provenance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get qualityFlags => $composableBuilder(
    column: $table.qualityFlags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clientSeq => $composableBuilder(
    column: $table.clientSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get prevHash => $composableBuilder(
    column: $table.prevHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  $MissionsOrderingComposer get missionId {
    final $MissionsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MissionsOrderingComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $MeasurementsOrderingComposer get supersedesId {
    final $MeasurementsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supersedesId,
      referencedTable: $db.measurements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MeasurementsOrderingComposer(
            $db: $db,
            $table: $db.measurements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MeasurementsAnnotationComposer
    extends Composer<_$RakiaDatabase, Measurements> {
  $MeasurementsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get metricCode => $composableBuilder(
    column: $table.metricCode,
    builder: (column) => column,
  );

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get observedAtUs => $composableBuilder(
    column: $table.observedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<int> get provenance => $composableBuilder(
    column: $table.provenance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get qualityFlags => $composableBuilder(
    column: $table.qualityFlags,
    builder: (column) => column,
  );

  GeneratedColumn<int> get clientSeq =>
      $composableBuilder(column: $table.clientSeq, builder: (column) => column);

  GeneratedColumn<Uint8List> get prevHash =>
      $composableBuilder(column: $table.prevHash, builder: (column) => column);

  GeneratedColumn<Uint8List> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  $MissionsAnnotationComposer get missionId {
    final $MissionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.missionId,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MissionsAnnotationComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $MeasurementsAnnotationComposer get supersedesId {
    final $MeasurementsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supersedesId,
      referencedTable: $db.measurements,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $MeasurementsAnnotationComposer(
            $db: $db,
            $table: $db.measurements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $MeasurementsTableManager
    extends
        RootTableManager<
          _$RakiaDatabase,
          Measurements,
          Measurement,
          $MeasurementsFilterComposer,
          $MeasurementsOrderingComposer,
          $MeasurementsAnnotationComposer,
          $MeasurementsCreateCompanionBuilder,
          $MeasurementsUpdateCompanionBuilder,
          (Measurement, $MeasurementsReferences),
          Measurement,
          PrefetchHooks Function({bool missionId, bool supersedesId})
        > {
  $MeasurementsTableManager(_$RakiaDatabase db, Measurements table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MeasurementsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MeasurementsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MeasurementsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Uint8List> id = const Value.absent(),
                Value<String> missionId = const Value.absent(),
                Value<Uint8List> subjectId = const Value.absent(),
                Value<String> metricCode = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<int> observedAtUs = const Value.absent(),
                Value<int> method = const Value.absent(),
                Value<int> provenance = const Value.absent(),
                Value<int> qualityFlags = const Value.absent(),
                Value<Uint8List?> supersedesId = const Value.absent(),
                Value<int> clientSeq = const Value.absent(),
                Value<Uint8List> prevHash = const Value.absent(),
                Value<Uint8List> hash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MeasurementsCompanion(
                id: id,
                missionId: missionId,
                subjectId: subjectId,
                metricCode: metricCode,
                value: value,
                unit: unit,
                observedAtUs: observedAtUs,
                method: method,
                provenance: provenance,
                qualityFlags: qualityFlags,
                supersedesId: supersedesId,
                clientSeq: clientSeq,
                prevHash: prevHash,
                hash: hash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required Uint8List id,
                required String missionId,
                required Uint8List subjectId,
                required String metricCode,
                required double value,
                required String unit,
                required int observedAtUs,
                required int method,
                required int provenance,
                Value<int> qualityFlags = const Value.absent(),
                Value<Uint8List?> supersedesId = const Value.absent(),
                required int clientSeq,
                required Uint8List prevHash,
                required Uint8List hash,
                Value<int> rowid = const Value.absent(),
              }) => MeasurementsCompanion.insert(
                id: id,
                missionId: missionId,
                subjectId: subjectId,
                metricCode: metricCode,
                value: value,
                unit: unit,
                observedAtUs: observedAtUs,
                method: method,
                provenance: provenance,
                qualityFlags: qualityFlags,
                supersedesId: supersedesId,
                clientSeq: clientSeq,
                prevHash: prevHash,
                hash: hash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Measurements, Measurement>(table),
                  $MeasurementsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({missionId = false, supersedesId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (missionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.missionId,
                        referencedTable: $MeasurementsReferences
                            ._missionIdTable(db),
                        referencedColumn: $MeasurementsReferences
                            ._missionIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (supersedesId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.supersedesId,
                        referencedTable: $MeasurementsReferences
                            ._supersedesIdTable(db),
                        referencedColumn: $MeasurementsReferences
                            ._supersedesIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $MeasurementsProcessedTableManager =
    ProcessedTableManager<
      _$RakiaDatabase,
      Measurements,
      Measurement,
      $MeasurementsFilterComposer,
      $MeasurementsOrderingComposer,
      $MeasurementsAnnotationComposer,
      $MeasurementsCreateCompanionBuilder,
      $MeasurementsUpdateCompanionBuilder,
      (Measurement, $MeasurementsReferences),
      Measurement,
      PrefetchHooks Function({bool missionId, bool supersedesId})
    >;

class $RakiaDatabaseManager {
  final _$RakiaDatabase _db;
  $RakiaDatabaseManager(this._db);
  $SettingsTableManager get settings =>
      $SettingsTableManager(_db, _db.settings);
  $MissionsTableManager get missions =>
      $MissionsTableManager(_db, _db.missions);
  $MeasurementsTableManager get measurements =>
      $MeasurementsTableManager(_db, _db.measurements);
}
