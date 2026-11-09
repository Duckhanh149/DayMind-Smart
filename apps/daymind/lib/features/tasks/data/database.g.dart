// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, CategoryRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, color];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRecord> instance, {
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
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class CategoryRecord extends DataClass implements Insertable<CategoryRecord> {
  final String id;
  final String name;
  final int color;
  const CategoryRecord({
    required this.id,
    required this.name,
    required this.color,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
    );
  }

  factory CategoryRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRecord(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
    };
  }

  CategoryRecord copyWith({String? id, String? name, int? color}) =>
      CategoryRecord(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
      );
  CategoryRecord copyWithCompanion(CategoriesCompanion data) {
    return CategoryRecord(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRecord(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRecord &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRecord> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> color;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    required int color,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       color = Value(color);
  static Insertable<CategoryRecord> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? color,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
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
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, TaskRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 240,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (priority BETWEEN 0 AND 2)',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (status BETWEEN 0 AND 3)',
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledStartAtMeta = const VerificationMeta(
    'scheduledStartAt',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledStartAt =
      GeneratedColumn<DateTime>(
        'scheduled_start_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _scheduledEndAtMeta = const VerificationMeta(
    'scheduledEndAt',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledEndAt =
      GeneratedColumn<DateTime>(
        'scheduled_end_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    priority,
    status,
    categoryId,
    dueAt,
    createdAt,
    updatedAt,
    completedAt,
    deletedAt,
    scheduledStartAt,
    scheduledEndAt,
    revision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('scheduled_start_at')) {
      context.handle(
        _scheduledStartAtMeta,
        scheduledStartAt.isAcceptableOrUnknown(
          data['scheduled_start_at']!,
          _scheduledStartAtMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_end_at')) {
      context.handle(
        _scheduledEndAtMeta,
        scheduledEndAt.isAcceptableOrUnknown(
          data['scheduled_end_at']!,
          _scheduledEndAtMeta,
        ),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      scheduledStartAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_start_at'],
      ),
      scheduledEndAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_end_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }
}

class TaskRecord extends DataClass implements Insertable<TaskRecord> {
  final String id;
  final String title;
  final String description;
  final int priority;
  final int status;
  final String? categoryId;
  final DateTime? dueAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? deletedAt;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;
  final int revision;
  const TaskRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    this.categoryId,
    this.dueAt,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.deletedAt,
    this.scheduledStartAt,
    this.scheduledEndAt,
    required this.revision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['priority'] = Variable<int>(priority);
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || dueAt != null) {
      map['due_at'] = Variable<DateTime>(dueAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || scheduledStartAt != null) {
      map['scheduled_start_at'] = Variable<DateTime>(scheduledStartAt);
    }
    if (!nullToAbsent || scheduledEndAt != null) {
      map['scheduled_end_at'] = Variable<DateTime>(scheduledEndAt);
    }
    map['revision'] = Variable<int>(revision);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      priority: Value(priority),
      status: Value(status),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      dueAt: dueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dueAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      scheduledStartAt: scheduledStartAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledStartAt),
      scheduledEndAt: scheduledEndAt == null && nullToAbsent
          ? const Value.absent()
          : Value(scheduledEndAt),
      revision: Value(revision),
    );
  }

  factory TaskRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRecord(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      priority: serializer.fromJson<int>(json['priority']),
      status: serializer.fromJson<int>(json['status']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      dueAt: serializer.fromJson<DateTime?>(json['dueAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      scheduledStartAt: serializer.fromJson<DateTime?>(
        json['scheduledStartAt'],
      ),
      scheduledEndAt: serializer.fromJson<DateTime?>(json['scheduledEndAt']),
      revision: serializer.fromJson<int>(json['revision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'priority': serializer.toJson<int>(priority),
      'status': serializer.toJson<int>(status),
      'categoryId': serializer.toJson<String?>(categoryId),
      'dueAt': serializer.toJson<DateTime?>(dueAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'scheduledStartAt': serializer.toJson<DateTime?>(scheduledStartAt),
      'scheduledEndAt': serializer.toJson<DateTime?>(scheduledEndAt),
      'revision': serializer.toJson<int>(revision),
    };
  }

  TaskRecord copyWith({
    String? id,
    String? title,
    String? description,
    int? priority,
    int? status,
    Value<String?> categoryId = const Value.absent(),
    Value<DateTime?> dueAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<DateTime?> scheduledStartAt = const Value.absent(),
    Value<DateTime?> scheduledEndAt = const Value.absent(),
    int? revision,
  }) => TaskRecord(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    dueAt: dueAt.present ? dueAt.value : this.dueAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    scheduledStartAt: scheduledStartAt.present
        ? scheduledStartAt.value
        : this.scheduledStartAt,
    scheduledEndAt: scheduledEndAt.present
        ? scheduledEndAt.value
        : this.scheduledEndAt,
    revision: revision ?? this.revision,
  );
  TaskRecord copyWithCompanion(TasksCompanion data) {
    return TaskRecord(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      priority: data.priority.present ? data.priority.value : this.priority,
      status: data.status.present ? data.status.value : this.status,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      scheduledStartAt: data.scheduledStartAt.present
          ? data.scheduledStartAt.value
          : this.scheduledStartAt,
      scheduledEndAt: data.scheduledEndAt.present
          ? data.scheduledEndAt.value
          : this.scheduledEndAt,
      revision: data.revision.present ? data.revision.value : this.revision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRecord(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('categoryId: $categoryId, ')
          ..write('dueAt: $dueAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('scheduledStartAt: $scheduledStartAt, ')
          ..write('scheduledEndAt: $scheduledEndAt, ')
          ..write('revision: $revision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    priority,
    status,
    categoryId,
    dueAt,
    createdAt,
    updatedAt,
    completedAt,
    deletedAt,
    scheduledStartAt,
    scheduledEndAt,
    revision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRecord &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.priority == this.priority &&
          other.status == this.status &&
          other.categoryId == this.categoryId &&
          other.dueAt == this.dueAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt &&
          other.deletedAt == this.deletedAt &&
          other.scheduledStartAt == this.scheduledStartAt &&
          other.scheduledEndAt == this.scheduledEndAt &&
          other.revision == this.revision);
}

class TasksCompanion extends UpdateCompanion<TaskRecord> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> description;
  final Value<int> priority;
  final Value<int> status;
  final Value<String?> categoryId;
  final Value<DateTime?> dueAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  final Value<DateTime?> deletedAt;
  final Value<DateTime?> scheduledStartAt;
  final Value<DateTime?> scheduledEndAt;
  final Value<int> revision;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.scheduledStartAt = const Value.absent(),
    this.scheduledEndAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    required int priority,
    required int status,
    this.categoryId = const Value.absent(),
    this.dueAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.completedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.scheduledStartAt = const Value.absent(),
    this.scheduledEndAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       priority = Value(priority),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskRecord> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? priority,
    Expression<int>? status,
    Expression<String>? categoryId,
    Expression<DateTime>? dueAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? scheduledStartAt,
    Expression<DateTime>? scheduledEndAt,
    Expression<int>? revision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (categoryId != null) 'category_id': categoryId,
      if (dueAt != null) 'due_at': dueAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (scheduledStartAt != null) 'scheduled_start_at': scheduledStartAt,
      if (scheduledEndAt != null) 'scheduled_end_at': scheduledEndAt,
      if (revision != null) 'revision': revision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? description,
    Value<int>? priority,
    Value<int>? status,
    Value<String?>? categoryId,
    Value<DateTime?>? dueAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? completedAt,
    Value<DateTime?>? deletedAt,
    Value<DateTime?>? scheduledStartAt,
    Value<DateTime?>? scheduledEndAt,
    Value<int>? revision,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      dueAt: dueAt ?? this.dueAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      scheduledStartAt: scheduledStartAt ?? this.scheduledStartAt,
      scheduledEndAt: scheduledEndAt ?? this.scheduledEndAt,
      revision: revision ?? this.revision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (scheduledStartAt.present) {
      map['scheduled_start_at'] = Variable<DateTime>(scheduledStartAt.value);
    }
    if (scheduledEndAt.present) {
      map['scheduled_end_at'] = Variable<DateTime>(scheduledEndAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('categoryId: $categoryId, ')
          ..write('dueAt: $dueAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('scheduledStartAt: $scheduledStartAt, ')
          ..write('scheduledEndAt: $scheduledEndAt, ')
          ..write('revision: $revision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PreferencesTable extends Preferences
    with TableInfo<$PreferencesTable, Preference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<Preference> instance, {
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
  Preference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Preference(
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
  $PreferencesTable createAlias(String alias) {
    return $PreferencesTable(attachedDatabase, alias);
  }
}

class Preference extends DataClass implements Insertable<Preference> {
  final String key;
  final String value;
  const Preference({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  PreferencesCompanion toCompanion(bool nullToAbsent) {
    return PreferencesCompanion(key: Value(key), value: Value(value));
  }

  factory Preference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Preference(
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

  Preference copyWith({String? key, String? value}) =>
      Preference(key: key ?? this.key, value: value ?? this.value);
  Preference copyWithCompanion(PreferencesCompanion data) {
    return Preference(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Preference(')
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
      (other is Preference &&
          other.key == this.key &&
          other.value == this.value);
}

class PreferencesCompanion extends UpdateCompanion<Preference> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const PreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreferencesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Preference> custom({
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

  PreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return PreferencesCompanion(
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
    return (StringBuffer('PreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExtensionRecordsTable extends ExtensionRecords
    with TableInfo<$ExtensionRecordsTable, ExtensionRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExtensionRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _areaMeta = const VerificationMeta('area');
  @override
  late final GeneratedColumn<String> area = GeneratedColumn<String>(
    'area',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedMsMeta = const VerificationMeta(
    'updatedMs',
  );
  @override
  late final GeneratedColumn<int> updatedMs = GeneratedColumn<int>(
    'updated_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [area, id, value, updatedMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'extension_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExtensionRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('area')) {
      context.handle(
        _areaMeta,
        area.isAcceptableOrUnknown(data['area']!, _areaMeta),
      );
    } else if (isInserting) {
      context.missing(_areaMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_ms')) {
      context.handle(
        _updatedMsMeta,
        updatedMs.isAcceptableOrUnknown(data['updated_ms']!, _updatedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {area, id};
  @override
  ExtensionRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExtensionRecord(
      area: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}area'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_ms'],
      )!,
    );
  }

  @override
  $ExtensionRecordsTable createAlias(String alias) {
    return $ExtensionRecordsTable(attachedDatabase, alias);
  }
}

class ExtensionRecord extends DataClass implements Insertable<ExtensionRecord> {
  final String area;
  final String id;
  final String value;
  final int updatedMs;
  const ExtensionRecord({
    required this.area,
    required this.id,
    required this.value,
    required this.updatedMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['area'] = Variable<String>(area);
    map['id'] = Variable<String>(id);
    map['value'] = Variable<String>(value);
    map['updated_ms'] = Variable<int>(updatedMs);
    return map;
  }

  ExtensionRecordsCompanion toCompanion(bool nullToAbsent) {
    return ExtensionRecordsCompanion(
      area: Value(area),
      id: Value(id),
      value: Value(value),
      updatedMs: Value(updatedMs),
    );
  }

  factory ExtensionRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExtensionRecord(
      area: serializer.fromJson<String>(json['area']),
      id: serializer.fromJson<String>(json['id']),
      value: serializer.fromJson<String>(json['value']),
      updatedMs: serializer.fromJson<int>(json['updatedMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'area': serializer.toJson<String>(area),
      'id': serializer.toJson<String>(id),
      'value': serializer.toJson<String>(value),
      'updatedMs': serializer.toJson<int>(updatedMs),
    };
  }

  ExtensionRecord copyWith({
    String? area,
    String? id,
    String? value,
    int? updatedMs,
  }) => ExtensionRecord(
    area: area ?? this.area,
    id: id ?? this.id,
    value: value ?? this.value,
    updatedMs: updatedMs ?? this.updatedMs,
  );
  ExtensionRecord copyWithCompanion(ExtensionRecordsCompanion data) {
    return ExtensionRecord(
      area: data.area.present ? data.area.value : this.area,
      id: data.id.present ? data.id.value : this.id,
      value: data.value.present ? data.value.value : this.value,
      updatedMs: data.updatedMs.present ? data.updatedMs.value : this.updatedMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExtensionRecord(')
          ..write('area: $area, ')
          ..write('id: $id, ')
          ..write('value: $value, ')
          ..write('updatedMs: $updatedMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(area, id, value, updatedMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExtensionRecord &&
          other.area == this.area &&
          other.id == this.id &&
          other.value == this.value &&
          other.updatedMs == this.updatedMs);
}

class ExtensionRecordsCompanion extends UpdateCompanion<ExtensionRecord> {
  final Value<String> area;
  final Value<String> id;
  final Value<String> value;
  final Value<int> updatedMs;
  final Value<int> rowid;
  const ExtensionRecordsCompanion({
    this.area = const Value.absent(),
    this.id = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExtensionRecordsCompanion.insert({
    required String area,
    required String id,
    required String value,
    required int updatedMs,
    this.rowid = const Value.absent(),
  }) : area = Value(area),
       id = Value(id),
       value = Value(value),
       updatedMs = Value(updatedMs);
  static Insertable<ExtensionRecord> custom({
    Expression<String>? area,
    Expression<String>? id,
    Expression<String>? value,
    Expression<int>? updatedMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (area != null) 'area': area,
      if (id != null) 'id': id,
      if (value != null) 'value': value,
      if (updatedMs != null) 'updated_ms': updatedMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExtensionRecordsCompanion copyWith({
    Value<String>? area,
    Value<String>? id,
    Value<String>? value,
    Value<int>? updatedMs,
    Value<int>? rowid,
  }) {
    return ExtensionRecordsCompanion(
      area: area ?? this.area,
      id: id ?? this.id,
      value: value ?? this.value,
      updatedMs: updatedMs ?? this.updatedMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (area.present) {
      map['area'] = Variable<String>(area.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedMs.present) {
      map['updated_ms'] = Variable<int>(updatedMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExtensionRecordsCompanion(')
          ..write('area: $area, ')
          ..write('id: $id, ')
          ..write('value: $value, ')
          ..write('updatedMs: $updatedMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReminderEventsTable extends ReminderEvents
    with TableInfo<$ReminderEventsTable, ReminderEventRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReminderEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventKeyMeta = const VerificationMeta(
    'eventKey',
  );
  @override
  late final GeneratedColumn<String> eventKey = GeneratedColumn<String>(
    'event_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ruleIdMeta = const VerificationMeta('ruleId');
  @override
  late final GeneratedColumn<String> ruleId = GeneratedColumn<String>(
    'rule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurrenceIdMeta = const VerificationMeta(
    'occurrenceId',
  );
  @override
  late final GeneratedColumn<String> occurrenceId = GeneratedColumn<String>(
    'occurrence_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurrenceRevisionMeta =
      const VerificationMeta('occurrenceRevision');
  @override
  late final GeneratedColumn<int> occurrenceRevision = GeneratedColumn<int>(
    'occurrence_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taskRevisionMeta = const VerificationMeta(
    'taskRevision',
  );
  @override
  late final GeneratedColumn<int> taskRevision = GeneratedColumn<int>(
    'task_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledMsMeta = const VerificationMeta(
    'scheduledMs',
  );
  @override
  late final GeneratedColumn<int> scheduledMs = GeneratedColumn<int>(
    'scheduled_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresMsMeta = const VerificationMeta(
    'expiresMs',
  );
  @override
  late final GeneratedColumn<int> expiresMs = GeneratedColumn<int>(
    'expires_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformIdMeta = const VerificationMeta(
    'platformId',
  );
  @override
  late final GeneratedColumn<int> platformId = GeneratedColumn<int>(
    'platform_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _readMeta = const VerificationMeta('read');
  @override
  late final GeneratedColumn<bool> read = GeneratedColumn<bool>(
    'read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedMsMeta = const VerificationMeta(
    'updatedMs',
  );
  @override
  late final GeneratedColumn<int> updatedMs = GeneratedColumn<int>(
    'updated_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventKey,
    taskId,
    ruleId,
    occurrenceId,
    occurrenceRevision,
    taskRevision,
    scheduledMs,
    expiresMs,
    state,
    platformId,
    read,
    title,
    priority,
    updatedMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminder_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderEventRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_key')) {
      context.handle(
        _eventKeyMeta,
        eventKey.isAcceptableOrUnknown(data['event_key']!, _eventKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_eventKeyMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('rule_id')) {
      context.handle(
        _ruleIdMeta,
        ruleId.isAcceptableOrUnknown(data['rule_id']!, _ruleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleIdMeta);
    }
    if (data.containsKey('occurrence_id')) {
      context.handle(
        _occurrenceIdMeta,
        occurrenceId.isAcceptableOrUnknown(
          data['occurrence_id']!,
          _occurrenceIdMeta,
        ),
      );
    }
    if (data.containsKey('occurrence_revision')) {
      context.handle(
        _occurrenceRevisionMeta,
        occurrenceRevision.isAcceptableOrUnknown(
          data['occurrence_revision']!,
          _occurrenceRevisionMeta,
        ),
      );
    }
    if (data.containsKey('task_revision')) {
      context.handle(
        _taskRevisionMeta,
        taskRevision.isAcceptableOrUnknown(
          data['task_revision']!,
          _taskRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_taskRevisionMeta);
    }
    if (data.containsKey('scheduled_ms')) {
      context.handle(
        _scheduledMsMeta,
        scheduledMs.isAcceptableOrUnknown(
          data['scheduled_ms']!,
          _scheduledMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledMsMeta);
    }
    if (data.containsKey('expires_ms')) {
      context.handle(
        _expiresMsMeta,
        expiresMs.isAcceptableOrUnknown(data['expires_ms']!, _expiresMsMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresMsMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('platform_id')) {
      context.handle(
        _platformIdMeta,
        platformId.isAcceptableOrUnknown(data['platform_id']!, _platformIdMeta),
      );
    }
    if (data.containsKey('read')) {
      context.handle(
        _readMeta,
        read.isAcceptableOrUnknown(data['read']!, _readMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('updated_ms')) {
      context.handle(
        _updatedMsMeta,
        updatedMs.isAcceptableOrUnknown(data['updated_ms']!, _updatedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {platformId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {eventKey},
  ];
  @override
  ReminderEventRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderEventRecord(
      eventKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_key'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      ruleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_id'],
      )!,
      occurrenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurrence_id'],
      ),
      occurrenceRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurrence_revision'],
      ),
      taskRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_revision'],
      )!,
      scheduledMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_ms'],
      )!,
      expiresMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_ms'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      platformId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}platform_id'],
      )!,
      read: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}read'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      updatedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_ms'],
      )!,
    );
  }

  @override
  $ReminderEventsTable createAlias(String alias) {
    return $ReminderEventsTable(attachedDatabase, alias);
  }
}

class ReminderEventRecord extends DataClass
    implements Insertable<ReminderEventRecord> {
  final String eventKey;
  final String taskId;
  final String ruleId;
  final String? occurrenceId;
  final int? occurrenceRevision;
  final int taskRevision;
  final int scheduledMs;
  final int expiresMs;
  final String state;
  final int platformId;
  final bool read;
  final String title;
  final int priority;
  final int updatedMs;
  const ReminderEventRecord({
    required this.eventKey,
    required this.taskId,
    required this.ruleId,
    this.occurrenceId,
    this.occurrenceRevision,
    required this.taskRevision,
    required this.scheduledMs,
    required this.expiresMs,
    required this.state,
    required this.platformId,
    required this.read,
    required this.title,
    required this.priority,
    required this.updatedMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_key'] = Variable<String>(eventKey);
    map['task_id'] = Variable<String>(taskId);
    map['rule_id'] = Variable<String>(ruleId);
    if (!nullToAbsent || occurrenceId != null) {
      map['occurrence_id'] = Variable<String>(occurrenceId);
    }
    if (!nullToAbsent || occurrenceRevision != null) {
      map['occurrence_revision'] = Variable<int>(occurrenceRevision);
    }
    map['task_revision'] = Variable<int>(taskRevision);
    map['scheduled_ms'] = Variable<int>(scheduledMs);
    map['expires_ms'] = Variable<int>(expiresMs);
    map['state'] = Variable<String>(state);
    map['platform_id'] = Variable<int>(platformId);
    map['read'] = Variable<bool>(read);
    map['title'] = Variable<String>(title);
    map['priority'] = Variable<int>(priority);
    map['updated_ms'] = Variable<int>(updatedMs);
    return map;
  }

  ReminderEventsCompanion toCompanion(bool nullToAbsent) {
    return ReminderEventsCompanion(
      eventKey: Value(eventKey),
      taskId: Value(taskId),
      ruleId: Value(ruleId),
      occurrenceId: occurrenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(occurrenceId),
      occurrenceRevision: occurrenceRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(occurrenceRevision),
      taskRevision: Value(taskRevision),
      scheduledMs: Value(scheduledMs),
      expiresMs: Value(expiresMs),
      state: Value(state),
      platformId: Value(platformId),
      read: Value(read),
      title: Value(title),
      priority: Value(priority),
      updatedMs: Value(updatedMs),
    );
  }

  factory ReminderEventRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderEventRecord(
      eventKey: serializer.fromJson<String>(json['eventKey']),
      taskId: serializer.fromJson<String>(json['taskId']),
      ruleId: serializer.fromJson<String>(json['ruleId']),
      occurrenceId: serializer.fromJson<String?>(json['occurrenceId']),
      occurrenceRevision: serializer.fromJson<int?>(json['occurrenceRevision']),
      taskRevision: serializer.fromJson<int>(json['taskRevision']),
      scheduledMs: serializer.fromJson<int>(json['scheduledMs']),
      expiresMs: serializer.fromJson<int>(json['expiresMs']),
      state: serializer.fromJson<String>(json['state']),
      platformId: serializer.fromJson<int>(json['platformId']),
      read: serializer.fromJson<bool>(json['read']),
      title: serializer.fromJson<String>(json['title']),
      priority: serializer.fromJson<int>(json['priority']),
      updatedMs: serializer.fromJson<int>(json['updatedMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventKey': serializer.toJson<String>(eventKey),
      'taskId': serializer.toJson<String>(taskId),
      'ruleId': serializer.toJson<String>(ruleId),
      'occurrenceId': serializer.toJson<String?>(occurrenceId),
      'occurrenceRevision': serializer.toJson<int?>(occurrenceRevision),
      'taskRevision': serializer.toJson<int>(taskRevision),
      'scheduledMs': serializer.toJson<int>(scheduledMs),
      'expiresMs': serializer.toJson<int>(expiresMs),
      'state': serializer.toJson<String>(state),
      'platformId': serializer.toJson<int>(platformId),
      'read': serializer.toJson<bool>(read),
      'title': serializer.toJson<String>(title),
      'priority': serializer.toJson<int>(priority),
      'updatedMs': serializer.toJson<int>(updatedMs),
    };
  }

  ReminderEventRecord copyWith({
    String? eventKey,
    String? taskId,
    String? ruleId,
    Value<String?> occurrenceId = const Value.absent(),
    Value<int?> occurrenceRevision = const Value.absent(),
    int? taskRevision,
    int? scheduledMs,
    int? expiresMs,
    String? state,
    int? platformId,
    bool? read,
    String? title,
    int? priority,
    int? updatedMs,
  }) => ReminderEventRecord(
    eventKey: eventKey ?? this.eventKey,
    taskId: taskId ?? this.taskId,
    ruleId: ruleId ?? this.ruleId,
    occurrenceId: occurrenceId.present ? occurrenceId.value : this.occurrenceId,
    occurrenceRevision: occurrenceRevision.present
        ? occurrenceRevision.value
        : this.occurrenceRevision,
    taskRevision: taskRevision ?? this.taskRevision,
    scheduledMs: scheduledMs ?? this.scheduledMs,
    expiresMs: expiresMs ?? this.expiresMs,
    state: state ?? this.state,
    platformId: platformId ?? this.platformId,
    read: read ?? this.read,
    title: title ?? this.title,
    priority: priority ?? this.priority,
    updatedMs: updatedMs ?? this.updatedMs,
  );
  ReminderEventRecord copyWithCompanion(ReminderEventsCompanion data) {
    return ReminderEventRecord(
      eventKey: data.eventKey.present ? data.eventKey.value : this.eventKey,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      ruleId: data.ruleId.present ? data.ruleId.value : this.ruleId,
      occurrenceId: data.occurrenceId.present
          ? data.occurrenceId.value
          : this.occurrenceId,
      occurrenceRevision: data.occurrenceRevision.present
          ? data.occurrenceRevision.value
          : this.occurrenceRevision,
      taskRevision: data.taskRevision.present
          ? data.taskRevision.value
          : this.taskRevision,
      scheduledMs: data.scheduledMs.present
          ? data.scheduledMs.value
          : this.scheduledMs,
      expiresMs: data.expiresMs.present ? data.expiresMs.value : this.expiresMs,
      state: data.state.present ? data.state.value : this.state,
      platformId: data.platformId.present
          ? data.platformId.value
          : this.platformId,
      read: data.read.present ? data.read.value : this.read,
      title: data.title.present ? data.title.value : this.title,
      priority: data.priority.present ? data.priority.value : this.priority,
      updatedMs: data.updatedMs.present ? data.updatedMs.value : this.updatedMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderEventRecord(')
          ..write('eventKey: $eventKey, ')
          ..write('taskId: $taskId, ')
          ..write('ruleId: $ruleId, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('occurrenceRevision: $occurrenceRevision, ')
          ..write('taskRevision: $taskRevision, ')
          ..write('scheduledMs: $scheduledMs, ')
          ..write('expiresMs: $expiresMs, ')
          ..write('state: $state, ')
          ..write('platformId: $platformId, ')
          ..write('read: $read, ')
          ..write('title: $title, ')
          ..write('priority: $priority, ')
          ..write('updatedMs: $updatedMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eventKey,
    taskId,
    ruleId,
    occurrenceId,
    occurrenceRevision,
    taskRevision,
    scheduledMs,
    expiresMs,
    state,
    platformId,
    read,
    title,
    priority,
    updatedMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderEventRecord &&
          other.eventKey == this.eventKey &&
          other.taskId == this.taskId &&
          other.ruleId == this.ruleId &&
          other.occurrenceId == this.occurrenceId &&
          other.occurrenceRevision == this.occurrenceRevision &&
          other.taskRevision == this.taskRevision &&
          other.scheduledMs == this.scheduledMs &&
          other.expiresMs == this.expiresMs &&
          other.state == this.state &&
          other.platformId == this.platformId &&
          other.read == this.read &&
          other.title == this.title &&
          other.priority == this.priority &&
          other.updatedMs == this.updatedMs);
}

class ReminderEventsCompanion extends UpdateCompanion<ReminderEventRecord> {
  final Value<String> eventKey;
  final Value<String> taskId;
  final Value<String> ruleId;
  final Value<String?> occurrenceId;
  final Value<int?> occurrenceRevision;
  final Value<int> taskRevision;
  final Value<int> scheduledMs;
  final Value<int> expiresMs;
  final Value<String> state;
  final Value<int> platformId;
  final Value<bool> read;
  final Value<String> title;
  final Value<int> priority;
  final Value<int> updatedMs;
  const ReminderEventsCompanion({
    this.eventKey = const Value.absent(),
    this.taskId = const Value.absent(),
    this.ruleId = const Value.absent(),
    this.occurrenceId = const Value.absent(),
    this.occurrenceRevision = const Value.absent(),
    this.taskRevision = const Value.absent(),
    this.scheduledMs = const Value.absent(),
    this.expiresMs = const Value.absent(),
    this.state = const Value.absent(),
    this.platformId = const Value.absent(),
    this.read = const Value.absent(),
    this.title = const Value.absent(),
    this.priority = const Value.absent(),
    this.updatedMs = const Value.absent(),
  });
  ReminderEventsCompanion.insert({
    required String eventKey,
    required String taskId,
    required String ruleId,
    this.occurrenceId = const Value.absent(),
    this.occurrenceRevision = const Value.absent(),
    required int taskRevision,
    required int scheduledMs,
    required int expiresMs,
    required String state,
    this.platformId = const Value.absent(),
    this.read = const Value.absent(),
    required String title,
    required int priority,
    required int updatedMs,
  }) : eventKey = Value(eventKey),
       taskId = Value(taskId),
       ruleId = Value(ruleId),
       taskRevision = Value(taskRevision),
       scheduledMs = Value(scheduledMs),
       expiresMs = Value(expiresMs),
       state = Value(state),
       title = Value(title),
       priority = Value(priority),
       updatedMs = Value(updatedMs);
  static Insertable<ReminderEventRecord> custom({
    Expression<String>? eventKey,
    Expression<String>? taskId,
    Expression<String>? ruleId,
    Expression<String>? occurrenceId,
    Expression<int>? occurrenceRevision,
    Expression<int>? taskRevision,
    Expression<int>? scheduledMs,
    Expression<int>? expiresMs,
    Expression<String>? state,
    Expression<int>? platformId,
    Expression<bool>? read,
    Expression<String>? title,
    Expression<int>? priority,
    Expression<int>? updatedMs,
  }) {
    return RawValuesInsertable({
      if (eventKey != null) 'event_key': eventKey,
      if (taskId != null) 'task_id': taskId,
      if (ruleId != null) 'rule_id': ruleId,
      if (occurrenceId != null) 'occurrence_id': occurrenceId,
      if (occurrenceRevision != null) 'occurrence_revision': occurrenceRevision,
      if (taskRevision != null) 'task_revision': taskRevision,
      if (scheduledMs != null) 'scheduled_ms': scheduledMs,
      if (expiresMs != null) 'expires_ms': expiresMs,
      if (state != null) 'state': state,
      if (platformId != null) 'platform_id': platformId,
      if (read != null) 'read': read,
      if (title != null) 'title': title,
      if (priority != null) 'priority': priority,
      if (updatedMs != null) 'updated_ms': updatedMs,
    });
  }

  ReminderEventsCompanion copyWith({
    Value<String>? eventKey,
    Value<String>? taskId,
    Value<String>? ruleId,
    Value<String?>? occurrenceId,
    Value<int?>? occurrenceRevision,
    Value<int>? taskRevision,
    Value<int>? scheduledMs,
    Value<int>? expiresMs,
    Value<String>? state,
    Value<int>? platformId,
    Value<bool>? read,
    Value<String>? title,
    Value<int>? priority,
    Value<int>? updatedMs,
  }) {
    return ReminderEventsCompanion(
      eventKey: eventKey ?? this.eventKey,
      taskId: taskId ?? this.taskId,
      ruleId: ruleId ?? this.ruleId,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      occurrenceRevision: occurrenceRevision ?? this.occurrenceRevision,
      taskRevision: taskRevision ?? this.taskRevision,
      scheduledMs: scheduledMs ?? this.scheduledMs,
      expiresMs: expiresMs ?? this.expiresMs,
      state: state ?? this.state,
      platformId: platformId ?? this.platformId,
      read: read ?? this.read,
      title: title ?? this.title,
      priority: priority ?? this.priority,
      updatedMs: updatedMs ?? this.updatedMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventKey.present) {
      map['event_key'] = Variable<String>(eventKey.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (ruleId.present) {
      map['rule_id'] = Variable<String>(ruleId.value);
    }
    if (occurrenceId.present) {
      map['occurrence_id'] = Variable<String>(occurrenceId.value);
    }
    if (occurrenceRevision.present) {
      map['occurrence_revision'] = Variable<int>(occurrenceRevision.value);
    }
    if (taskRevision.present) {
      map['task_revision'] = Variable<int>(taskRevision.value);
    }
    if (scheduledMs.present) {
      map['scheduled_ms'] = Variable<int>(scheduledMs.value);
    }
    if (expiresMs.present) {
      map['expires_ms'] = Variable<int>(expiresMs.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (platformId.present) {
      map['platform_id'] = Variable<int>(platformId.value);
    }
    if (read.present) {
      map['read'] = Variable<bool>(read.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (updatedMs.present) {
      map['updated_ms'] = Variable<int>(updatedMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReminderEventsCompanion(')
          ..write('eventKey: $eventKey, ')
          ..write('taskId: $taskId, ')
          ..write('ruleId: $ruleId, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('occurrenceRevision: $occurrenceRevision, ')
          ..write('taskRevision: $taskRevision, ')
          ..write('scheduledMs: $scheduledMs, ')
          ..write('expiresMs: $expiresMs, ')
          ..write('state: $state, ')
          ..write('platformId: $platformId, ')
          ..write('read: $read, ')
          ..write('title: $title, ')
          ..write('priority: $priority, ')
          ..write('updatedMs: $updatedMs')
          ..write(')'))
        .toString();
  }
}

class $DeliveryLogsTable extends DeliveryLogs
    with TableInfo<$DeliveryLogsTable, DeliveryLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeliveryLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventKeyMeta = const VerificationMeta(
    'eventKey',
  );
  @override
  late final GeneratedColumn<String> eventKey = GeneratedColumn<String>(
    'event_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMsMeta = const VerificationMeta('atMs');
  @override
  late final GeneratedColumn<int> atMs = GeneratedColumn<int>(
    'at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, eventKey, outcome, atMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'delivery_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeliveryLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_key')) {
      context.handle(
        _eventKeyMeta,
        eventKey.isAcceptableOrUnknown(data['event_key']!, _eventKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_eventKeyMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('at_ms')) {
      context.handle(
        _atMsMeta,
        atMs.isAcceptableOrUnknown(data['at_ms']!, _atMsMeta),
      );
    } else if (isInserting) {
      context.missing(_atMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeliveryLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeliveryLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_key'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      )!,
      atMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at_ms'],
      )!,
    );
  }

  @override
  $DeliveryLogsTable createAlias(String alias) {
    return $DeliveryLogsTable(attachedDatabase, alias);
  }
}

class DeliveryLog extends DataClass implements Insertable<DeliveryLog> {
  final String id;
  final String eventKey;
  final String outcome;
  final int atMs;
  const DeliveryLog({
    required this.id,
    required this.eventKey,
    required this.outcome,
    required this.atMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_key'] = Variable<String>(eventKey);
    map['outcome'] = Variable<String>(outcome);
    map['at_ms'] = Variable<int>(atMs);
    return map;
  }

  DeliveryLogsCompanion toCompanion(bool nullToAbsent) {
    return DeliveryLogsCompanion(
      id: Value(id),
      eventKey: Value(eventKey),
      outcome: Value(outcome),
      atMs: Value(atMs),
    );
  }

  factory DeliveryLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeliveryLog(
      id: serializer.fromJson<String>(json['id']),
      eventKey: serializer.fromJson<String>(json['eventKey']),
      outcome: serializer.fromJson<String>(json['outcome']),
      atMs: serializer.fromJson<int>(json['atMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventKey': serializer.toJson<String>(eventKey),
      'outcome': serializer.toJson<String>(outcome),
      'atMs': serializer.toJson<int>(atMs),
    };
  }

  DeliveryLog copyWith({
    String? id,
    String? eventKey,
    String? outcome,
    int? atMs,
  }) => DeliveryLog(
    id: id ?? this.id,
    eventKey: eventKey ?? this.eventKey,
    outcome: outcome ?? this.outcome,
    atMs: atMs ?? this.atMs,
  );
  DeliveryLog copyWithCompanion(DeliveryLogsCompanion data) {
    return DeliveryLog(
      id: data.id.present ? data.id.value : this.id,
      eventKey: data.eventKey.present ? data.eventKey.value : this.eventKey,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      atMs: data.atMs.present ? data.atMs.value : this.atMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeliveryLog(')
          ..write('id: $id, ')
          ..write('eventKey: $eventKey, ')
          ..write('outcome: $outcome, ')
          ..write('atMs: $atMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, eventKey, outcome, atMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeliveryLog &&
          other.id == this.id &&
          other.eventKey == this.eventKey &&
          other.outcome == this.outcome &&
          other.atMs == this.atMs);
}

class DeliveryLogsCompanion extends UpdateCompanion<DeliveryLog> {
  final Value<String> id;
  final Value<String> eventKey;
  final Value<String> outcome;
  final Value<int> atMs;
  final Value<int> rowid;
  const DeliveryLogsCompanion({
    this.id = const Value.absent(),
    this.eventKey = const Value.absent(),
    this.outcome = const Value.absent(),
    this.atMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeliveryLogsCompanion.insert({
    required String id,
    required String eventKey,
    required String outcome,
    required int atMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventKey = Value(eventKey),
       outcome = Value(outcome),
       atMs = Value(atMs);
  static Insertable<DeliveryLog> custom({
    Expression<String>? id,
    Expression<String>? eventKey,
    Expression<String>? outcome,
    Expression<int>? atMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventKey != null) 'event_key': eventKey,
      if (outcome != null) 'outcome': outcome,
      if (atMs != null) 'at_ms': atMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeliveryLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? eventKey,
    Value<String>? outcome,
    Value<int>? atMs,
    Value<int>? rowid,
  }) {
    return DeliveryLogsCompanion(
      id: id ?? this.id,
      eventKey: eventKey ?? this.eventKey,
      outcome: outcome ?? this.outcome,
      atMs: atMs ?? this.atMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventKey.present) {
      map['event_key'] = Variable<String>(eventKey.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (atMs.present) {
      map['at_ms'] = Variable<int>(atMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeliveryLogsCompanion(')
          ..write('id: $id, ')
          ..write('eventKey: $eventKey, ')
          ..write('outcome: $outcome, ')
          ..write('atMs: $atMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DaymindDatabase extends GeneratedDatabase {
  _$DaymindDatabase(QueryExecutor e) : super(e);
  $DaymindDatabaseManager get managers => $DaymindDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $PreferencesTable preferences = $PreferencesTable(this);
  late final $ExtensionRecordsTable extensionRecords = $ExtensionRecordsTable(
    this,
  );
  late final $ReminderEventsTable reminderEvents = $ReminderEventsTable(this);
  late final $DeliveryLogsTable deliveryLogs = $DeliveryLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    tasks,
    preferences,
    extensionRecords,
    reminderEvents,
    deliveryLogs,
  ];
}

typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required String name,
  required int color,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> color,
  Value<int> rowid,
});

final class $$CategoriesTableReferences
    extends
        BaseReferences<_$DaymindDatabase, $CategoriesTable, CategoryRecord> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TasksTable, List<TaskRecord>> _tasksRefsTable(
    _$DaymindDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'categories__id__tasks__category_id',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$DaymindDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$DaymindDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$DaymindDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
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

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$DaymindDatabase,
          $CategoriesTable,
          CategoryRecord,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (CategoryRecord, $$CategoriesTableReferences),
          CategoryRecord,
          PrefetchHooks Function({bool tasksRefs})
        > {
  $$CategoriesTableTableManager(_$DaymindDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                color: color,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int color,
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                color: color,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, CategoryRecord>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tasksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tasksRefs) db.tasks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tasksRefs)
                    await $_getPrefetchedDataByColumns<
                      CategoryRecord,
                      $CategoriesTable,
                      TaskRecord,
                      $TasksTable
                    >(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences
                          ._tasksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoriesTableReferences(db, table, p0).tasksRefs,
                      currentColumn: 'id',
                      referencedColumn: 'category_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$DaymindDatabase,
      $CategoriesTable,
      CategoryRecord,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (CategoryRecord, $$CategoriesTableReferences),
      CategoryRecord,
      PrefetchHooks Function({bool tasksRefs})
    >;
typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  required String id,
  required String title,
  Value<String> description,
  required int priority,
  required int status,
  Value<String?> categoryId,
  Value<DateTime?> dueAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> completedAt,
  Value<DateTime?> deletedAt,
  Value<DateTime?> scheduledStartAt,
  Value<DateTime?> scheduledEndAt,
  Value<int> revision,
  Value<int> rowid,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> description,
  Value<int> priority,
  Value<int> status,
  Value<String?> categoryId,
  Value<DateTime?> dueAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> completedAt,
  Value<DateTime?> deletedAt,
  Value<DateTime?> scheduledStartAt,
  Value<DateTime?> scheduledEndAt,
  Value<int> revision,
  Value<int> rowid,
});

final class $$TasksTableReferences
    extends BaseReferences<_$DaymindDatabase, $TasksTable, TaskRecord> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoriesTable _categoryIdTable(_$DaymindDatabase db) =>
      db.categories.createAlias('tasks__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TasksTableFilterComposer
    extends Composer<_$DaymindDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledStartAt => $composableBuilder(
    column: $table.scheduledStartAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledEndAt => $composableBuilder(
    column: $table.scheduledEndAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$DaymindDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledStartAt => $composableBuilder(
    column: $table.scheduledStartAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledEndAt => $composableBuilder(
    column: $table.scheduledEndAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableAnnotationComposer
    extends Composer<_$DaymindDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledStartAt => $composableBuilder(
    column: $table.scheduledStartAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scheduledEndAt => $composableBuilder(
    column: $table.scheduledEndAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$DaymindDatabase,
          $TasksTable,
          TaskRecord,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (TaskRecord, $$TasksTableReferences),
          TaskRecord,
          PrefetchHooks Function({bool categoryId})
        > {
  $$TasksTableTableManager(_$DaymindDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> scheduledStartAt = const Value.absent(),
                Value<DateTime?> scheduledEndAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                title: title,
                description: description,
                priority: priority,
                status: status,
                categoryId: categoryId,
                dueAt: dueAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                deletedAt: deletedAt,
                scheduledStartAt: scheduledStartAt,
                scheduledEndAt: scheduledEndAt,
                revision: revision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> description = const Value.absent(),
                required int priority,
                required int status,
                Value<String?> categoryId = const Value.absent(),
                Value<DateTime?> dueAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> scheduledStartAt = const Value.absent(),
                Value<DateTime?> scheduledEndAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                title: title,
                description: description,
                priority: priority,
                status: status,
                categoryId: categoryId,
                dueAt: dueAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                deletedAt: deletedAt,
                scheduledStartAt: scheduledStartAt,
                scheduledEndAt: scheduledEndAt,
                revision: revision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TasksTable, TaskRecord>(table),
                  $$TasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
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
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$TasksTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$TasksTableReferences
                            ._categoryIdTable(db)
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

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$DaymindDatabase,
      $TasksTable,
      TaskRecord,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (TaskRecord, $$TasksTableReferences),
      TaskRecord,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$PreferencesTableCreateCompanionBuilder =
    PreferencesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$PreferencesTableUpdateCompanionBuilder =
    PreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$PreferencesTableFilterComposer
    extends Composer<_$DaymindDatabase, $PreferencesTable> {
  $$PreferencesTableFilterComposer({
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

class $$PreferencesTableOrderingComposer
    extends Composer<_$DaymindDatabase, $PreferencesTable> {
  $$PreferencesTableOrderingComposer({
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

class $$PreferencesTableAnnotationComposer
    extends Composer<_$DaymindDatabase, $PreferencesTable> {
  $$PreferencesTableAnnotationComposer({
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

class $$PreferencesTableTableManager
    extends
        RootTableManager<
          _$DaymindDatabase,
          $PreferencesTable,
          Preference,
          $$PreferencesTableFilterComposer,
          $$PreferencesTableOrderingComposer,
          $$PreferencesTableAnnotationComposer,
          $$PreferencesTableCreateCompanionBuilder,
          $$PreferencesTableUpdateCompanionBuilder,
          (
            Preference,
            BaseReferences<_$DaymindDatabase, $PreferencesTable, Preference>,
          ),
          Preference,
          PrefetchHooks Function()
        > {
  $$PreferencesTableTableManager(_$DaymindDatabase db, $PreferencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PreferencesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => PreferencesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PreferencesTable, Preference>(table),
                  BaseReferences<
                    _$DaymindDatabase,
                    $PreferencesTable,
                    Preference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$DaymindDatabase,
      $PreferencesTable,
      Preference,
      $$PreferencesTableFilterComposer,
      $$PreferencesTableOrderingComposer,
      $$PreferencesTableAnnotationComposer,
      $$PreferencesTableCreateCompanionBuilder,
      $$PreferencesTableUpdateCompanionBuilder,
      (
        Preference,
        BaseReferences<_$DaymindDatabase, $PreferencesTable, Preference>,
      ),
      Preference,
      PrefetchHooks Function()
    >;
typedef $$ExtensionRecordsTableCreateCompanionBuilder =
    ExtensionRecordsCompanion Function({
      required String area,
      required String id,
      required String value,
      required int updatedMs,
      Value<int> rowid,
    });
typedef $$ExtensionRecordsTableUpdateCompanionBuilder =
    ExtensionRecordsCompanion Function({
      Value<String> area,
      Value<String> id,
      Value<String> value,
      Value<int> updatedMs,
      Value<int> rowid,
    });

class $$ExtensionRecordsTableFilterComposer
    extends Composer<_$DaymindDatabase, $ExtensionRecordsTable> {
  $$ExtensionRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExtensionRecordsTableOrderingComposer
    extends Composer<_$DaymindDatabase, $ExtensionRecordsTable> {
  $$ExtensionRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get area => $composableBuilder(
    column: $table.area,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExtensionRecordsTableAnnotationComposer
    extends Composer<_$DaymindDatabase, $ExtensionRecordsTable> {
  $$ExtensionRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get area =>
      $composableBuilder(column: $table.area, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedMs =>
      $composableBuilder(column: $table.updatedMs, builder: (column) => column);
}

class $$ExtensionRecordsTableTableManager
    extends
        RootTableManager<
          _$DaymindDatabase,
          $ExtensionRecordsTable,
          ExtensionRecord,
          $$ExtensionRecordsTableFilterComposer,
          $$ExtensionRecordsTableOrderingComposer,
          $$ExtensionRecordsTableAnnotationComposer,
          $$ExtensionRecordsTableCreateCompanionBuilder,
          $$ExtensionRecordsTableUpdateCompanionBuilder,
          (
            ExtensionRecord,
            BaseReferences<
              _$DaymindDatabase,
              $ExtensionRecordsTable,
              ExtensionRecord
            >,
          ),
          ExtensionRecord,
          PrefetchHooks Function()
        > {
  $$ExtensionRecordsTableTableManager(
    _$DaymindDatabase db,
    $ExtensionRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExtensionRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExtensionRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExtensionRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> area = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExtensionRecordsCompanion(
                area: area,
                id: id,
                value: value,
                updatedMs: updatedMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String area,
                required String id,
                required String value,
                required int updatedMs,
                Value<int> rowid = const Value.absent(),
              }) => ExtensionRecordsCompanion.insert(
                area: area,
                id: id,
                value: value,
                updatedMs: updatedMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExtensionRecordsTable, ExtensionRecord>(table),
                  BaseReferences<
                    _$DaymindDatabase,
                    $ExtensionRecordsTable,
                    ExtensionRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExtensionRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$DaymindDatabase,
      $ExtensionRecordsTable,
      ExtensionRecord,
      $$ExtensionRecordsTableFilterComposer,
      $$ExtensionRecordsTableOrderingComposer,
      $$ExtensionRecordsTableAnnotationComposer,
      $$ExtensionRecordsTableCreateCompanionBuilder,
      $$ExtensionRecordsTableUpdateCompanionBuilder,
      (
        ExtensionRecord,
        BaseReferences<
          _$DaymindDatabase,
          $ExtensionRecordsTable,
          ExtensionRecord
        >,
      ),
      ExtensionRecord,
      PrefetchHooks Function()
    >;
typedef $$ReminderEventsTableCreateCompanionBuilder =
    ReminderEventsCompanion Function({
      required String eventKey,
      required String taskId,
      required String ruleId,
      Value<String?> occurrenceId,
      Value<int?> occurrenceRevision,
      required int taskRevision,
      required int scheduledMs,
      required int expiresMs,
      required String state,
      Value<int> platformId,
      Value<bool> read,
      required String title,
      required int priority,
      required int updatedMs,
    });
typedef $$ReminderEventsTableUpdateCompanionBuilder =
    ReminderEventsCompanion Function({
      Value<String> eventKey,
      Value<String> taskId,
      Value<String> ruleId,
      Value<String?> occurrenceId,
      Value<int?> occurrenceRevision,
      Value<int> taskRevision,
      Value<int> scheduledMs,
      Value<int> expiresMs,
      Value<String> state,
      Value<int> platformId,
      Value<bool> read,
      Value<String> title,
      Value<int> priority,
      Value<int> updatedMs,
    });

class $$ReminderEventsTableFilterComposer
    extends Composer<_$DaymindDatabase, $ReminderEventsTable> {
  $$ReminderEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventKey => $composableBuilder(
    column: $table.eventKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurrenceRevision => $composableBuilder(
    column: $table.occurrenceRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taskRevision => $composableBuilder(
    column: $table.taskRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledMs => $composableBuilder(
    column: $table.scheduledMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresMs => $composableBuilder(
    column: $table.expiresMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReminderEventsTableOrderingComposer
    extends Composer<_$DaymindDatabase, $ReminderEventsTable> {
  $$ReminderEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventKey => $composableBuilder(
    column: $table.eventKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleId => $composableBuilder(
    column: $table.ruleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurrenceRevision => $composableBuilder(
    column: $table.occurrenceRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taskRevision => $composableBuilder(
    column: $table.taskRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledMs => $composableBuilder(
    column: $table.scheduledMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresMs => $composableBuilder(
    column: $table.expiresMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get read => $composableBuilder(
    column: $table.read,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedMs => $composableBuilder(
    column: $table.updatedMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReminderEventsTableAnnotationComposer
    extends Composer<_$DaymindDatabase, $ReminderEventsTable> {
  $$ReminderEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventKey =>
      $composableBuilder(column: $table.eventKey, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get ruleId =>
      $composableBuilder(column: $table.ruleId, builder: (column) => column);

  GeneratedColumn<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get occurrenceRevision => $composableBuilder(
    column: $table.occurrenceRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get taskRevision => $composableBuilder(
    column: $table.taskRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduledMs => $composableBuilder(
    column: $table.scheduledMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expiresMs =>
      $composableBuilder(column: $table.expiresMs, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get platformId => $composableBuilder(
    column: $table.platformId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get read =>
      $composableBuilder(column: $table.read, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get updatedMs =>
      $composableBuilder(column: $table.updatedMs, builder: (column) => column);
}

class $$ReminderEventsTableTableManager
    extends
        RootTableManager<
          _$DaymindDatabase,
          $ReminderEventsTable,
          ReminderEventRecord,
          $$ReminderEventsTableFilterComposer,
          $$ReminderEventsTableOrderingComposer,
          $$ReminderEventsTableAnnotationComposer,
          $$ReminderEventsTableCreateCompanionBuilder,
          $$ReminderEventsTableUpdateCompanionBuilder,
          (
            ReminderEventRecord,
            BaseReferences<
              _$DaymindDatabase,
              $ReminderEventsTable,
              ReminderEventRecord
            >,
          ),
          ReminderEventRecord,
          PrefetchHooks Function()
        > {
  $$ReminderEventsTableTableManager(
    _$DaymindDatabase db,
    $ReminderEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReminderEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReminderEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReminderEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventKey = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> ruleId = const Value.absent(),
                Value<String?> occurrenceId = const Value.absent(),
                Value<int?> occurrenceRevision = const Value.absent(),
                Value<int> taskRevision = const Value.absent(),
                Value<int> scheduledMs = const Value.absent(),
                Value<int> expiresMs = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> platformId = const Value.absent(),
                Value<bool> read = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> updatedMs = const Value.absent(),
              }) => ReminderEventsCompanion(
                eventKey: eventKey,
                taskId: taskId,
                ruleId: ruleId,
                occurrenceId: occurrenceId,
                occurrenceRevision: occurrenceRevision,
                taskRevision: taskRevision,
                scheduledMs: scheduledMs,
                expiresMs: expiresMs,
                state: state,
                platformId: platformId,
                read: read,
                title: title,
                priority: priority,
                updatedMs: updatedMs,
              ),
          createCompanionCallback:
              ({
                required String eventKey,
                required String taskId,
                required String ruleId,
                Value<String?> occurrenceId = const Value.absent(),
                Value<int?> occurrenceRevision = const Value.absent(),
                required int taskRevision,
                required int scheduledMs,
                required int expiresMs,
                required String state,
                Value<int> platformId = const Value.absent(),
                Value<bool> read = const Value.absent(),
                required String title,
                required int priority,
                required int updatedMs,
              }) => ReminderEventsCompanion.insert(
                eventKey: eventKey,
                taskId: taskId,
                ruleId: ruleId,
                occurrenceId: occurrenceId,
                occurrenceRevision: occurrenceRevision,
                taskRevision: taskRevision,
                scheduledMs: scheduledMs,
                expiresMs: expiresMs,
                state: state,
                platformId: platformId,
                read: read,
                title: title,
                priority: priority,
                updatedMs: updatedMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReminderEventsTable, ReminderEventRecord>(table),
                  BaseReferences<
                    _$DaymindDatabase,
                    $ReminderEventsTable,
                    ReminderEventRecord
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReminderEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$DaymindDatabase,
      $ReminderEventsTable,
      ReminderEventRecord,
      $$ReminderEventsTableFilterComposer,
      $$ReminderEventsTableOrderingComposer,
      $$ReminderEventsTableAnnotationComposer,
      $$ReminderEventsTableCreateCompanionBuilder,
      $$ReminderEventsTableUpdateCompanionBuilder,
      (
        ReminderEventRecord,
        BaseReferences<
          _$DaymindDatabase,
          $ReminderEventsTable,
          ReminderEventRecord
        >,
      ),
      ReminderEventRecord,
      PrefetchHooks Function()
    >;
typedef $$DeliveryLogsTableCreateCompanionBuilder =
    DeliveryLogsCompanion Function({
      required String id,
      required String eventKey,
      required String outcome,
      required int atMs,
      Value<int> rowid,
    });
typedef $$DeliveryLogsTableUpdateCompanionBuilder =
    DeliveryLogsCompanion Function({
      Value<String> id,
      Value<String> eventKey,
      Value<String> outcome,
      Value<int> atMs,
      Value<int> rowid,
    });

class $$DeliveryLogsTableFilterComposer
    extends Composer<_$DaymindDatabase, $DeliveryLogsTable> {
  $$DeliveryLogsTableFilterComposer({
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

  ColumnFilters<String> get eventKey => $composableBuilder(
    column: $table.eventKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get atMs => $composableBuilder(
    column: $table.atMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeliveryLogsTableOrderingComposer
    extends Composer<_$DaymindDatabase, $DeliveryLogsTable> {
  $$DeliveryLogsTableOrderingComposer({
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

  ColumnOrderings<String> get eventKey => $composableBuilder(
    column: $table.eventKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get atMs => $composableBuilder(
    column: $table.atMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeliveryLogsTableAnnotationComposer
    extends Composer<_$DaymindDatabase, $DeliveryLogsTable> {
  $$DeliveryLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventKey =>
      $composableBuilder(column: $table.eventKey, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<int> get atMs =>
      $composableBuilder(column: $table.atMs, builder: (column) => column);
}

class $$DeliveryLogsTableTableManager
    extends
        RootTableManager<
          _$DaymindDatabase,
          $DeliveryLogsTable,
          DeliveryLog,
          $$DeliveryLogsTableFilterComposer,
          $$DeliveryLogsTableOrderingComposer,
          $$DeliveryLogsTableAnnotationComposer,
          $$DeliveryLogsTableCreateCompanionBuilder,
          $$DeliveryLogsTableUpdateCompanionBuilder,
          (
            DeliveryLog,
            BaseReferences<_$DaymindDatabase, $DeliveryLogsTable, DeliveryLog>,
          ),
          DeliveryLog,
          PrefetchHooks Function()
        > {
  $$DeliveryLogsTableTableManager(
    _$DaymindDatabase db,
    $DeliveryLogsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeliveryLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeliveryLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeliveryLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventKey = const Value.absent(),
                Value<String> outcome = const Value.absent(),
                Value<int> atMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeliveryLogsCompanion(
                id: id,
                eventKey: eventKey,
                outcome: outcome,
                atMs: atMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventKey,
                required String outcome,
                required int atMs,
                Value<int> rowid = const Value.absent(),
              }) => DeliveryLogsCompanion.insert(
                id: id,
                eventKey: eventKey,
                outcome: outcome,
                atMs: atMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DeliveryLogsTable, DeliveryLog>(table),
                  BaseReferences<
                    _$DaymindDatabase,
                    $DeliveryLogsTable,
                    DeliveryLog
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeliveryLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$DaymindDatabase,
      $DeliveryLogsTable,
      DeliveryLog,
      $$DeliveryLogsTableFilterComposer,
      $$DeliveryLogsTableOrderingComposer,
      $$DeliveryLogsTableAnnotationComposer,
      $$DeliveryLogsTableCreateCompanionBuilder,
      $$DeliveryLogsTableUpdateCompanionBuilder,
      (
        DeliveryLog,
        BaseReferences<_$DaymindDatabase, $DeliveryLogsTable, DeliveryLog>,
      ),
      DeliveryLog,
      PrefetchHooks Function()
    >;

class $DaymindDatabaseManager {
  final _$DaymindDatabase _db;
  $DaymindDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$PreferencesTableTableManager get preferences =>
      $$PreferencesTableTableManager(_db, _db.preferences);
  $$ExtensionRecordsTableTableManager get extensionRecords =>
      $$ExtensionRecordsTableTableManager(_db, _db.extensionRecords);
  $$ReminderEventsTableTableManager get reminderEvents =>
      $$ReminderEventsTableTableManager(_db, _db.reminderEvents);
  $$DeliveryLogsTableTableManager get deliveryLogs =>
      $$DeliveryLogsTableTableManager(_db, _db.deliveryLogs);
}
