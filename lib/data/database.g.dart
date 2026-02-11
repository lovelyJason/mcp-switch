// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ProviderProfilesTable extends ProviderProfiles
    with TableInfo<$ProviderProfilesTable, ProviderProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editorTypeMeta = const VerificationMeta(
    'editorType',
  );
  @override
  late final GeneratedColumn<String> editorType = GeneratedColumn<String>(
    'editor_type',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _apiTokenMeta = const VerificationMeta(
    'apiToken',
  );
  @override
  late final GeneratedColumn<String> apiToken = GeneratedColumn<String>(
    'api_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxOutputTokensMeta = const VerificationMeta(
    'maxOutputTokens',
  );
  @override
  late final GeneratedColumn<String> maxOutputTokens = GeneratedColumn<String>(
    'max_output_tokens',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxThinkingTokensMeta = const VerificationMeta(
    'maxThinkingTokens',
  );
  @override
  late final GeneratedColumn<String> maxThinkingTokens =
      GeneratedColumn<String>(
        'max_thinking_tokens',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _websiteMeta = const VerificationMeta(
    'website',
  );
  @override
  late final GeneratedColumn<String> website = GeneratedColumn<String>(
    'website',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelReasoningEffortMeta =
      const VerificationMeta('modelReasoningEffort');
  @override
  late final GeneratedColumn<String> modelReasoningEffort =
      GeneratedColumn<String>(
        'model_reasoning_effort',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _personalityMeta = const VerificationMeta(
    'personality',
  );
  @override
  late final GeneratedColumn<String> personality = GeneratedColumn<String>(
    'personality',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _oauthDataMeta = const VerificationMeta(
    'oauthData',
  );
  @override
  late final GeneratedColumn<String> oauthData = GeneratedColumn<String>(
    'oauth_data',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    editorType,
    name,
    description,
    isActive,
    apiToken,
    baseUrl,
    model,
    maxOutputTokens,
    maxThinkingTokens,
    website,
    modelReasoningEffort,
    personality,
    oauthData,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('editor_type')) {
      context.handle(
        _editorTypeMeta,
        editorType.isAcceptableOrUnknown(data['editor_type']!, _editorTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_editorTypeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
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
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('api_token')) {
      context.handle(
        _apiTokenMeta,
        apiToken.isAcceptableOrUnknown(data['api_token']!, _apiTokenMeta),
      );
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('max_output_tokens')) {
      context.handle(
        _maxOutputTokensMeta,
        maxOutputTokens.isAcceptableOrUnknown(
          data['max_output_tokens']!,
          _maxOutputTokensMeta,
        ),
      );
    }
    if (data.containsKey('max_thinking_tokens')) {
      context.handle(
        _maxThinkingTokensMeta,
        maxThinkingTokens.isAcceptableOrUnknown(
          data['max_thinking_tokens']!,
          _maxThinkingTokensMeta,
        ),
      );
    }
    if (data.containsKey('website')) {
      context.handle(
        _websiteMeta,
        website.isAcceptableOrUnknown(data['website']!, _websiteMeta),
      );
    }
    if (data.containsKey('model_reasoning_effort')) {
      context.handle(
        _modelReasoningEffortMeta,
        modelReasoningEffort.isAcceptableOrUnknown(
          data['model_reasoning_effort']!,
          _modelReasoningEffortMeta,
        ),
      );
    }
    if (data.containsKey('personality')) {
      context.handle(
        _personalityMeta,
        personality.isAcceptableOrUnknown(
          data['personality']!,
          _personalityMeta,
        ),
      );
    }
    if (data.containsKey('oauth_data')) {
      context.handle(
        _oauthDataMeta,
        oauthData.isAcceptableOrUnknown(data['oauth_data']!, _oauthDataMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProviderProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      editorType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}editor_type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      apiToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_token'],
      ),
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      maxOutputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}max_output_tokens'],
      ),
      maxThinkingTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}max_thinking_tokens'],
      ),
      website: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}website'],
      ),
      modelReasoningEffort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_reasoning_effort'],
      ),
      personality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}personality'],
      ),
      oauthData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}oauth_data'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProviderProfilesTable createAlias(String alias) {
    return $ProviderProfilesTable(attachedDatabase, alias);
  }
}

