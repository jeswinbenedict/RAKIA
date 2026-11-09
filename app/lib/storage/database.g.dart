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

class SelfCheckins extends Table with TableInfo<SelfCheckins, SelfCheckin> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SelfCheckins(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<Uint8List> id = GeneratedColumn<Uint8List>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(id) = 16)',
  );
  static const VerificationMeta _recordedAtUsMeta = const VerificationMeta(
    'recordedAtUs',
  );
  late final GeneratedColumn<int> recordedAtUs = GeneratedColumn<int>(
    'recorded_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sleepinessMeta = const VerificationMeta(
    'sleepiness',
  );
  late final GeneratedColumn<int> sleepiness = GeneratedColumn<int>(
    'sleepiness',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (sleepiness BETWEEN 1 AND 9)',
  );
  static const VerificationMeta _stressMeta = const VerificationMeta('stress');
  late final GeneratedColumn<int> stress = GeneratedColumn<int>(
    'stress',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (stress BETWEEN 1 AND 5)',
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  late final GeneratedColumn<int> mood = GeneratedColumn<int>(
    'mood',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (mood BETWEEN 1 AND 5)',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordedAtUs,
    sleepiness,
    stress,
    mood,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'self_checkins';
  @override
  VerificationContext validateIntegrity(
    Insertable<SelfCheckin> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('recorded_at_us')) {
      context.handle(
        _recordedAtUsMeta,
        recordedAtUs.isAcceptableOrUnknown(
          data['recorded_at_us']!,
          _recordedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordedAtUsMeta);
    }
    if (data.containsKey('sleepiness')) {
      context.handle(
        _sleepinessMeta,
        sleepiness.isAcceptableOrUnknown(data['sleepiness']!, _sleepinessMeta),
      );
    } else if (isInserting) {
      context.missing(_sleepinessMeta);
    }
    if (data.containsKey('stress')) {
      context.handle(
        _stressMeta,
        stress.isAcceptableOrUnknown(data['stress']!, _stressMeta),
      );
    } else if (isInserting) {
      context.missing(_stressMeta);
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    } else if (isInserting) {
      context.missing(_moodMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SelfCheckin map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SelfCheckin(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}id'],
      )!,
      recordedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recorded_at_us'],
      )!,
      sleepiness: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sleepiness'],
      )!,
      stress: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stress'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mood'],
      )!,
    );
  }

  @override
  SelfCheckins createAlias(String alias) {
    return SelfCheckins(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  bool get dontWriteConstraints => true;
}

class SelfCheckin extends DataClass implements Insertable<SelfCheckin> {
  final Uint8List id;
  final int recordedAtUs;

  /// Karolinska Sleepiness Scale: 1 extremely alert ... 9 very sleepy,
  /// fighting sleep (Akerstedt and Gillberg, 1990).
  final int sleepiness;

  /// Single-item measure of stress symptoms: 1 not at all ... 5 very much
  /// (Elo, Leppanen and Jahkola, 2003).
  final int stress;

  /// A plain mood self-rating, 1 very low ... 5 very good. Not a validated
  /// clinical scale; the app says so.
  final int mood;
  const SelfCheckin({
    required this.id,
    required this.recordedAtUs,
    required this.sleepiness,
    required this.stress,
    required this.mood,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<Uint8List>(id);
    map['recorded_at_us'] = Variable<int>(recordedAtUs);
    map['sleepiness'] = Variable<int>(sleepiness);
    map['stress'] = Variable<int>(stress);
    map['mood'] = Variable<int>(mood);
    return map;
  }

  SelfCheckinsCompanion toCompanion(bool nullToAbsent) {
    return SelfCheckinsCompanion(
      id: Value(id),
      recordedAtUs: Value(recordedAtUs),
      sleepiness: Value(sleepiness),
      stress: Value(stress),
      mood: Value(mood),
    );
  }

  factory SelfCheckin.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SelfCheckin(
      id: serializer.fromJson<Uint8List>(json['id']),
      recordedAtUs: serializer.fromJson<int>(json['recorded_at_us']),
      sleepiness: serializer.fromJson<int>(json['sleepiness']),
      stress: serializer.fromJson<int>(json['stress']),
      mood: serializer.fromJson<int>(json['mood']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<Uint8List>(id),
      'recorded_at_us': serializer.toJson<int>(recordedAtUs),
      'sleepiness': serializer.toJson<int>(sleepiness),
      'stress': serializer.toJson<int>(stress),
      'mood': serializer.toJson<int>(mood),
    };
  }

  SelfCheckin copyWith({
    Uint8List? id,
    int? recordedAtUs,
    int? sleepiness,
    int? stress,
    int? mood,
  }) => SelfCheckin(
    id: id ?? this.id,
    recordedAtUs: recordedAtUs ?? this.recordedAtUs,
    sleepiness: sleepiness ?? this.sleepiness,
    stress: stress ?? this.stress,
    mood: mood ?? this.mood,
  );
  SelfCheckin copyWithCompanion(SelfCheckinsCompanion data) {
    return SelfCheckin(
      id: data.id.present ? data.id.value : this.id,
      recordedAtUs: data.recordedAtUs.present
          ? data.recordedAtUs.value
          : this.recordedAtUs,
      sleepiness: data.sleepiness.present
          ? data.sleepiness.value
          : this.sleepiness,
      stress: data.stress.present ? data.stress.value : this.stress,
      mood: data.mood.present ? data.mood.value : this.mood,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SelfCheckin(')
          ..write('id: $id, ')
          ..write('recordedAtUs: $recordedAtUs, ')
          ..write('sleepiness: $sleepiness, ')
          ..write('stress: $stress, ')
          ..write('mood: $mood')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    $driftBlobEquality.hash(id),
    recordedAtUs,
    sleepiness,
    stress,
    mood,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SelfCheckin &&
          $driftBlobEquality.equals(other.id, this.id) &&
          other.recordedAtUs == this.recordedAtUs &&
          other.sleepiness == this.sleepiness &&
          other.stress == this.stress &&
          other.mood == this.mood);
}

class SelfCheckinsCompanion extends UpdateCompanion<SelfCheckin> {
  final Value<Uint8List> id;
  final Value<int> recordedAtUs;
  final Value<int> sleepiness;
  final Value<int> stress;
  final Value<int> mood;
  final Value<int> rowid;
  const SelfCheckinsCompanion({
    this.id = const Value.absent(),
    this.recordedAtUs = const Value.absent(),
    this.sleepiness = const Value.absent(),
    this.stress = const Value.absent(),
    this.mood = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SelfCheckinsCompanion.insert({
    required Uint8List id,
    required int recordedAtUs,
    required int sleepiness,
    required int stress,
    required int mood,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recordedAtUs = Value(recordedAtUs),
       sleepiness = Value(sleepiness),
       stress = Value(stress),
       mood = Value(mood);
  static Insertable<SelfCheckin> custom({
    Expression<Uint8List>? id,
    Expression<int>? recordedAtUs,
    Expression<int>? sleepiness,
    Expression<int>? stress,
    Expression<int>? mood,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordedAtUs != null) 'recorded_at_us': recordedAtUs,
      if (sleepiness != null) 'sleepiness': sleepiness,
      if (stress != null) 'stress': stress,
      if (mood != null) 'mood': mood,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SelfCheckinsCompanion copyWith({
    Value<Uint8List>? id,
    Value<int>? recordedAtUs,
    Value<int>? sleepiness,
    Value<int>? stress,
    Value<int>? mood,
    Value<int>? rowid,
  }) {
    return SelfCheckinsCompanion(
      id: id ?? this.id,
      recordedAtUs: recordedAtUs ?? this.recordedAtUs,
      sleepiness: sleepiness ?? this.sleepiness,
      stress: stress ?? this.stress,
      mood: mood ?? this.mood,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<Uint8List>(id.value);
    }
    if (recordedAtUs.present) {
      map['recorded_at_us'] = Variable<int>(recordedAtUs.value);
    }
    if (sleepiness.present) {
      map['sleepiness'] = Variable<int>(sleepiness.value);
    }
    if (stress.present) {
      map['stress'] = Variable<int>(stress.value);
    }
    if (mood.present) {
      map['mood'] = Variable<int>(mood.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SelfCheckinsCompanion(')
          ..write('id: $id, ')
          ..write('recordedAtUs: $recordedAtUs, ')
          ..write('sleepiness: $sleepiness, ')
          ..write('stress: $stress, ')
          ..write('mood: $mood, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ReactionTests extends Table with TableInfo<ReactionTests, ReactionTest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ReactionTests(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<Uint8List> id = GeneratedColumn<Uint8List>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY CHECK (length(id) = 16)',
  );
  static const VerificationMeta _recordedAtUsMeta = const VerificationMeta(
    'recordedAtUs',
  );
  late final GeneratedColumn<int> recordedAtUs = GeneratedColumn<int>(
    'recorded_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (duration_ms > 0)',
  );
  static const VerificationMeta _stimuliMeta = const VerificationMeta(
    'stimuli',
  );
  late final GeneratedColumn<int> stimuli = GeneratedColumn<int>(
    'stimuli',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (stimuli >= 0)',
  );
  static const VerificationMeta _responsesMeta = const VerificationMeta(
    'responses',
  );
  late final GeneratedColumn<int> responses = GeneratedColumn<int>(
    'responses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (responses BETWEEN 0 AND stimuli)',
  );
  static const VerificationMeta _medianRtMsMeta = const VerificationMeta(
    'medianRtMs',
  );
  late final GeneratedColumn<double> medianRtMs = GeneratedColumn<double>(
    'median_rt_ms',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (median_rt_ms IS NULL OR median_rt_ms > 0)',
  );
  static const VerificationMeta _meanSpeedMeta = const VerificationMeta(
    'meanSpeed',
  );
  late final GeneratedColumn<double> meanSpeed = GeneratedColumn<double>(
    'mean_speed',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (mean_speed IS NULL OR mean_speed > 0)',
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (lapses >= 0)',
  );
  static const VerificationMeta _falseStartsMeta = const VerificationMeta(
    'falseStarts',
  );
  late final GeneratedColumn<int> falseStarts = GeneratedColumn<int>(
    'false_starts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (false_starts >= 0)',
  );
  static const VerificationMeta _deviceMeta = const VerificationMeta('device');
  late final GeneratedColumn<String> device = GeneratedColumn<String>(
    'device',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(device) BETWEEN 1 AND 60)',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordedAtUs,
    durationMs,
    stimuli,
    responses,
    medianRtMs,
    meanSpeed,
    lapses,
    falseStarts,
    device,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reaction_tests';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReactionTest> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('recorded_at_us')) {
      context.handle(
        _recordedAtUsMeta,
        recordedAtUs.isAcceptableOrUnknown(
          data['recorded_at_us']!,
          _recordedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordedAtUsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('stimuli')) {
      context.handle(
        _stimuliMeta,
        stimuli.isAcceptableOrUnknown(data['stimuli']!, _stimuliMeta),
      );
    } else if (isInserting) {
      context.missing(_stimuliMeta);
    }
    if (data.containsKey('responses')) {
      context.handle(
        _responsesMeta,
        responses.isAcceptableOrUnknown(data['responses']!, _responsesMeta),
      );
    } else if (isInserting) {
      context.missing(_responsesMeta);
    }
    if (data.containsKey('median_rt_ms')) {
      context.handle(
        _medianRtMsMeta,
        medianRtMs.isAcceptableOrUnknown(
          data['median_rt_ms']!,
          _medianRtMsMeta,
        ),
      );
    }
    if (data.containsKey('mean_speed')) {
      context.handle(
        _meanSpeedMeta,
        meanSpeed.isAcceptableOrUnknown(data['mean_speed']!, _meanSpeedMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    } else if (isInserting) {
      context.missing(_lapsesMeta);
    }
    if (data.containsKey('false_starts')) {
      context.handle(
        _falseStartsMeta,
        falseStarts.isAcceptableOrUnknown(
          data['false_starts']!,
          _falseStartsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_falseStartsMeta);
    }
    if (data.containsKey('device')) {
      context.handle(
        _deviceMeta,
        device.isAcceptableOrUnknown(data['device']!, _deviceMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReactionTest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReactionTest(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}id'],
      )!,
      recordedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recorded_at_us'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      stimuli: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stimuli'],
      )!,
      responses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}responses'],
      )!,
      medianRtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}median_rt_ms'],
      ),
      meanSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mean_speed'],
      ),
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
      falseStarts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}false_starts'],
      )!,
      device: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device'],
      )!,
    );
  }

  @override
  ReactionTests createAlias(String alias) {
    return ReactionTests(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => const [
    'CHECK((responses = 0)=(median_rt_ms IS NULL))',
    'CHECK((responses = 0)=(mean_speed IS NULL))',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class ReactionTest extends DataClass implements Insertable<ReactionTest> {
  final Uint8List id;
  final int recordedAtUs;
  final int durationMs;

  /// Stimuli shown and valid responses (100 ms or slower).
  final int stimuli;
  final int responses;
  final double? medianRtMs;

  /// Mean response speed, 1/RT in 1/s (the PVT's most sensitive outcome).
  final double? meanSpeed;

  /// Lapses: responses of 355 ms or more, or no response within 30 s.
  final int lapses;

  /// False starts: responses before a stimulus or faster than 100 ms.
  final int falseStarts;

  /// The device the test ran on (platform and form factor), for comparison.
  final String device;
  const ReactionTest({
    required this.id,
    required this.recordedAtUs,
    required this.durationMs,
    required this.stimuli,
    required this.responses,
    this.medianRtMs,
    this.meanSpeed,
    required this.lapses,
    required this.falseStarts,
    required this.device,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<Uint8List>(id);
    map['recorded_at_us'] = Variable<int>(recordedAtUs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['stimuli'] = Variable<int>(stimuli);
    map['responses'] = Variable<int>(responses);
    if (!nullToAbsent || medianRtMs != null) {
      map['median_rt_ms'] = Variable<double>(medianRtMs);
    }
    if (!nullToAbsent || meanSpeed != null) {
      map['mean_speed'] = Variable<double>(meanSpeed);
    }
    map['lapses'] = Variable<int>(lapses);
    map['false_starts'] = Variable<int>(falseStarts);
    map['device'] = Variable<String>(device);
    return map;
  }

  ReactionTestsCompanion toCompanion(bool nullToAbsent) {
    return ReactionTestsCompanion(
      id: Value(id),
      recordedAtUs: Value(recordedAtUs),
      durationMs: Value(durationMs),
      stimuli: Value(stimuli),
      responses: Value(responses),
      medianRtMs: medianRtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(medianRtMs),
      meanSpeed: meanSpeed == null && nullToAbsent
          ? const Value.absent()
          : Value(meanSpeed),
      lapses: Value(lapses),
      falseStarts: Value(falseStarts),
      device: Value(device),
    );
  }

  factory ReactionTest.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReactionTest(
      id: serializer.fromJson<Uint8List>(json['id']),
      recordedAtUs: serializer.fromJson<int>(json['recorded_at_us']),
      durationMs: serializer.fromJson<int>(json['duration_ms']),
      stimuli: serializer.fromJson<int>(json['stimuli']),
      responses: serializer.fromJson<int>(json['responses']),
      medianRtMs: serializer.fromJson<double?>(json['median_rt_ms']),
      meanSpeed: serializer.fromJson<double?>(json['mean_speed']),
      lapses: serializer.fromJson<int>(json['lapses']),
      falseStarts: serializer.fromJson<int>(json['false_starts']),
      device: serializer.fromJson<String>(json['device']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<Uint8List>(id),
      'recorded_at_us': serializer.toJson<int>(recordedAtUs),
      'duration_ms': serializer.toJson<int>(durationMs),
      'stimuli': serializer.toJson<int>(stimuli),
      'responses': serializer.toJson<int>(responses),
      'median_rt_ms': serializer.toJson<double?>(medianRtMs),
      'mean_speed': serializer.toJson<double?>(meanSpeed),
      'lapses': serializer.toJson<int>(lapses),
      'false_starts': serializer.toJson<int>(falseStarts),
      'device': serializer.toJson<String>(device),
    };
  }

  ReactionTest copyWith({
    Uint8List? id,
    int? recordedAtUs,
    int? durationMs,
    int? stimuli,
    int? responses,
    Value<double?> medianRtMs = const Value.absent(),
    Value<double?> meanSpeed = const Value.absent(),
    int? lapses,
    int? falseStarts,
    String? device,
  }) => ReactionTest(
    id: id ?? this.id,
    recordedAtUs: recordedAtUs ?? this.recordedAtUs,
    durationMs: durationMs ?? this.durationMs,
    stimuli: stimuli ?? this.stimuli,
    responses: responses ?? this.responses,
    medianRtMs: medianRtMs.present ? medianRtMs.value : this.medianRtMs,
    meanSpeed: meanSpeed.present ? meanSpeed.value : this.meanSpeed,
    lapses: lapses ?? this.lapses,
    falseStarts: falseStarts ?? this.falseStarts,
    device: device ?? this.device,
  );
  ReactionTest copyWithCompanion(ReactionTestsCompanion data) {
    return ReactionTest(
      id: data.id.present ? data.id.value : this.id,
      recordedAtUs: data.recordedAtUs.present
          ? data.recordedAtUs.value
          : this.recordedAtUs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      stimuli: data.stimuli.present ? data.stimuli.value : this.stimuli,
      responses: data.responses.present ? data.responses.value : this.responses,
      medianRtMs: data.medianRtMs.present
          ? data.medianRtMs.value
          : this.medianRtMs,
      meanSpeed: data.meanSpeed.present ? data.meanSpeed.value : this.meanSpeed,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      falseStarts: data.falseStarts.present
          ? data.falseStarts.value
          : this.falseStarts,
      device: data.device.present ? data.device.value : this.device,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReactionTest(')
          ..write('id: $id, ')
          ..write('recordedAtUs: $recordedAtUs, ')
          ..write('durationMs: $durationMs, ')
          ..write('stimuli: $stimuli, ')
          ..write('responses: $responses, ')
          ..write('medianRtMs: $medianRtMs, ')
          ..write('meanSpeed: $meanSpeed, ')
          ..write('lapses: $lapses, ')
          ..write('falseStarts: $falseStarts, ')
          ..write('device: $device')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    $driftBlobEquality.hash(id),
    recordedAtUs,
    durationMs,
    stimuli,
    responses,
    medianRtMs,
    meanSpeed,
    lapses,
    falseStarts,
    device,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReactionTest &&
          $driftBlobEquality.equals(other.id, this.id) &&
          other.recordedAtUs == this.recordedAtUs &&
          other.durationMs == this.durationMs &&
          other.stimuli == this.stimuli &&
          other.responses == this.responses &&
          other.medianRtMs == this.medianRtMs &&
          other.meanSpeed == this.meanSpeed &&
          other.lapses == this.lapses &&
          other.falseStarts == this.falseStarts &&
          other.device == this.device);
}

class ReactionTestsCompanion extends UpdateCompanion<ReactionTest> {
  final Value<Uint8List> id;
  final Value<int> recordedAtUs;
  final Value<int> durationMs;
  final Value<int> stimuli;
  final Value<int> responses;
  final Value<double?> medianRtMs;
  final Value<double?> meanSpeed;
  final Value<int> lapses;
  final Value<int> falseStarts;
  final Value<String> device;
  final Value<int> rowid;
  const ReactionTestsCompanion({
    this.id = const Value.absent(),
    this.recordedAtUs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.stimuli = const Value.absent(),
    this.responses = const Value.absent(),
    this.medianRtMs = const Value.absent(),
    this.meanSpeed = const Value.absent(),
    this.lapses = const Value.absent(),
    this.falseStarts = const Value.absent(),
    this.device = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReactionTestsCompanion.insert({
    required Uint8List id,
    required int recordedAtUs,
    required int durationMs,
    required int stimuli,
    required int responses,
    this.medianRtMs = const Value.absent(),
    this.meanSpeed = const Value.absent(),
    required int lapses,
    required int falseStarts,
    required String device,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recordedAtUs = Value(recordedAtUs),
       durationMs = Value(durationMs),
       stimuli = Value(stimuli),
       responses = Value(responses),
       lapses = Value(lapses),
       falseStarts = Value(falseStarts),
       device = Value(device);
  static Insertable<ReactionTest> custom({
    Expression<Uint8List>? id,
    Expression<int>? recordedAtUs,
    Expression<int>? durationMs,
    Expression<int>? stimuli,
    Expression<int>? responses,
    Expression<double>? medianRtMs,
    Expression<double>? meanSpeed,
    Expression<int>? lapses,
    Expression<int>? falseStarts,
    Expression<String>? device,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordedAtUs != null) 'recorded_at_us': recordedAtUs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (stimuli != null) 'stimuli': stimuli,
      if (responses != null) 'responses': responses,
      if (medianRtMs != null) 'median_rt_ms': medianRtMs,
      if (meanSpeed != null) 'mean_speed': meanSpeed,
      if (lapses != null) 'lapses': lapses,
      if (falseStarts != null) 'false_starts': falseStarts,
      if (device != null) 'device': device,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReactionTestsCompanion copyWith({
    Value<Uint8List>? id,
    Value<int>? recordedAtUs,
    Value<int>? durationMs,
    Value<int>? stimuli,
    Value<int>? responses,
    Value<double?>? medianRtMs,
    Value<double?>? meanSpeed,
    Value<int>? lapses,
    Value<int>? falseStarts,
    Value<String>? device,
    Value<int>? rowid,
  }) {
    return ReactionTestsCompanion(
      id: id ?? this.id,
      recordedAtUs: recordedAtUs ?? this.recordedAtUs,
      durationMs: durationMs ?? this.durationMs,
      stimuli: stimuli ?? this.stimuli,
      responses: responses ?? this.responses,
      medianRtMs: medianRtMs ?? this.medianRtMs,
      meanSpeed: meanSpeed ?? this.meanSpeed,
      lapses: lapses ?? this.lapses,
      falseStarts: falseStarts ?? this.falseStarts,
      device: device ?? this.device,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<Uint8List>(id.value);
    }
    if (recordedAtUs.present) {
      map['recorded_at_us'] = Variable<int>(recordedAtUs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (stimuli.present) {
      map['stimuli'] = Variable<int>(stimuli.value);
    }
    if (responses.present) {
      map['responses'] = Variable<int>(responses.value);
    }
    if (medianRtMs.present) {
      map['median_rt_ms'] = Variable<double>(medianRtMs.value);
    }
    if (meanSpeed.present) {
      map['mean_speed'] = Variable<double>(meanSpeed.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (falseStarts.present) {
      map['false_starts'] = Variable<int>(falseStarts.value);
    }
    if (device.present) {
      map['device'] = Variable<String>(device.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReactionTestsCompanion(')
          ..write('id: $id, ')
          ..write('recordedAtUs: $recordedAtUs, ')
          ..write('durationMs: $durationMs, ')
          ..write('stimuli: $stimuli, ')
          ..write('responses: $responses, ')
          ..write('medianRtMs: $medianRtMs, ')
          ..write('meanSpeed: $meanSpeed, ')
          ..write('lapses: $lapses, ')
          ..write('falseStarts: $falseStarts, ')
          ..write('device: $device, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AlertResponses extends Table
    with TableInfo<AlertResponses, AlertResponse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AlertResponses(this.attachedDatabase, [this._alias]);
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
    $customConstraints: 'NOT NULL REFERENCES missions(id)',
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
  static const VerificationMeta _alertLevelMeta = const VerificationMeta(
    'alertLevel',
  );
  late final GeneratedColumn<int> alertLevel = GeneratedColumn<int>(
    'alert_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (alert_level IN (1, 3, 4))',
  );
  static const VerificationMeta _alertDayUsMeta = const VerificationMeta(
    'alertDayUs',
  );
  late final GeneratedColumn<int> alertDayUs = GeneratedColumn<int>(
    'alert_day_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _responseMeta = const VerificationMeta(
    'response',
  );
  late final GeneratedColumn<int> response = GeneratedColumn<int>(
    'response',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (response BETWEEN 1 AND 5)',
  );
  static const VerificationMeta _outcomeLevelMeta = const VerificationMeta(
    'outcomeLevel',
  );
  late final GeneratedColumn<int> outcomeLevel = GeneratedColumn<int>(
    'outcome_level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints:
        'CHECK (outcome_level IS NULL OR outcome_level BETWEEN 0 AND 4)',
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'CHECK (note IS NULL OR length(note) BETWEEN 1 AND 500)',
  );
  static const VerificationMeta _recordedAtUsMeta = const VerificationMeta(
    'recordedAtUs',
  );
  late final GeneratedColumn<int> recordedAtUs = GeneratedColumn<int>(
    'recorded_at_us',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    missionId,
    metricCode,
    alertLevel,
    alertDayUs,
    response,
    outcomeLevel,
    note,
    recordedAtUs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alert_responses';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlertResponse> instance, {
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
    if (data.containsKey('metric_code')) {
      context.handle(
        _metricCodeMeta,
        metricCode.isAcceptableOrUnknown(data['metric_code']!, _metricCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_metricCodeMeta);
    }
    if (data.containsKey('alert_level')) {
      context.handle(
        _alertLevelMeta,
        alertLevel.isAcceptableOrUnknown(data['alert_level']!, _alertLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_alertLevelMeta);
    }
    if (data.containsKey('alert_day_us')) {
      context.handle(
        _alertDayUsMeta,
        alertDayUs.isAcceptableOrUnknown(
          data['alert_day_us']!,
          _alertDayUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_alertDayUsMeta);
    }
    if (data.containsKey('response')) {
      context.handle(
        _responseMeta,
        response.isAcceptableOrUnknown(data['response']!, _responseMeta),
      );
    } else if (isInserting) {
      context.missing(_responseMeta);
    }
    if (data.containsKey('outcome_level')) {
      context.handle(
        _outcomeLevelMeta,
        outcomeLevel.isAcceptableOrUnknown(
          data['outcome_level']!,
          _outcomeLevelMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('recorded_at_us')) {
      context.handle(
        _recordedAtUsMeta,
        recordedAtUs.isAcceptableOrUnknown(
          data['recorded_at_us']!,
          _recordedAtUsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordedAtUsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlertResponse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlertResponse(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}id'],
      )!,
      missionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mission_id'],
      )!,
      metricCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metric_code'],
      )!,
      alertLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}alert_level'],
      )!,
      alertDayUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}alert_day_us'],
      )!,
      response: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}response'],
      )!,
      outcomeLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}outcome_level'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      recordedAtUs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recorded_at_us'],
      )!,
    );
  }

  @override
  AlertResponses createAlias(String alias) {
    return AlertResponses(attachedDatabase, alias);
  }

  @override
  bool get isStrict => true;
  @override
  bool get dontWriteConstraints => true;
}

class AlertResponse extends DataClass implements Insertable<AlertResponse> {
  final Uint8List id;
  final String missionId;
  final String metricCode;

  /// Levels are rakia_level codes (core/include/rakia/rakia.h): 0 not
  /// enough data, 1 data quality, 2 within baseline, 3 watch, 4 act.
  /// The alert answered: data quality, watch or act.
  final int alertLevel;

  /// The day the alert concerns (onset of a shift, or the flagged reading),
  /// as microseconds since the Unix epoch at 00:00 UTC of that date.
  final int alertDayUs;

  /// 1 confirmatory reading, 2 value checked and correct, 3 value
  /// corrected, 4 keep watching, 5 contacted medical support.
  final int response;

  /// For a confirmatory reading or correction: the indicator's level once
  /// the new value was evaluated.
  final int? outcomeLevel;
  final String? note;
  final int recordedAtUs;
  const AlertResponse({
    required this.id,
    required this.missionId,
    required this.metricCode,
    required this.alertLevel,
    required this.alertDayUs,
    required this.response,
    this.outcomeLevel,
    this.note,
    required this.recordedAtUs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<Uint8List>(id);
    map['mission_id'] = Variable<String>(missionId);
    map['metric_code'] = Variable<String>(metricCode);
    map['alert_level'] = Variable<int>(alertLevel);
    map['alert_day_us'] = Variable<int>(alertDayUs);
    map['response'] = Variable<int>(response);
    if (!nullToAbsent || outcomeLevel != null) {
      map['outcome_level'] = Variable<int>(outcomeLevel);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['recorded_at_us'] = Variable<int>(recordedAtUs);
    return map;
  }

  AlertResponsesCompanion toCompanion(bool nullToAbsent) {
    return AlertResponsesCompanion(
      id: Value(id),
      missionId: Value(missionId),
      metricCode: Value(metricCode),
      alertLevel: Value(alertLevel),
      alertDayUs: Value(alertDayUs),
      response: Value(response),
      outcomeLevel: outcomeLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(outcomeLevel),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      recordedAtUs: Value(recordedAtUs),
    );
  }

  factory AlertResponse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlertResponse(
      id: serializer.fromJson<Uint8List>(json['id']),
      missionId: serializer.fromJson<String>(json['mission_id']),
      metricCode: serializer.fromJson<String>(json['metric_code']),
      alertLevel: serializer.fromJson<int>(json['alert_level']),
      alertDayUs: serializer.fromJson<int>(json['alert_day_us']),
      response: serializer.fromJson<int>(json['response']),
      outcomeLevel: serializer.fromJson<int?>(json['outcome_level']),
      note: serializer.fromJson<String?>(json['note']),
      recordedAtUs: serializer.fromJson<int>(json['recorded_at_us']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<Uint8List>(id),
      'mission_id': serializer.toJson<String>(missionId),
      'metric_code': serializer.toJson<String>(metricCode),
      'alert_level': serializer.toJson<int>(alertLevel),
      'alert_day_us': serializer.toJson<int>(alertDayUs),
      'response': serializer.toJson<int>(response),
      'outcome_level': serializer.toJson<int?>(outcomeLevel),
      'note': serializer.toJson<String?>(note),
      'recorded_at_us': serializer.toJson<int>(recordedAtUs),
    };
  }

  AlertResponse copyWith({
    Uint8List? id,
    String? missionId,
    String? metricCode,
    int? alertLevel,
    int? alertDayUs,
    int? response,
    Value<int?> outcomeLevel = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? recordedAtUs,
  }) => AlertResponse(
    id: id ?? this.id,
    missionId: missionId ?? this.missionId,
    metricCode: metricCode ?? this.metricCode,
    alertLevel: alertLevel ?? this.alertLevel,
    alertDayUs: alertDayUs ?? this.alertDayUs,
    response: response ?? this.response,
    outcomeLevel: outcomeLevel.present ? outcomeLevel.value : this.outcomeLevel,
    note: note.present ? note.value : this.note,
    recordedAtUs: recordedAtUs ?? this.recordedAtUs,
  );
  AlertResponse copyWithCompanion(AlertResponsesCompanion data) {
    return AlertResponse(
      id: data.id.present ? data.id.value : this.id,
      missionId: data.missionId.present ? data.missionId.value : this.missionId,
      metricCode: data.metricCode.present
          ? data.metricCode.value
          : this.metricCode,
      alertLevel: data.alertLevel.present
          ? data.alertLevel.value
          : this.alertLevel,
      alertDayUs: data.alertDayUs.present
          ? data.alertDayUs.value
          : this.alertDayUs,
      response: data.response.present ? data.response.value : this.response,
      outcomeLevel: data.outcomeLevel.present
          ? data.outcomeLevel.value
          : this.outcomeLevel,
      note: data.note.present ? data.note.value : this.note,
      recordedAtUs: data.recordedAtUs.present
          ? data.recordedAtUs.value
          : this.recordedAtUs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlertResponse(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('metricCode: $metricCode, ')
          ..write('alertLevel: $alertLevel, ')
          ..write('alertDayUs: $alertDayUs, ')
          ..write('response: $response, ')
          ..write('outcomeLevel: $outcomeLevel, ')
          ..write('note: $note, ')
          ..write('recordedAtUs: $recordedAtUs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    $driftBlobEquality.hash(id),
    missionId,
    metricCode,
    alertLevel,
    alertDayUs,
    response,
    outcomeLevel,
    note,
    recordedAtUs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlertResponse &&
          $driftBlobEquality.equals(other.id, this.id) &&
          other.missionId == this.missionId &&
          other.metricCode == this.metricCode &&
          other.alertLevel == this.alertLevel &&
          other.alertDayUs == this.alertDayUs &&
          other.response == this.response &&
          other.outcomeLevel == this.outcomeLevel &&
          other.note == this.note &&
          other.recordedAtUs == this.recordedAtUs);
}

class AlertResponsesCompanion extends UpdateCompanion<AlertResponse> {
  final Value<Uint8List> id;
  final Value<String> missionId;
  final Value<String> metricCode;
  final Value<int> alertLevel;
  final Value<int> alertDayUs;
  final Value<int> response;
  final Value<int?> outcomeLevel;
  final Value<String?> note;
  final Value<int> recordedAtUs;
  final Value<int> rowid;
  const AlertResponsesCompanion({
    this.id = const Value.absent(),
    this.missionId = const Value.absent(),
    this.metricCode = const Value.absent(),
    this.alertLevel = const Value.absent(),
    this.alertDayUs = const Value.absent(),
    this.response = const Value.absent(),
    this.outcomeLevel = const Value.absent(),
    this.note = const Value.absent(),
    this.recordedAtUs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlertResponsesCompanion.insert({
    required Uint8List id,
    required String missionId,
    required String metricCode,
    required int alertLevel,
    required int alertDayUs,
    required int response,
    this.outcomeLevel = const Value.absent(),
    this.note = const Value.absent(),
    required int recordedAtUs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       missionId = Value(missionId),
       metricCode = Value(metricCode),
       alertLevel = Value(alertLevel),
       alertDayUs = Value(alertDayUs),
       response = Value(response),
       recordedAtUs = Value(recordedAtUs);
  static Insertable<AlertResponse> custom({
    Expression<Uint8List>? id,
    Expression<String>? missionId,
    Expression<String>? metricCode,
    Expression<int>? alertLevel,
    Expression<int>? alertDayUs,
    Expression<int>? response,
    Expression<int>? outcomeLevel,
    Expression<String>? note,
    Expression<int>? recordedAtUs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (missionId != null) 'mission_id': missionId,
      if (metricCode != null) 'metric_code': metricCode,
      if (alertLevel != null) 'alert_level': alertLevel,
      if (alertDayUs != null) 'alert_day_us': alertDayUs,
      if (response != null) 'response': response,
      if (outcomeLevel != null) 'outcome_level': outcomeLevel,
      if (note != null) 'note': note,
      if (recordedAtUs != null) 'recorded_at_us': recordedAtUs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlertResponsesCompanion copyWith({
    Value<Uint8List>? id,
    Value<String>? missionId,
    Value<String>? metricCode,
    Value<int>? alertLevel,
    Value<int>? alertDayUs,
    Value<int>? response,
    Value<int?>? outcomeLevel,
    Value<String?>? note,
    Value<int>? recordedAtUs,
    Value<int>? rowid,
  }) {
    return AlertResponsesCompanion(
      id: id ?? this.id,
      missionId: missionId ?? this.missionId,
      metricCode: metricCode ?? this.metricCode,
      alertLevel: alertLevel ?? this.alertLevel,
      alertDayUs: alertDayUs ?? this.alertDayUs,
      response: response ?? this.response,
      outcomeLevel: outcomeLevel ?? this.outcomeLevel,
      note: note ?? this.note,
      recordedAtUs: recordedAtUs ?? this.recordedAtUs,
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
    if (metricCode.present) {
      map['metric_code'] = Variable<String>(metricCode.value);
    }
    if (alertLevel.present) {
      map['alert_level'] = Variable<int>(alertLevel.value);
    }
    if (alertDayUs.present) {
      map['alert_day_us'] = Variable<int>(alertDayUs.value);
    }
    if (response.present) {
      map['response'] = Variable<int>(response.value);
    }
    if (outcomeLevel.present) {
      map['outcome_level'] = Variable<int>(outcomeLevel.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (recordedAtUs.present) {
      map['recorded_at_us'] = Variable<int>(recordedAtUs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlertResponsesCompanion(')
          ..write('id: $id, ')
          ..write('missionId: $missionId, ')
          ..write('metricCode: $metricCode, ')
          ..write('alertLevel: $alertLevel, ')
          ..write('alertDayUs: $alertDayUs, ')
          ..write('response: $response, ')
          ..write('outcomeLevel: $outcomeLevel, ')
          ..write('note: $note, ')
          ..write('recordedAtUs: $recordedAtUs, ')
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
  late final SelfCheckins selfCheckins = SelfCheckins(this);
  late final Index selfCheckinsByTime = Index(
    'self_checkins_by_time',
    'CREATE INDEX self_checkins_by_time ON self_checkins (recorded_at_us)',
  );
  late final Trigger selfCheckinsImmutable = Trigger(
    'CREATE TRIGGER self_checkins_immutable BEFORE UPDATE ON self_checkins BEGIN SELECT RAISE (ABORT, \'rakia: check-ins are not edited; record a new one\');END',
    'self_checkins_immutable',
  );
  late final ReactionTests reactionTests = ReactionTests(this);
  late final Index reactionTestsByTime = Index(
    'reaction_tests_by_time',
    'CREATE INDEX reaction_tests_by_time ON reaction_tests (recorded_at_us)',
  );
  late final Trigger reactionTestsImmutable = Trigger(
    'CREATE TRIGGER reaction_tests_immutable BEFORE UPDATE ON reaction_tests BEGIN SELECT RAISE (ABORT, \'rakia: test results are not edited\');END',
    'reaction_tests_immutable',
  );
  late final AlertResponses alertResponses = AlertResponses(this);
  late final Index alertResponsesByMetric = Index(
    'alert_responses_by_metric',
    'CREATE INDEX alert_responses_by_metric ON alert_responses (mission_id, metric_code, recorded_at_us)',
  );
  late final Trigger alertResponsesRealOnly = Trigger(
    'CREATE TRIGGER alert_responses_real_only BEFORE INSERT ON alert_responses WHEN (SELECT is_simulation FROM missions WHERE id = NEW.mission_id) IS NOT 0 BEGIN SELECT RAISE (ABORT, \'rakia: responses belong to a real record\');END',
    'alert_responses_real_only',
  );
  late final Trigger alertResponsesImmutable = Trigger(
    'CREATE TRIGGER alert_responses_immutable BEFORE UPDATE ON alert_responses BEGIN SELECT RAISE (ABORT, \'rakia: responses are not edited\');END',
    'alert_responses_immutable',
  );
  late final Trigger alertResponsesKept = Trigger(
    'CREATE TRIGGER alert_responses_kept BEFORE DELETE ON alert_responses BEGIN SELECT RAISE (ABORT, \'rakia: responses are kept\');END',
    'alert_responses_kept',
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
    selfCheckins,
    selfCheckinsByTime,
    selfCheckinsImmutable,
    reactionTests,
    reactionTestsByTime,
    reactionTestsImmutable,
    alertResponses,
    alertResponsesByMetric,
    alertResponsesRealOnly,
    alertResponsesImmutable,
    alertResponsesKept,
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
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'self_checkins',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'reaction_tests',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'alert_responses',
        limitUpdateKind: UpdateKind.insert,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'alert_responses',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'alert_responses',
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

  static MultiTypedResultKey<AlertResponses, List<AlertResponse>>
  _alertResponsesRefsTable(_$RakiaDatabase db) => MultiTypedResultKey.fromTable(
    db.alertResponses,
    aliasName: 'missions__id__alert_responses__mission_id',
  );

  $AlertResponsesProcessedTableManager get alertResponsesRefs {
    final manager = $AlertResponsesTableManager(
      $_db,
      $_db.alertResponses,
    ).filter((f) => f.missionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_alertResponsesRefsTable($_db));
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

  Expression<bool> alertResponsesRefs(
    Expression<bool> Function($AlertResponsesFilterComposer f) f,
  ) {
    final $AlertResponsesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alertResponses,
      getReferencedColumn: (t) => t.missionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AlertResponsesFilterComposer(
            $db: $db,
            $table: $db.alertResponses,
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

  Expression<T> alertResponsesRefs<T extends Object>(
    Expression<T> Function($AlertResponsesAnnotationComposer a) f,
  ) {
    final $AlertResponsesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alertResponses,
      getReferencedColumn: (t) => t.missionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AlertResponsesAnnotationComposer(
            $db: $db,
            $table: $db.alertResponses,
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
          PrefetchHooks Function({
            bool measurementsRefs,
            bool alertResponsesRefs,
          })
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
          prefetchHooksCallback:
              ({measurementsRefs = false, alertResponsesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (measurementsRefs) db.measurements,
                    if (alertResponsesRefs) db.alertResponses,
                  ],
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
                          managerFromTypedResult: (p0) => $MissionsReferences(
                            db,
                            table,
                            p0,
                          ).measurementsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'mission_id',
                          typedResults: items,
                        ),
                      if (alertResponsesRefs)
                        await $_getPrefetchedDataByColumns<
                          Mission,
                          Missions,
                          AlertResponse,
                          AlertResponses
                        >(
                          currentTable: table,
                          referencedTable: $MissionsReferences
                              ._alertResponsesRefsTable(db),
                          managerFromTypedResult: (p0) => $MissionsReferences(
                            db,
                            table,
                            p0,
                          ).alertResponsesRefs,
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
      PrefetchHooks Function({bool measurementsRefs, bool alertResponsesRefs})
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
typedef $SelfCheckinsCreateCompanionBuilder = SelfCheckinsCompanion Function({
  required Uint8List id,
  required int recordedAtUs,
  required int sleepiness,
  required int stress,
  required int mood,
  Value<int> rowid,
});
typedef $SelfCheckinsUpdateCompanionBuilder = SelfCheckinsCompanion Function({
  Value<Uint8List> id,
  Value<int> recordedAtUs,
  Value<int> sleepiness,
  Value<int> stress,
  Value<int> mood,
  Value<int> rowid,
});

class $SelfCheckinsFilterComposer
    extends Composer<_$RakiaDatabase, SelfCheckins> {
  $SelfCheckinsFilterComposer({
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

  ColumnFilters<int> get recordedAtUs => $composableBuilder(
    column: $table.recordedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sleepiness => $composableBuilder(
    column: $table.sleepiness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stress => $composableBuilder(
    column: $table.stress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );
}

class $SelfCheckinsOrderingComposer
    extends Composer<_$RakiaDatabase, SelfCheckins> {
  $SelfCheckinsOrderingComposer({
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

  ColumnOrderings<int> get recordedAtUs => $composableBuilder(
    column: $table.recordedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sleepiness => $composableBuilder(
    column: $table.sleepiness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stress => $composableBuilder(
    column: $table.stress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );
}

class $SelfCheckinsAnnotationComposer
    extends Composer<_$RakiaDatabase, SelfCheckins> {
  $SelfCheckinsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get recordedAtUs => $composableBuilder(
    column: $table.recordedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sleepiness => $composableBuilder(
    column: $table.sleepiness,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stress =>
      $composableBuilder(column: $table.stress, builder: (column) => column);

  GeneratedColumn<int> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);
}

class $SelfCheckinsTableManager
    extends
        RootTableManager<
          _$RakiaDatabase,
          SelfCheckins,
          SelfCheckin,
          $SelfCheckinsFilterComposer,
          $SelfCheckinsOrderingComposer,
          $SelfCheckinsAnnotationComposer,
          $SelfCheckinsCreateCompanionBuilder,
          $SelfCheckinsUpdateCompanionBuilder,
          (
            SelfCheckin,
            BaseReferences<_$RakiaDatabase, SelfCheckins, SelfCheckin>,
          ),
          SelfCheckin,
          PrefetchHooks Function()
        > {
  $SelfCheckinsTableManager(_$RakiaDatabase db, SelfCheckins table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SelfCheckinsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SelfCheckinsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SelfCheckinsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Uint8List> id = const Value.absent(),
                Value<int> recordedAtUs = const Value.absent(),
                Value<int> sleepiness = const Value.absent(),
                Value<int> stress = const Value.absent(),
                Value<int> mood = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SelfCheckinsCompanion(
                id: id,
                recordedAtUs: recordedAtUs,
                sleepiness: sleepiness,
                stress: stress,
                mood: mood,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required Uint8List id,
                required int recordedAtUs,
                required int sleepiness,
                required int stress,
                required int mood,
                Value<int> rowid = const Value.absent(),
              }) => SelfCheckinsCompanion.insert(
                id: id,
                recordedAtUs: recordedAtUs,
                sleepiness: sleepiness,
                stress: stress,
                mood: mood,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SelfCheckins, SelfCheckin>(table),
                  BaseReferences<_$RakiaDatabase, SelfCheckins, SelfCheckin>(
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

typedef $SelfCheckinsProcessedTableManager =
    ProcessedTableManager<
      _$RakiaDatabase,
      SelfCheckins,
      SelfCheckin,
      $SelfCheckinsFilterComposer,
      $SelfCheckinsOrderingComposer,
      $SelfCheckinsAnnotationComposer,
      $SelfCheckinsCreateCompanionBuilder,
      $SelfCheckinsUpdateCompanionBuilder,
      (SelfCheckin, BaseReferences<_$RakiaDatabase, SelfCheckins, SelfCheckin>),
      SelfCheckin,
      PrefetchHooks Function()
    >;
typedef $ReactionTestsCreateCompanionBuilder = ReactionTestsCompanion Function({
  required Uint8List id,
  required int recordedAtUs,
  required int durationMs,
  required int stimuli,
  required int responses,
  Value<double?> medianRtMs,
  Value<double?> meanSpeed,
  required int lapses,
  required int falseStarts,
  required String device,
  Value<int> rowid,
});
typedef $ReactionTestsUpdateCompanionBuilder = ReactionTestsCompanion Function({
  Value<Uint8List> id,
  Value<int> recordedAtUs,
  Value<int> durationMs,
  Value<int> stimuli,
  Value<int> responses,
  Value<double?> medianRtMs,
  Value<double?> meanSpeed,
  Value<int> lapses,
  Value<int> falseStarts,
  Value<String> device,
  Value<int> rowid,
});

class $ReactionTestsFilterComposer
    extends Composer<_$RakiaDatabase, ReactionTests> {
  $ReactionTestsFilterComposer({
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

  ColumnFilters<int> get recordedAtUs => $composableBuilder(
    column: $table.recordedAtUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stimuli => $composableBuilder(
    column: $table.stimuli,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get responses => $composableBuilder(
    column: $table.responses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get medianRtMs => $composableBuilder(
    column: $table.medianRtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get meanSpeed => $composableBuilder(
    column: $table.meanSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get falseStarts => $composableBuilder(
    column: $table.falseStarts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get device => $composableBuilder(
    column: $table.device,
    builder: (column) => ColumnFilters(column),
  );
}

class $ReactionTestsOrderingComposer
    extends Composer<_$RakiaDatabase, ReactionTests> {
  $ReactionTestsOrderingComposer({
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

  ColumnOrderings<int> get recordedAtUs => $composableBuilder(
    column: $table.recordedAtUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stimuli => $composableBuilder(
    column: $table.stimuli,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get responses => $composableBuilder(
    column: $table.responses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get medianRtMs => $composableBuilder(
    column: $table.medianRtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get meanSpeed => $composableBuilder(
    column: $table.meanSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapses => $composableBuilder(
    column: $table.lapses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get falseStarts => $composableBuilder(
    column: $table.falseStarts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get device => $composableBuilder(
    column: $table.device,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ReactionTestsAnnotationComposer
    extends Composer<_$RakiaDatabase, ReactionTests> {
  $ReactionTestsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get recordedAtUs => $composableBuilder(
    column: $table.recordedAtUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stimuli =>
      $composableBuilder(column: $table.stimuli, builder: (column) => column);

  GeneratedColumn<int> get responses =>
      $composableBuilder(column: $table.responses, builder: (column) => column);

  GeneratedColumn<double> get medianRtMs => $composableBuilder(
    column: $table.medianRtMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get meanSpeed =>
      $composableBuilder(column: $table.meanSpeed, builder: (column) => column);

  GeneratedColumn<int> get lapses =>
      $composableBuilder(column: $table.lapses, builder: (column) => column);

  GeneratedColumn<int> get falseStarts => $composableBuilder(
    column: $table.falseStarts,
    builder: (column) => column,
  );

  GeneratedColumn<String> get device =>
      $composableBuilder(column: $table.device, builder: (column) => column);
}

class $ReactionTestsTableManager
    extends
        RootTableManager<
          _$RakiaDatabase,
          ReactionTests,
          ReactionTest,
          $ReactionTestsFilterComposer,
          $ReactionTestsOrderingComposer,
          $ReactionTestsAnnotationComposer,
          $ReactionTestsCreateCompanionBuilder,
          $ReactionTestsUpdateCompanionBuilder,
          (
            ReactionTest,
            BaseReferences<_$RakiaDatabase, ReactionTests, ReactionTest>,
          ),
          ReactionTest,
          PrefetchHooks Function()
        > {
  $ReactionTestsTableManager(_$RakiaDatabase db, ReactionTests table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ReactionTestsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ReactionTestsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ReactionTestsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Uint8List> id = const Value.absent(),
                Value<int> recordedAtUs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> stimuli = const Value.absent(),
                Value<int> responses = const Value.absent(),
                Value<double?> medianRtMs = const Value.absent(),
                Value<double?> meanSpeed = const Value.absent(),
                Value<int> lapses = const Value.absent(),
                Value<int> falseStarts = const Value.absent(),
                Value<String> device = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReactionTestsCompanion(
                id: id,
                recordedAtUs: recordedAtUs,
                durationMs: durationMs,
                stimuli: stimuli,
                responses: responses,
                medianRtMs: medianRtMs,
                meanSpeed: meanSpeed,
                lapses: lapses,
                falseStarts: falseStarts,
                device: device,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required Uint8List id,
                required int recordedAtUs,
                required int durationMs,
                required int stimuli,
                required int responses,
                Value<double?> medianRtMs = const Value.absent(),
                Value<double?> meanSpeed = const Value.absent(),
                required int lapses,
                required int falseStarts,
                required String device,
                Value<int> rowid = const Value.absent(),
              }) => ReactionTestsCompanion.insert(
                id: id,
                recordedAtUs: recordedAtUs,
                durationMs: durationMs,
                stimuli: stimuli,
                responses: responses,
                medianRtMs: medianRtMs,
                meanSpeed: meanSpeed,
                lapses: lapses,
                falseStarts: falseStarts,
                device: device,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<ReactionTests, ReactionTest>(table),
                  BaseReferences<_$RakiaDatabase, ReactionTests, ReactionTest>(
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

typedef $ReactionTestsProcessedTableManager =
    ProcessedTableManager<
      _$RakiaDatabase,
      ReactionTests,
      ReactionTest,
      $ReactionTestsFilterComposer,
      $ReactionTestsOrderingComposer,
      $ReactionTestsAnnotationComposer,
      $ReactionTestsCreateCompanionBuilder,
      $ReactionTestsUpdateCompanionBuilder,
      (
        ReactionTest,
        BaseReferences<_$RakiaDatabase, ReactionTests, ReactionTest>,
      ),
      ReactionTest,
      PrefetchHooks Function()
    >;
typedef $AlertResponsesCreateCompanionBuilder =
    AlertResponsesCompanion Function({
      required Uint8List id,
      required String missionId,
      required String metricCode,
      required int alertLevel,
      required int alertDayUs,
      required int response,
      Value<int?> outcomeLevel,
      Value<String?> note,
      required int recordedAtUs,
      Value<int> rowid,
    });
typedef $AlertResponsesUpdateCompanionBuilder =
    AlertResponsesCompanion Function({
      Value<Uint8List> id,
      Value<String> missionId,
      Value<String> metricCode,
      Value<int> alertLevel,
      Value<int> alertDayUs,
      Value<int> response,
      Value<int?> outcomeLevel,
      Value<String?> note,
      Value<int> recordedAtUs,
      Value<int> rowid,
    });

final class $AlertResponsesReferences
    extends BaseReferences<_$RakiaDatabase, AlertResponses, AlertResponse> {
  $AlertResponsesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Missions _missionIdTable(_$RakiaDatabase db) =>
      db.missions.createAlias('alert_responses__mission_id__missions__id');

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
}

class $AlertResponsesFilterComposer
    extends Composer<_$RakiaDatabase, AlertResponses> {
  $AlertResponsesFilterComposer({
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

  ColumnFilters<String> get metricCode => $composableBuilder(
    column: $table.metricCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get alertLevel => $composableBuilder(
    column: $table.alertLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get alertDayUs => $composableBuilder(
    column: $table.alertDayUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get response => $composableBuilder(
    column: $table.response,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outcomeLevel => $composableBuilder(
    column: $table.outcomeLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordedAtUs => $composableBuilder(
    column: $table.recordedAtUs,
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
}

class $AlertResponsesOrderingComposer
    extends Composer<_$RakiaDatabase, AlertResponses> {
  $AlertResponsesOrderingComposer({
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

  ColumnOrderings<String> get metricCode => $composableBuilder(
    column: $table.metricCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get alertLevel => $composableBuilder(
    column: $table.alertLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get alertDayUs => $composableBuilder(
    column: $table.alertDayUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get response => $composableBuilder(
    column: $table.response,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outcomeLevel => $composableBuilder(
    column: $table.outcomeLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordedAtUs => $composableBuilder(
    column: $table.recordedAtUs,
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
}

class $AlertResponsesAnnotationComposer
    extends Composer<_$RakiaDatabase, AlertResponses> {
  $AlertResponsesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get metricCode => $composableBuilder(
    column: $table.metricCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get alertLevel => $composableBuilder(
    column: $table.alertLevel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get alertDayUs => $composableBuilder(
    column: $table.alertDayUs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get response =>
      $composableBuilder(column: $table.response, builder: (column) => column);

  GeneratedColumn<int> get outcomeLevel => $composableBuilder(
    column: $table.outcomeLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get recordedAtUs => $composableBuilder(
    column: $table.recordedAtUs,
    builder: (column) => column,
  );

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
}

class $AlertResponsesTableManager
    extends
        RootTableManager<
          _$RakiaDatabase,
          AlertResponses,
          AlertResponse,
          $AlertResponsesFilterComposer,
          $AlertResponsesOrderingComposer,
          $AlertResponsesAnnotationComposer,
          $AlertResponsesCreateCompanionBuilder,
          $AlertResponsesUpdateCompanionBuilder,
          (AlertResponse, $AlertResponsesReferences),
          AlertResponse,
          PrefetchHooks Function({bool missionId})
        > {
  $AlertResponsesTableManager(_$RakiaDatabase db, AlertResponses table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AlertResponsesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AlertResponsesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AlertResponsesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<Uint8List> id = const Value.absent(),
                Value<String> missionId = const Value.absent(),
                Value<String> metricCode = const Value.absent(),
                Value<int> alertLevel = const Value.absent(),
                Value<int> alertDayUs = const Value.absent(),
                Value<int> response = const Value.absent(),
                Value<int?> outcomeLevel = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> recordedAtUs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlertResponsesCompanion(
                id: id,
                missionId: missionId,
                metricCode: metricCode,
                alertLevel: alertLevel,
                alertDayUs: alertDayUs,
                response: response,
                outcomeLevel: outcomeLevel,
                note: note,
                recordedAtUs: recordedAtUs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required Uint8List id,
                required String missionId,
                required String metricCode,
                required int alertLevel,
                required int alertDayUs,
                required int response,
                Value<int?> outcomeLevel = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int recordedAtUs,
                Value<int> rowid = const Value.absent(),
              }) => AlertResponsesCompanion.insert(
                id: id,
                missionId: missionId,
                metricCode: metricCode,
                alertLevel: alertLevel,
                alertDayUs: alertDayUs,
                response: response,
                outcomeLevel: outcomeLevel,
                note: note,
                recordedAtUs: recordedAtUs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<AlertResponses, AlertResponse>(table),
                  $AlertResponsesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({missionId = false}) {
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
                        referencedTable: $AlertResponsesReferences
                            ._missionIdTable(db),
                        referencedColumn: $AlertResponsesReferences
                            ._missionIdTable(db)
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

typedef $AlertResponsesProcessedTableManager =
    ProcessedTableManager<
      _$RakiaDatabase,
      AlertResponses,
      AlertResponse,
      $AlertResponsesFilterComposer,
      $AlertResponsesOrderingComposer,
      $AlertResponsesAnnotationComposer,
      $AlertResponsesCreateCompanionBuilder,
      $AlertResponsesUpdateCompanionBuilder,
      (AlertResponse, $AlertResponsesReferences),
      AlertResponse,
      PrefetchHooks Function({bool missionId})
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
  $SelfCheckinsTableManager get selfCheckins =>
      $SelfCheckinsTableManager(_db, _db.selfCheckins);
  $ReactionTestsTableManager get reactionTests =>
      $ReactionTestsTableManager(_db, _db.reactionTests);
  $AlertResponsesTableManager get alertResponses =>
      $AlertResponsesTableManager(_db, _db.alertResponses);
}