class ProviderProfile extends DataClass implements Insertable<ProviderProfile> {
  final String id;
  final String editorType;
  final String name;
  final String? description;
  final bool isActive;
  final String? apiToken;
  final String? baseUrl;
  final String? model;
  final String? maxOutputTokens;
  final String? maxThinkingTokens;
  final String? website;
  final String? modelReasoningEffort;
  final String? personality;
  final String? oauthData;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ProviderProfile({
    required this.id,
    required this.editorType,
    required this.name,
    this.description,
    required this.isActive,
    this.apiToken,
    this.baseUrl,
    this.model,
    this.maxOutputTokens,
    this.maxThinkingTokens,
    this.website,
    this.modelReasoningEffort,
    this.personality,
    this.oauthData,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['editor_type'] = Variable<String>(editorType);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || apiToken != null) {
      map['api_token'] = Variable<String>(apiToken);
    }
    if (!nullToAbsent || baseUrl != null) {
      map['base_url'] = Variable<String>(baseUrl);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || maxOutputTokens != null) {
      map['max_output_tokens'] = Variable<String>(maxOutputTokens);
    }
    if (!nullToAbsent || maxThinkingTokens != null) {
      map['max_thinking_tokens'] = Variable<String>(maxThinkingTokens);
    }
    if (!nullToAbsent || website != null) {
      map['website'] = Variable<String>(website);
    }
    if (!nullToAbsent || modelReasoningEffort != null) {
      map['model_reasoning_effort'] = Variable<String>(modelReasoningEffort);
    }
    if (!nullToAbsent || personality != null) {
      map['personality'] = Variable<String>(personality);
    }
    if (!nullToAbsent || oauthData != null) {
      map['oauth_data'] = Variable<String>(oauthData);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProviderProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProviderProfilesCompanion(
      id: Value(id),
      editorType: Value(editorType),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isActive: Value(isActive),
      apiToken: apiToken == null && nullToAbsent
          ? const Value.absent()
          : Value(apiToken),
      baseUrl: baseUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(baseUrl),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      maxOutputTokens: maxOutputTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(maxOutputTokens),
      maxThinkingTokens: maxThinkingTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(maxThinkingTokens),
      website: website == null && nullToAbsent
          ? const Value.absent()
          : Value(website),
      modelReasoningEffort: modelReasoningEffort == null && nullToAbsent
          ? const Value.absent()
          : Value(modelReasoningEffort),
      personality: personality == null && nullToAbsent
          ? const Value.absent()
          : Value(personality),
      oauthData: oauthData == null && nullToAbsent
          ? const Value.absent()
          : Value(oauthData),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProviderProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderProfile(
      id: serializer.fromJson<String>(json['id']),
      editorType: serializer.fromJson<String>(json['editorType']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      apiToken: serializer.fromJson<String?>(json['apiToken']),
      baseUrl: serializer.fromJson<String?>(json['baseUrl']),
      model: serializer.fromJson<String?>(json['model']),
      maxOutputTokens: serializer.fromJson<String?>(json['maxOutputTokens']),
      maxThinkingTokens: serializer.fromJson<String?>(
        json['maxThinkingTokens'],
      ),
      website: serializer.fromJson<String?>(json['website']),
      modelReasoningEffort: serializer.fromJson<String?>(
        json['modelReasoningEffort'],
      ),
      personality: serializer.fromJson<String?>(json['personality']),
      oauthData: serializer.fromJson<String?>(json['oauthData']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'editorType': serializer.toJson<String>(editorType),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'isActive': serializer.toJson<bool>(isActive),
      'apiToken': serializer.toJson<String?>(apiToken),
      'baseUrl': serializer.toJson<String?>(baseUrl),
      'model': serializer.toJson<String?>(model),
      'maxOutputTokens': serializer.toJson<String?>(maxOutputTokens),
      'maxThinkingTokens': serializer.toJson<String?>(maxThinkingTokens),
      'website': serializer.toJson<String?>(website),
      'modelReasoningEffort': serializer.toJson<String?>(modelReasoningEffort),
      'personality': serializer.toJson<String?>(personality),
      'oauthData': serializer.toJson<String?>(oauthData),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProviderProfile copyWith({
    String? id,
    String? editorType,
    String? name,
    Value<String?> description = const Value.absent(),
    bool? isActive,
    Value<String?> apiToken = const Value.absent(),
    Value<String?> baseUrl = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<String?> maxOutputTokens = const Value.absent(),
    Value<String?> maxThinkingTokens = const Value.absent(),
    Value<String?> website = const Value.absent(),
    Value<String?> modelReasoningEffort = const Value.absent(),
    Value<String?> personality = const Value.absent(),
    Value<String?> oauthData = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProviderProfile(
    id: id ?? this.id,
    editorType: editorType ?? this.editorType,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    isActive: isActive ?? this.isActive,
    apiToken: apiToken.present ? apiToken.value : this.apiToken,
    baseUrl: baseUrl.present ? baseUrl.value : this.baseUrl,
    model: model.present ? model.value : this.model,
    maxOutputTokens: maxOutputTokens.present
        ? maxOutputTokens.value
        : this.maxOutputTokens,
    maxThinkingTokens: maxThinkingTokens.present
        ? maxThinkingTokens.value
        : this.maxThinkingTokens,
    website: website.present ? website.value : this.website,
    modelReasoningEffort: modelReasoningEffort.present
        ? modelReasoningEffort.value
        : this.modelReasoningEffort,
    personality: personality.present ? personality.value : this.personality,
    oauthData: oauthData.present ? oauthData.value : this.oauthData,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProviderProfile copyWithCompanion(ProviderProfilesCompanion data) {
    return ProviderProfile(
      id: data.id.present ? data.id.value : this.id,
      editorType: data.editorType.present
          ? data.editorType.value
          : this.editorType,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      apiToken: data.apiToken.present ? data.apiToken.value : this.apiToken,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      model: data.model.present ? data.model.value : this.model,
      maxOutputTokens: data.maxOutputTokens.present
          ? data.maxOutputTokens.value
          : this.maxOutputTokens,
      maxThinkingTokens: data.maxThinkingTokens.present
          ? data.maxThinkingTokens.value
          : this.maxThinkingTokens,
      website: data.website.present ? data.website.value : this.website,
      modelReasoningEffort: data.modelReasoningEffort.present
          ? data.modelReasoningEffort.value
          : this.modelReasoningEffort,
      personality: data.personality.present
          ? data.personality.value
          : this.personality,
      oauthData: data.oauthData.present ? data.oauthData.value : this.oauthData,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderProfile(')
          ..write('id: $id, ')
          ..write('editorType: $editorType, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('apiToken: $apiToken, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('maxOutputTokens: $maxOutputTokens, ')
          ..write('maxThinkingTokens: $maxThinkingTokens, ')
          ..write('website: $website, ')
          ..write('modelReasoningEffort: $modelReasoningEffort, ')
          ..write('personality: $personality, ')
          ..write('oauthData: $oauthData, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    editorType,
    name,
    description,
    isActive,
    apiToken,
    baseUrl,
    model,
    maxOutputTokens,
    maxThinkingTokens,
    website,
    modelReasoningEffort,
    personality,
    oauthData,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderProfile &&
          other.id == this.id &&
          other.editorType == this.editorType &&
          other.name == this.name &&
          other.description == this.description &&
          other.isActive == this.isActive &&
          other.apiToken == this.apiToken &&
          other.baseUrl == this.baseUrl &&
          other.model == this.model &&
          other.maxOutputTokens == this.maxOutputTokens &&
          other.maxThinkingTokens == this.maxThinkingTokens &&
          other.website == this.website &&
          other.modelReasoningEffort == this.modelReasoningEffort &&
          other.personality == this.personality &&
          other.oauthData == this.oauthData &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProviderProfilesCompanion extends UpdateCompanion<ProviderProfile> {
  final Value<String> id;
  final Value<String> editorType;
  final Value<String> name;
  final Value<String?> description;
  final Value<bool> isActive;
  final Value<String?> apiToken;
  final Value<String?> baseUrl;
  final Value<String?> model;
  final Value<String?> maxOutputTokens;
  final Value<String?> maxThinkingTokens;
  final Value<String?> website;
  final Value<String?> modelReasoningEffort;
  final Value<String?> personality;
  final Value<String?> oauthData;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProviderProfilesCompanion({
    this.id = const Value.absent(),
    this.editorType = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.apiToken = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.maxOutputTokens = const Value.absent(),
    this.maxThinkingTokens = const Value.absent(),
    this.website = const Value.absent(),
    this.modelReasoningEffort = const Value.absent(),
    this.personality = const Value.absent(),
    this.oauthData = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderProfilesCompanion.insert({
    required String id,
    required String editorType,
    required String name,
    this.description = const Value.absent(),
    this.isActive = const Value.absent(),
    this.apiToken = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.maxOutputTokens = const Value.absent(),
    this.maxThinkingTokens = const Value.absent(),
    this.website = const Value.absent(),
    this.modelReasoningEffort = const Value.absent(),
    this.personality = const Value.absent(),
    this.oauthData = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       editorType = Value(editorType),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ProviderProfile> custom({
    Expression<String>? id,
    Expression<String>? editorType,
    Expression<String>? name,
    Expression<String>? description,
    Expression<bool>? isActive,
    Expression<String>? apiToken,
    Expression<String>? baseUrl,
    Expression<String>? model,
    Expression<String>? maxOutputTokens,
    Expression<String>? maxThinkingTokens,
    Expression<String>? website,
    Expression<String>? modelReasoningEffort,
    Expression<String>? personality,
    Expression<String>? oauthData,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (editorType != null) 'editor_type': editorType,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (isActive != null) 'is_active': isActive,
      if (apiToken != null) 'api_token': apiToken,
      if (baseUrl != null) 'base_url': baseUrl,
      if (model != null) 'model': model,
      if (maxOutputTokens != null) 'max_output_tokens': maxOutputTokens,
      if (maxThinkingTokens != null) 'max_thinking_tokens': maxThinkingTokens,
      if (website != null) 'website': website,
      if (modelReasoningEffort != null)
        'model_reasoning_effort': modelReasoningEffort,
      if (personality != null) 'personality': personality,
      if (oauthData != null) 'oauth_data': oauthData,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? editorType,
    Value<String>? name,
    Value<String?>? description,
    Value<bool>? isActive,
    Value<String?>? apiToken,
    Value<String?>? baseUrl,
    Value<String?>? model,
    Value<String?>? maxOutputTokens,
    Value<String?>? maxThinkingTokens,
    Value<String?>? website,
    Value<String?>? modelReasoningEffort,
    Value<String?>? personality,
    Value<String?>? oauthData,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProviderProfilesCompanion(
      id: id ?? this.id,
      editorType: editorType ?? this.editorType,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      apiToken: apiToken ?? this.apiToken,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      maxThinkingTokens: maxThinkingTokens ?? this.maxThinkingTokens,
      website: website ?? this.website,
      modelReasoningEffort: modelReasoningEffort ?? this.modelReasoningEffort,
      personality: personality ?? this.personality,
      oauthData: oauthData ?? this.oauthData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (editorType.present) {
      map['editor_type'] = Variable<String>(editorType.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (apiToken.present) {
      map['api_token'] = Variable<String>(apiToken.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (maxOutputTokens.present) {
      map['max_output_tokens'] = Variable<String>(maxOutputTokens.value);
    }
    if (maxThinkingTokens.present) {
      map['max_thinking_tokens'] = Variable<String>(maxThinkingTokens.value);
    }
    if (website.present) {
      map['website'] = Variable<String>(website.value);
    }
    if (modelReasoningEffort.present) {
      map['model_reasoning_effort'] = Variable<String>(
        modelReasoningEffort.value,
      );
    }
    if (personality.present) {
      map['personality'] = Variable<String>(personality.value);
    }
    if (oauthData.present) {
      map['oauth_data'] = Variable<String>(oauthData.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderProfilesCompanion(')
          ..write('id: $id, ')
          ..write('editorType: $editorType, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isActive: $isActive, ')
          ..write('apiToken: $apiToken, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('maxOutputTokens: $maxOutputTokens, ')
          ..write('maxThinkingTokens: $maxThinkingTokens, ')
          ..write('website: $website, ')
          ..write('modelReasoningEffort: $modelReasoningEffort, ')
          ..write('personality: $personality, ')
          ..write('oauthData: $oauthData, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProviderProfilesTable providerProfiles = $ProviderProfilesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [providerProfiles];
}

typedef $$ProviderProfilesTableCreateCompanionBuilder =
    ProviderProfilesCompanion Function({
      required String id,
      required String editorType,
      required String name,
      Value<String?> description,
      Value<bool> isActive,
      Value<String?> apiToken,
      Value<String?> baseUrl,
      Value<String?> model,
      Value<String?> maxOutputTokens,
      Value<String?> maxThinkingTokens,
      Value<String?> website,
      Value<String?> modelReasoningEffort,
      Value<String?> personality,
      Value<String?> oauthData,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProviderProfilesTableUpdateCompanionBuilder =
    ProviderProfilesCompanion Function({
      Value<String> id,
      Value<String> editorType,
      Value<String> name,
      Value<String?> description,
      Value<bool> isActive,
      Value<String?> apiToken,
      Value<String?> baseUrl,
      Value<String?> model,
      Value<String?> maxOutputTokens,
      Value<String?> maxThinkingTokens,
      Value<String?> website,
      Value<String?> modelReasoningEffort,
      Value<String?> personality,
      Value<String?> oauthData,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ProviderProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProviderProfilesTable> {
  $$ProviderProfilesTableFilterComposer({
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

  ColumnFilters<String> get editorType => $composableBuilder(
    column: $table.editorType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiToken => $composableBuilder(
    column: $table.apiToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get maxOutputTokens => $composableBuilder(
    column: $table.maxOutputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get maxThinkingTokens => $composableBuilder(
    column: $table.maxThinkingTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get website => $composableBuilder(
    column: $table.website,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelReasoningEffort => $composableBuilder(
    column: $table.modelReasoningEffort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personality => $composableBuilder(
    column: $table.personality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oauthData => $composableBuilder(
    column: $table.oauthData,
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
}

class $$ProviderProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProviderProfilesTable> {
  $$ProviderProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get editorType => $composableBuilder(
    column: $table.editorType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiToken => $composableBuilder(
    column: $table.apiToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get maxOutputTokens => $composableBuilder(
    column: $table.maxOutputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get maxThinkingTokens => $composableBuilder(
    column: $table.maxThinkingTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get website => $composableBuilder(
    column: $table.website,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelReasoningEffort => $composableBuilder(
    column: $table.modelReasoningEffort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personality => $composableBuilder(
    column: $table.personality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oauthData => $composableBuilder(
    column: $table.oauthData,
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
}

class $$ProviderProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProviderProfilesTable> {
  $$ProviderProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get editorType => $composableBuilder(
    column: $table.editorType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get apiToken =>
      $composableBuilder(column: $table.apiToken, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get maxOutputTokens => $composableBuilder(
    column: $table.maxOutputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<String> get maxThinkingTokens => $composableBuilder(
    column: $table.maxThinkingTokens,
    builder: (column) => column,
  );

  GeneratedColumn<String> get website =>
      $composableBuilder(column: $table.website, builder: (column) => column);

  GeneratedColumn<String> get modelReasoningEffort => $composableBuilder(
    column: $table.modelReasoningEffort,
    builder: (column) => column,
  );

  GeneratedColumn<String> get personality => $composableBuilder(
    column: $table.personality,
    builder: (column) => column,
  );

  GeneratedColumn<String> get oauthData =>
      $composableBuilder(column: $table.oauthData, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProviderProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProviderProfilesTable,
          ProviderProfile,
          $$ProviderProfilesTableFilterComposer,
          $$ProviderProfilesTableOrderingComposer,
          $$ProviderProfilesTableAnnotationComposer,
          $$ProviderProfilesTableCreateCompanionBuilder,
          $$ProviderProfilesTableUpdateCompanionBuilder,
          (
            ProviderProfile,
            BaseReferences<
              _$AppDatabase,
              $ProviderProfilesTable,
              ProviderProfile
            >,
          ),
          ProviderProfile,
          PrefetchHooks Function()
        > {
  $$ProviderProfilesTableTableManager(
    _$AppDatabase db,
    $ProviderProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> editorType = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> apiToken = const Value.absent(),
                Value<String?> baseUrl = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> maxOutputTokens = const Value.absent(),
                Value<String?> maxThinkingTokens = const Value.absent(),
                Value<String?> website = const Value.absent(),
                Value<String?> modelReasoningEffort = const Value.absent(),
                Value<String?> personality = const Value.absent(),
                Value<String?> oauthData = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderProfilesCompanion(
                id: id,
                editorType: editorType,
                name: name,
                description: description,
                isActive: isActive,
                apiToken: apiToken,
                baseUrl: baseUrl,
                model: model,
                maxOutputTokens: maxOutputTokens,
                maxThinkingTokens: maxThinkingTokens,
                website: website,
                modelReasoningEffort: modelReasoningEffort,
                personality: personality,
                oauthData: oauthData,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String editorType,
                required String name,
                Value<String?> description = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> apiToken = const Value.absent(),
                Value<String?> baseUrl = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> maxOutputTokens = const Value.absent(),
                Value<String?> maxThinkingTokens = const Value.absent(),
                Value<String?> website = const Value.absent(),
                Value<String?> modelReasoningEffort = const Value.absent(),
                Value<String?> personality = const Value.absent(),
                Value<String?> oauthData = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProviderProfilesCompanion.insert(
                id: id,
                editorType: editorType,
                name: name,
                description: description,
                isActive: isActive,
                apiToken: apiToken,
                baseUrl: baseUrl,
                model: model,
                maxOutputTokens: maxOutputTokens,
                maxThinkingTokens: maxThinkingTokens,
                website: website,
                modelReasoningEffort: modelReasoningEffort,
                personality: personality,
                oauthData: oauthData,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProviderProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProviderProfilesTable,
      ProviderProfile,
      $$ProviderProfilesTableFilterComposer,
      $$ProviderProfilesTableOrderingComposer,
      $$ProviderProfilesTableAnnotationComposer,
      $$ProviderProfilesTableCreateCompanionBuilder,
      $$ProviderProfilesTableUpdateCompanionBuilder,
      (
        ProviderProfile,
        BaseReferences<_$AppDatabase, $ProviderProfilesTable, ProviderProfile>,
      ),
      ProviderProfile,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProviderProfilesTableTableManager get providerProfiles =>
      $$ProviderProfilesTableTableManager(_db, _db.providerProfiles);
}
