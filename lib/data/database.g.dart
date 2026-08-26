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
  static const VerificationMeta _vscodeModelMeta = const VerificationMeta(
    'vscodeModel',
  );
  @override
  late final GeneratedColumn<String> vscodeModel = GeneratedColumn<String>(
    'vscode_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vscodeModelModeMeta = const VerificationMeta(
    'vscodeModelMode',
  );
  @override
  late final GeneratedColumn<String> vscodeModelMode = GeneratedColumn<String>(
    'vscode_model_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultHaikuModelMeta = const VerificationMeta(
    'defaultHaikuModel',
  );
  @override
  late final GeneratedColumn<String> defaultHaikuModel =
      GeneratedColumn<String>(
        'default_haiku_model',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _defaultSonnetModelMeta =
      const VerificationMeta('defaultSonnetModel');
  @override
  late final GeneratedColumn<String> defaultSonnetModel =
      GeneratedColumn<String>(
        'default_sonnet_model',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _defaultOpusModelMeta = const VerificationMeta(
    'defaultOpusModel',
  );
  @override
  late final GeneratedColumn<String> defaultOpusModel = GeneratedColumn<String>(
    'default_opus_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _configContentMeta = const VerificationMeta(
    'configContent',
  );
  @override
  late final GeneratedColumn<String> configContent = GeneratedColumn<String>(
    'config_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOfficialProviderMeta =
      const VerificationMeta('isOfficialProvider');
  @override
  late final GeneratedColumn<bool> isOfficialProvider = GeneratedColumn<bool>(
    'is_official_provider',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_official_provider" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    vscodeModel,
    vscodeModelMode,
    defaultHaikuModel,
    defaultSonnetModel,
    defaultOpusModel,
    configContent,
    isOfficialProvider,
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
    if (data.containsKey('vscode_model')) {
      context.handle(
        _vscodeModelMeta,
        vscodeModel.isAcceptableOrUnknown(
          data['vscode_model']!,
          _vscodeModelMeta,
        ),
      );
    }
    if (data.containsKey('vscode_model_mode')) {
      context.handle(
        _vscodeModelModeMeta,
        vscodeModelMode.isAcceptableOrUnknown(
          data['vscode_model_mode']!,
          _vscodeModelModeMeta,
        ),
      );
    }
    if (data.containsKey('default_haiku_model')) {
      context.handle(
        _defaultHaikuModelMeta,
        defaultHaikuModel.isAcceptableOrUnknown(
          data['default_haiku_model']!,
          _defaultHaikuModelMeta,
        ),
      );
    }
    if (data.containsKey('default_sonnet_model')) {
      context.handle(
        _defaultSonnetModelMeta,
        defaultSonnetModel.isAcceptableOrUnknown(
          data['default_sonnet_model']!,
          _defaultSonnetModelMeta,
        ),
      );
    }
    if (data.containsKey('default_opus_model')) {
      context.handle(
        _defaultOpusModelMeta,
        defaultOpusModel.isAcceptableOrUnknown(
          data['default_opus_model']!,
          _defaultOpusModelMeta,
        ),
      );
    }
    if (data.containsKey('config_content')) {
      context.handle(
        _configContentMeta,
        configContent.isAcceptableOrUnknown(
          data['config_content']!,
          _configContentMeta,
        ),
      );
    }
    if (data.containsKey('is_official_provider')) {
      context.handle(
        _isOfficialProviderMeta,
        isOfficialProvider.isAcceptableOrUnknown(
          data['is_official_provider']!,
          _isOfficialProviderMeta,
        ),
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
      vscodeModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vscode_model'],
      ),
      vscodeModelMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vscode_model_mode'],
      ),
      defaultHaikuModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_haiku_model'],
      ),
      defaultSonnetModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_sonnet_model'],
      ),
      defaultOpusModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_opus_model'],
      ),
      configContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_content'],
      ),
      isOfficialProvider: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_official_provider'],
      )!,
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
  final String? vscodeModel;

  /// VSCode 插件模型写入位置：'legacy'（VSCode settings.json -> claudeCode.selectedModel）
  /// 或 'modern'（~/.claude/settings.json -> model）。null 视为 legacy。
  final String? vscodeModelMode;
  final String? defaultHaikuModel;
  final String? defaultSonnetModel;
  final String? defaultOpusModel;
  final String? configContent;

  /// 是否为官方供应商（通过 OAuth 登录，不需要 apiToken/baseUrl）
  final bool isOfficialProvider;
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
    this.vscodeModel,
    this.vscodeModelMode,
    this.defaultHaikuModel,
    this.defaultSonnetModel,
    this.defaultOpusModel,
    this.configContent,
    required this.isOfficialProvider,
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
    if (!nullToAbsent || vscodeModel != null) {
      map['vscode_model'] = Variable<String>(vscodeModel);
    }
    if (!nullToAbsent || vscodeModelMode != null) {
      map['vscode_model_mode'] = Variable<String>(vscodeModelMode);
    }
    if (!nullToAbsent || defaultHaikuModel != null) {
      map['default_haiku_model'] = Variable<String>(defaultHaikuModel);
    }
    if (!nullToAbsent || defaultSonnetModel != null) {
      map['default_sonnet_model'] = Variable<String>(defaultSonnetModel);
    }
    if (!nullToAbsent || defaultOpusModel != null) {
      map['default_opus_model'] = Variable<String>(defaultOpusModel);
    }
    if (!nullToAbsent || configContent != null) {
      map['config_content'] = Variable<String>(configContent);
    }
    map['is_official_provider'] = Variable<bool>(isOfficialProvider);
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
      vscodeModel: vscodeModel == null && nullToAbsent
          ? const Value.absent()
          : Value(vscodeModel),
      vscodeModelMode: vscodeModelMode == null && nullToAbsent
          ? const Value.absent()
          : Value(vscodeModelMode),
      defaultHaikuModel: defaultHaikuModel == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultHaikuModel),
      defaultSonnetModel: defaultSonnetModel == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultSonnetModel),
      defaultOpusModel: defaultOpusModel == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultOpusModel),
      configContent: configContent == null && nullToAbsent
          ? const Value.absent()
          : Value(configContent),
      isOfficialProvider: Value(isOfficialProvider),
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
      vscodeModel: serializer.fromJson<String?>(json['vscodeModel']),
      vscodeModelMode: serializer.fromJson<String?>(json['vscodeModelMode']),
      defaultHaikuModel: serializer.fromJson<String?>(
        json['defaultHaikuModel'],
      ),
      defaultSonnetModel: serializer.fromJson<String?>(
        json['defaultSonnetModel'],
      ),
      defaultOpusModel: serializer.fromJson<String?>(json['defaultOpusModel']),
      configContent: serializer.fromJson<String?>(json['configContent']),
      isOfficialProvider: serializer.fromJson<bool>(json['isOfficialProvider']),
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
      'vscodeModel': serializer.toJson<String?>(vscodeModel),
      'vscodeModelMode': serializer.toJson<String?>(vscodeModelMode),
      'defaultHaikuModel': serializer.toJson<String?>(defaultHaikuModel),
      'defaultSonnetModel': serializer.toJson<String?>(defaultSonnetModel),
      'defaultOpusModel': serializer.toJson<String?>(defaultOpusModel),
      'configContent': serializer.toJson<String?>(configContent),
      'isOfficialProvider': serializer.toJson<bool>(isOfficialProvider),
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
    Value<String?> vscodeModel = const Value.absent(),
    Value<String?> vscodeModelMode = const Value.absent(),
    Value<String?> defaultHaikuModel = const Value.absent(),
    Value<String?> defaultSonnetModel = const Value.absent(),
    Value<String?> defaultOpusModel = const Value.absent(),
    Value<String?> configContent = const Value.absent(),
    bool? isOfficialProvider,
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
    vscodeModel: vscodeModel.present ? vscodeModel.value : this.vscodeModel,
    vscodeModelMode: vscodeModelMode.present
        ? vscodeModelMode.value
        : this.vscodeModelMode,
    defaultHaikuModel: defaultHaikuModel.present
        ? defaultHaikuModel.value
        : this.defaultHaikuModel,
    defaultSonnetModel: defaultSonnetModel.present
        ? defaultSonnetModel.value
        : this.defaultSonnetModel,
    defaultOpusModel: defaultOpusModel.present
        ? defaultOpusModel.value
        : this.defaultOpusModel,
    configContent: configContent.present
        ? configContent.value
        : this.configContent,
    isOfficialProvider: isOfficialProvider ?? this.isOfficialProvider,
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
      vscodeModel: data.vscodeModel.present
          ? data.vscodeModel.value
          : this.vscodeModel,
      vscodeModelMode: data.vscodeModelMode.present
          ? data.vscodeModelMode.value
          : this.vscodeModelMode,
      defaultHaikuModel: data.defaultHaikuModel.present
          ? data.defaultHaikuModel.value
          : this.defaultHaikuModel,
      defaultSonnetModel: data.defaultSonnetModel.present
          ? data.defaultSonnetModel.value
          : this.defaultSonnetModel,
      defaultOpusModel: data.defaultOpusModel.present
          ? data.defaultOpusModel.value
          : this.defaultOpusModel,
      configContent: data.configContent.present
          ? data.configContent.value
          : this.configContent,
      isOfficialProvider: data.isOfficialProvider.present
          ? data.isOfficialProvider.value
          : this.isOfficialProvider,
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
          ..write('vscodeModel: $vscodeModel, ')
          ..write('vscodeModelMode: $vscodeModelMode, ')
          ..write('defaultHaikuModel: $defaultHaikuModel, ')
          ..write('defaultSonnetModel: $defaultSonnetModel, ')
          ..write('defaultOpusModel: $defaultOpusModel, ')
          ..write('configContent: $configContent, ')
          ..write('isOfficialProvider: $isOfficialProvider, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
    vscodeModel,
    vscodeModelMode,
    defaultHaikuModel,
    defaultSonnetModel,
    defaultOpusModel,
    configContent,
    isOfficialProvider,
    createdAt,
    updatedAt,
  ]);
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
          other.vscodeModel == this.vscodeModel &&
          other.vscodeModelMode == this.vscodeModelMode &&
          other.defaultHaikuModel == this.defaultHaikuModel &&
          other.defaultSonnetModel == this.defaultSonnetModel &&
          other.defaultOpusModel == this.defaultOpusModel &&
          other.configContent == this.configContent &&
          other.isOfficialProvider == this.isOfficialProvider &&
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
  final Value<String?> vscodeModel;
  final Value<String?> vscodeModelMode;
  final Value<String?> defaultHaikuModel;
  final Value<String?> defaultSonnetModel;
  final Value<String?> defaultOpusModel;
  final Value<String?> configContent;
  final Value<bool> isOfficialProvider;
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
    this.vscodeModel = const Value.absent(),
    this.vscodeModelMode = const Value.absent(),
    this.defaultHaikuModel = const Value.absent(),
    this.defaultSonnetModel = const Value.absent(),
    this.defaultOpusModel = const Value.absent(),
    this.configContent = const Value.absent(),
    this.isOfficialProvider = const Value.absent(),
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
    this.vscodeModel = const Value.absent(),
    this.vscodeModelMode = const Value.absent(),
    this.defaultHaikuModel = const Value.absent(),
    this.defaultSonnetModel = const Value.absent(),
    this.defaultOpusModel = const Value.absent(),
    this.configContent = const Value.absent(),
    this.isOfficialProvider = const Value.absent(),
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
    Expression<String>? vscodeModel,
    Expression<String>? vscodeModelMode,
    Expression<String>? defaultHaikuModel,
    Expression<String>? defaultSonnetModel,
    Expression<String>? defaultOpusModel,
    Expression<String>? configContent,
    Expression<bool>? isOfficialProvider,
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
      if (vscodeModel != null) 'vscode_model': vscodeModel,
      if (vscodeModelMode != null) 'vscode_model_mode': vscodeModelMode,
      if (defaultHaikuModel != null) 'default_haiku_model': defaultHaikuModel,
      if (defaultSonnetModel != null)
        'default_sonnet_model': defaultSonnetModel,
      if (defaultOpusModel != null) 'default_opus_model': defaultOpusModel,
      if (configContent != null) 'config_content': configContent,
      if (isOfficialProvider != null)
        'is_official_provider': isOfficialProvider,
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
    Value<String?>? vscodeModel,
    Value<String?>? vscodeModelMode,
    Value<String?>? defaultHaikuModel,
    Value<String?>? defaultSonnetModel,
    Value<String?>? defaultOpusModel,
    Value<String?>? configContent,
    Value<bool>? isOfficialProvider,
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
      vscodeModel: vscodeModel ?? this.vscodeModel,
      vscodeModelMode: vscodeModelMode ?? this.vscodeModelMode,
      defaultHaikuModel: defaultHaikuModel ?? this.defaultHaikuModel,
      defaultSonnetModel: defaultSonnetModel ?? this.defaultSonnetModel,
      defaultOpusModel: defaultOpusModel ?? this.defaultOpusModel,
      configContent: configContent ?? this.configContent,
      isOfficialProvider: isOfficialProvider ?? this.isOfficialProvider,
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
    if (vscodeModel.present) {
      map['vscode_model'] = Variable<String>(vscodeModel.value);
    }
    if (vscodeModelMode.present) {
      map['vscode_model_mode'] = Variable<String>(vscodeModelMode.value);
    }
    if (defaultHaikuModel.present) {
      map['default_haiku_model'] = Variable<String>(defaultHaikuModel.value);
    }
    if (defaultSonnetModel.present) {
      map['default_sonnet_model'] = Variable<String>(defaultSonnetModel.value);
    }
    if (defaultOpusModel.present) {
      map['default_opus_model'] = Variable<String>(defaultOpusModel.value);
    }
    if (configContent.present) {
      map['config_content'] = Variable<String>(configContent.value);
    }
    if (isOfficialProvider.present) {
      map['is_official_provider'] = Variable<bool>(isOfficialProvider.value);
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
          ..write('vscodeModel: $vscodeModel, ')
          ..write('vscodeModelMode: $vscodeModelMode, ')
          ..write('defaultHaikuModel: $defaultHaikuModel, ')
          ..write('defaultSonnetModel: $defaultSonnetModel, ')
          ..write('defaultOpusModel: $defaultOpusModel, ')
          ..write('configContent: $configContent, ')
          ..write('isOfficialProvider: $isOfficialProvider, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CursorAccountsTable extends CursorAccounts
    with TableInfo<$CursorAccountsTable, CursorAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CursorAccountsTable(this.attachedDatabase, [this._alias]);
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accessTokenMeta = const VerificationMeta(
    'accessToken',
  );
  @override
  late final GeneratedColumn<String> accessToken = GeneratedColumn<String>(
    'access_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _refreshTokenMeta = const VerificationMeta(
    'refreshToken',
  );
  @override
  late final GeneratedColumn<String> refreshToken = GeneratedColumn<String>(
    'refresh_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _membershipTypeMeta = const VerificationMeta(
    'membershipType',
  );
  @override
  late final GeneratedColumn<String> membershipType = GeneratedColumn<String>(
    'membership_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _signUpTypeMeta = const VerificationMeta(
    'signUpType',
  );
  @override
  late final GeneratedColumn<String> signUpType = GeneratedColumn<String>(
    'sign_up_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _machineIdMeta = const VerificationMeta(
    'machineId',
  );
  @override
  late final GeneratedColumn<String> machineId = GeneratedColumn<String>(
    'machine_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _macMachineIdMeta = const VerificationMeta(
    'macMachineId',
  );
  @override
  late final GeneratedColumn<String> macMachineId = GeneratedColumn<String>(
    'mac_machine_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _devDeviceIdMeta = const VerificationMeta(
    'devDeviceId',
  );
  @override
  late final GeneratedColumn<String> devDeviceId = GeneratedColumn<String>(
    'dev_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sqmIdMeta = const VerificationMeta('sqmId');
  @override
  late final GeneratedColumn<String> sqmId = GeneratedColumn<String>(
    'sqm_id',
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
    name,
    email,
    accessToken,
    refreshToken,
    membershipType,
    signUpType,
    machineId,
    macMachineId,
    devDeviceId,
    sqmId,
    isActive,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cursor_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<CursorAccount> instance, {
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
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('access_token')) {
      context.handle(
        _accessTokenMeta,
        accessToken.isAcceptableOrUnknown(
          data['access_token']!,
          _accessTokenMeta,
        ),
      );
    }
    if (data.containsKey('refresh_token')) {
      context.handle(
        _refreshTokenMeta,
        refreshToken.isAcceptableOrUnknown(
          data['refresh_token']!,
          _refreshTokenMeta,
        ),
      );
    }
    if (data.containsKey('membership_type')) {
      context.handle(
        _membershipTypeMeta,
        membershipType.isAcceptableOrUnknown(
          data['membership_type']!,
          _membershipTypeMeta,
        ),
      );
    }
    if (data.containsKey('sign_up_type')) {
      context.handle(
        _signUpTypeMeta,
        signUpType.isAcceptableOrUnknown(
          data['sign_up_type']!,
          _signUpTypeMeta,
        ),
      );
    }
    if (data.containsKey('machine_id')) {
      context.handle(
        _machineIdMeta,
        machineId.isAcceptableOrUnknown(data['machine_id']!, _machineIdMeta),
      );
    }
    if (data.containsKey('mac_machine_id')) {
      context.handle(
        _macMachineIdMeta,
        macMachineId.isAcceptableOrUnknown(
          data['mac_machine_id']!,
          _macMachineIdMeta,
        ),
      );
    }
    if (data.containsKey('dev_device_id')) {
      context.handle(
        _devDeviceIdMeta,
        devDeviceId.isAcceptableOrUnknown(
          data['dev_device_id']!,
          _devDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('sqm_id')) {
      context.handle(
        _sqmIdMeta,
        sqmId.isAcceptableOrUnknown(data['sqm_id']!, _sqmIdMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
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
  CursorAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CursorAccount(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      accessToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}access_token'],
      ),
      refreshToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}refresh_token'],
      ),
      membershipType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}membership_type'],
      ),
      signUpType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sign_up_type'],
      ),
      machineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}machine_id'],
      ),
      macMachineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mac_machine_id'],
      ),
      devDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dev_device_id'],
      ),
      sqmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sqm_id'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
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
  $CursorAccountsTable createAlias(String alias) {
    return $CursorAccountsTable(attachedDatabase, alias);
  }
}

class CursorAccount extends DataClass implements Insertable<CursorAccount> {
  final String id;
  final String name;
  final String? email;
  final String? accessToken;
  final String? refreshToken;
  final String? membershipType;
  final String? signUpType;
  final String? machineId;
  final String? macMachineId;
  final String? devDeviceId;
  final String? sqmId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CursorAccount({
    required this.id,
    required this.name,
    this.email,
    this.accessToken,
    this.refreshToken,
    this.membershipType,
    this.signUpType,
    this.machineId,
    this.macMachineId,
    this.devDeviceId,
    this.sqmId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || accessToken != null) {
      map['access_token'] = Variable<String>(accessToken);
    }
    if (!nullToAbsent || refreshToken != null) {
      map['refresh_token'] = Variable<String>(refreshToken);
    }
    if (!nullToAbsent || membershipType != null) {
      map['membership_type'] = Variable<String>(membershipType);
    }
    if (!nullToAbsent || signUpType != null) {
      map['sign_up_type'] = Variable<String>(signUpType);
    }
    if (!nullToAbsent || machineId != null) {
      map['machine_id'] = Variable<String>(machineId);
    }
    if (!nullToAbsent || macMachineId != null) {
      map['mac_machine_id'] = Variable<String>(macMachineId);
    }
    if (!nullToAbsent || devDeviceId != null) {
      map['dev_device_id'] = Variable<String>(devDeviceId);
    }
    if (!nullToAbsent || sqmId != null) {
      map['sqm_id'] = Variable<String>(sqmId);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CursorAccountsCompanion toCompanion(bool nullToAbsent) {
    return CursorAccountsCompanion(
      id: Value(id),
      name: Value(name),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      accessToken: accessToken == null && nullToAbsent
          ? const Value.absent()
          : Value(accessToken),
      refreshToken: refreshToken == null && nullToAbsent
          ? const Value.absent()
          : Value(refreshToken),
      membershipType: membershipType == null && nullToAbsent
          ? const Value.absent()
          : Value(membershipType),
      signUpType: signUpType == null && nullToAbsent
          ? const Value.absent()
          : Value(signUpType),
      machineId: machineId == null && nullToAbsent
          ? const Value.absent()
          : Value(machineId),
      macMachineId: macMachineId == null && nullToAbsent
          ? const Value.absent()
          : Value(macMachineId),
      devDeviceId: devDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(devDeviceId),
      sqmId: sqmId == null && nullToAbsent
          ? const Value.absent()
          : Value(sqmId),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CursorAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CursorAccount(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      email: serializer.fromJson<String?>(json['email']),
      accessToken: serializer.fromJson<String?>(json['accessToken']),
      refreshToken: serializer.fromJson<String?>(json['refreshToken']),
      membershipType: serializer.fromJson<String?>(json['membershipType']),
      signUpType: serializer.fromJson<String?>(json['signUpType']),
      machineId: serializer.fromJson<String?>(json['machineId']),
      macMachineId: serializer.fromJson<String?>(json['macMachineId']),
      devDeviceId: serializer.fromJson<String?>(json['devDeviceId']),
      sqmId: serializer.fromJson<String?>(json['sqmId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'email': serializer.toJson<String?>(email),
      'accessToken': serializer.toJson<String?>(accessToken),
      'refreshToken': serializer.toJson<String?>(refreshToken),
      'membershipType': serializer.toJson<String?>(membershipType),
      'signUpType': serializer.toJson<String?>(signUpType),
      'machineId': serializer.toJson<String?>(machineId),
      'macMachineId': serializer.toJson<String?>(macMachineId),
      'devDeviceId': serializer.toJson<String?>(devDeviceId),
      'sqmId': serializer.toJson<String?>(sqmId),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CursorAccount copyWith({
    String? id,
    String? name,
    Value<String?> email = const Value.absent(),
    Value<String?> accessToken = const Value.absent(),
    Value<String?> refreshToken = const Value.absent(),
    Value<String?> membershipType = const Value.absent(),
    Value<String?> signUpType = const Value.absent(),
    Value<String?> machineId = const Value.absent(),
    Value<String?> macMachineId = const Value.absent(),
    Value<String?> devDeviceId = const Value.absent(),
    Value<String?> sqmId = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CursorAccount(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email.present ? email.value : this.email,
    accessToken: accessToken.present ? accessToken.value : this.accessToken,
    refreshToken: refreshToken.present ? refreshToken.value : this.refreshToken,
    membershipType: membershipType.present
        ? membershipType.value
        : this.membershipType,
    signUpType: signUpType.present ? signUpType.value : this.signUpType,
    machineId: machineId.present ? machineId.value : this.machineId,
    macMachineId: macMachineId.present ? macMachineId.value : this.macMachineId,
    devDeviceId: devDeviceId.present ? devDeviceId.value : this.devDeviceId,
    sqmId: sqmId.present ? sqmId.value : this.sqmId,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CursorAccount copyWithCompanion(CursorAccountsCompanion data) {
    return CursorAccount(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      email: data.email.present ? data.email.value : this.email,
      accessToken: data.accessToken.present
          ? data.accessToken.value
          : this.accessToken,
      refreshToken: data.refreshToken.present
          ? data.refreshToken.value
          : this.refreshToken,
      membershipType: data.membershipType.present
          ? data.membershipType.value
          : this.membershipType,
      signUpType: data.signUpType.present
          ? data.signUpType.value
          : this.signUpType,
      machineId: data.machineId.present ? data.machineId.value : this.machineId,
      macMachineId: data.macMachineId.present
          ? data.macMachineId.value
          : this.macMachineId,
      devDeviceId: data.devDeviceId.present
          ? data.devDeviceId.value
          : this.devDeviceId,
      sqmId: data.sqmId.present ? data.sqmId.value : this.sqmId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CursorAccount(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('accessToken: $accessToken, ')
          ..write('refreshToken: $refreshToken, ')
          ..write('membershipType: $membershipType, ')
          ..write('signUpType: $signUpType, ')
          ..write('machineId: $machineId, ')
          ..write('macMachineId: $macMachineId, ')
          ..write('devDeviceId: $devDeviceId, ')
          ..write('sqmId: $sqmId, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    email,
    accessToken,
    refreshToken,
    membershipType,
    signUpType,
    machineId,
    macMachineId,
    devDeviceId,
    sqmId,
    isActive,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CursorAccount &&
          other.id == this.id &&
          other.name == this.name &&
          other.email == this.email &&
          other.accessToken == this.accessToken &&
          other.refreshToken == this.refreshToken &&
          other.membershipType == this.membershipType &&
          other.signUpType == this.signUpType &&
          other.machineId == this.machineId &&
          other.macMachineId == this.macMachineId &&
          other.devDeviceId == this.devDeviceId &&
          other.sqmId == this.sqmId &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CursorAccountsCompanion extends UpdateCompanion<CursorAccount> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> email;
  final Value<String?> accessToken;
  final Value<String?> refreshToken;
  final Value<String?> membershipType;
  final Value<String?> signUpType;
  final Value<String?> machineId;
  final Value<String?> macMachineId;
  final Value<String?> devDeviceId;
  final Value<String?> sqmId;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CursorAccountsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.accessToken = const Value.absent(),
    this.refreshToken = const Value.absent(),
    this.membershipType = const Value.absent(),
    this.signUpType = const Value.absent(),
    this.machineId = const Value.absent(),
    this.macMachineId = const Value.absent(),
    this.devDeviceId = const Value.absent(),
    this.sqmId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CursorAccountsCompanion.insert({
    required String id,
    required String name,
    this.email = const Value.absent(),
    this.accessToken = const Value.absent(),
    this.refreshToken = const Value.absent(),
    this.membershipType = const Value.absent(),
    this.signUpType = const Value.absent(),
    this.machineId = const Value.absent(),
    this.macMachineId = const Value.absent(),
    this.devDeviceId = const Value.absent(),
    this.sqmId = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CursorAccount> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? email,
    Expression<String>? accessToken,
    Expression<String>? refreshToken,
    Expression<String>? membershipType,
    Expression<String>? signUpType,
    Expression<String>? machineId,
    Expression<String>? macMachineId,
    Expression<String>? devDeviceId,
    Expression<String>? sqmId,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (accessToken != null) 'access_token': accessToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (membershipType != null) 'membership_type': membershipType,
      if (signUpType != null) 'sign_up_type': signUpType,
      if (machineId != null) 'machine_id': machineId,
      if (macMachineId != null) 'mac_machine_id': macMachineId,
      if (devDeviceId != null) 'dev_device_id': devDeviceId,
      if (sqmId != null) 'sqm_id': sqmId,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CursorAccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? email,
    Value<String?>? accessToken,
    Value<String?>? refreshToken,
    Value<String?>? membershipType,
    Value<String?>? signUpType,
    Value<String?>? machineId,
    Value<String?>? macMachineId,
    Value<String?>? devDeviceId,
    Value<String?>? sqmId,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CursorAccountsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      membershipType: membershipType ?? this.membershipType,
      signUpType: signUpType ?? this.signUpType,
      machineId: machineId ?? this.machineId,
      macMachineId: macMachineId ?? this.macMachineId,
      devDeviceId: devDeviceId ?? this.devDeviceId,
      sqmId: sqmId ?? this.sqmId,
      isActive: isActive ?? this.isActive,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (accessToken.present) {
      map['access_token'] = Variable<String>(accessToken.value);
    }
    if (refreshToken.present) {
      map['refresh_token'] = Variable<String>(refreshToken.value);
    }
    if (membershipType.present) {
      map['membership_type'] = Variable<String>(membershipType.value);
    }
    if (signUpType.present) {
      map['sign_up_type'] = Variable<String>(signUpType.value);
    }
    if (machineId.present) {
      map['machine_id'] = Variable<String>(machineId.value);
    }
    if (macMachineId.present) {
      map['mac_machine_id'] = Variable<String>(macMachineId.value);
    }
    if (devDeviceId.present) {
      map['dev_device_id'] = Variable<String>(devDeviceId.value);
    }
    if (sqmId.present) {
      map['sqm_id'] = Variable<String>(sqmId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
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
    return (StringBuffer('CursorAccountsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('accessToken: $accessToken, ')
          ..write('refreshToken: $refreshToken, ')
          ..write('membershipType: $membershipType, ')
          ..write('signUpType: $signUpType, ')
          ..write('machineId: $machineId, ')
          ..write('macMachineId: $macMachineId, ')
          ..write('devDeviceId: $devDeviceId, ')
          ..write('sqmId: $sqmId, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClaudeAccountsTable extends ClaudeAccounts
    with TableInfo<$ClaudeAccountsTable, ClaudeAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClaudeAccountsTable(this.attachedDatabase, [this._alias]);
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
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
    'token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subscriptionTypeMeta = const VerificationMeta(
    'subscriptionType',
  );
  @override
  late final GeneratedColumn<String> subscriptionType = GeneratedColumn<String>(
    'subscription_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _organizationUuidMeta = const VerificationMeta(
    'organizationUuid',
  );
  @override
  late final GeneratedColumn<String> organizationUuid = GeneratedColumn<String>(
    'organization_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accountInfoMeta = const VerificationMeta(
    'accountInfo',
  );
  @override
  late final GeneratedColumn<String> accountInfo = GeneratedColumn<String>(
    'account_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usageInfoMeta = const VerificationMeta(
    'usageInfo',
  );
  @override
  late final GeneratedColumn<String> usageInfo = GeneratedColumn<String>(
    'usage_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proxySoftwareMeta = const VerificationMeta(
    'proxySoftware',
  );
  @override
  late final GeneratedColumn<String> proxySoftware = GeneratedColumn<String>(
    'proxy_software',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proxySubscriptionMeta = const VerificationMeta(
    'proxySubscription',
  );
  @override
  late final GeneratedColumn<String> proxySubscription =
      GeneratedColumn<String>(
        'proxy_subscription',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _timezoneMeta = const VerificationMeta(
    'timezone',
  );
  @override
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
    'timezone',
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
    name,
    token,
    subscriptionType,
    organizationUuid,
    accountInfo,
    usageInfo,
    proxySoftware,
    proxySubscription,
    timezone,
    isActive,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'claude_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClaudeAccount> instance, {
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
    if (data.containsKey('token')) {
      context.handle(
        _tokenMeta,
        token.isAcceptableOrUnknown(data['token']!, _tokenMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenMeta);
    }
    if (data.containsKey('subscription_type')) {
      context.handle(
        _subscriptionTypeMeta,
        subscriptionType.isAcceptableOrUnknown(
          data['subscription_type']!,
          _subscriptionTypeMeta,
        ),
      );
    }
    if (data.containsKey('organization_uuid')) {
      context.handle(
        _organizationUuidMeta,
        organizationUuid.isAcceptableOrUnknown(
          data['organization_uuid']!,
          _organizationUuidMeta,
        ),
      );
    }
    if (data.containsKey('account_info')) {
      context.handle(
        _accountInfoMeta,
        accountInfo.isAcceptableOrUnknown(
          data['account_info']!,
          _accountInfoMeta,
        ),
      );
    }
    if (data.containsKey('usage_info')) {
      context.handle(
        _usageInfoMeta,
        usageInfo.isAcceptableOrUnknown(data['usage_info']!, _usageInfoMeta),
      );
    }
    if (data.containsKey('proxy_software')) {
      context.handle(
        _proxySoftwareMeta,
        proxySoftware.isAcceptableOrUnknown(
          data['proxy_software']!,
          _proxySoftwareMeta,
        ),
      );
    }
    if (data.containsKey('proxy_subscription')) {
      context.handle(
        _proxySubscriptionMeta,
        proxySubscription.isAcceptableOrUnknown(
          data['proxy_subscription']!,
          _proxySubscriptionMeta,
        ),
      );
    }
    if (data.containsKey('timezone')) {
      context.handle(
        _timezoneMeta,
        timezone.isAcceptableOrUnknown(data['timezone']!, _timezoneMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
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
  ClaudeAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClaudeAccount(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      token: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token'],
      )!,
      subscriptionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subscription_type'],
      ),
      organizationUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_uuid'],
      ),
      accountInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_info'],
      ),
      usageInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}usage_info'],
      ),
      proxySoftware: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proxy_software'],
      ),
      proxySubscription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}proxy_subscription'],
      ),
      timezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
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
  $ClaudeAccountsTable createAlias(String alias) {
    return $ClaudeAccountsTable(attachedDatabase, alias);
  }
}

class ClaudeAccount extends DataClass implements Insertable<ClaudeAccount> {
  final String id;
  final String name;
  final String token;
  final String? subscriptionType;
  final String? organizationUuid;

  /// ~/.claude.json 中的账号身份 JSON：{userID, oauthAccount}
  /// 用于切换时恢复 UI 显示的邮箱/组织（Keychain token 里没有 email）
  final String? accountInfo;

  /// 最近一次「刷新额度」的结果 JSON（持久化，重启后仍显示，虽可能过期）
  final String? usageInfo;

  /// 与该 Claude 账号绑定的本地环境配置。
  final String? proxySoftware;
  final String? proxySubscription;
  final String? timezone;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ClaudeAccount({
    required this.id,
    required this.name,
    required this.token,
    this.subscriptionType,
    this.organizationUuid,
    this.accountInfo,
    this.usageInfo,
    this.proxySoftware,
    this.proxySubscription,
    this.timezone,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['token'] = Variable<String>(token);
    if (!nullToAbsent || subscriptionType != null) {
      map['subscription_type'] = Variable<String>(subscriptionType);
    }
    if (!nullToAbsent || organizationUuid != null) {
      map['organization_uuid'] = Variable<String>(organizationUuid);
    }
    if (!nullToAbsent || accountInfo != null) {
      map['account_info'] = Variable<String>(accountInfo);
    }
    if (!nullToAbsent || usageInfo != null) {
      map['usage_info'] = Variable<String>(usageInfo);
    }
    if (!nullToAbsent || proxySoftware != null) {
      map['proxy_software'] = Variable<String>(proxySoftware);
    }
    if (!nullToAbsent || proxySubscription != null) {
      map['proxy_subscription'] = Variable<String>(proxySubscription);
    }
    if (!nullToAbsent || timezone != null) {
      map['timezone'] = Variable<String>(timezone);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ClaudeAccountsCompanion toCompanion(bool nullToAbsent) {
    return ClaudeAccountsCompanion(
      id: Value(id),
      name: Value(name),
      token: Value(token),
      subscriptionType: subscriptionType == null && nullToAbsent
          ? const Value.absent()
          : Value(subscriptionType),
      organizationUuid: organizationUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(organizationUuid),
      accountInfo: accountInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(accountInfo),
      usageInfo: usageInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(usageInfo),
      proxySoftware: proxySoftware == null && nullToAbsent
          ? const Value.absent()
          : Value(proxySoftware),
      proxySubscription: proxySubscription == null && nullToAbsent
          ? const Value.absent()
          : Value(proxySubscription),
      timezone: timezone == null && nullToAbsent
          ? const Value.absent()
          : Value(timezone),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ClaudeAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClaudeAccount(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      token: serializer.fromJson<String>(json['token']),
      subscriptionType: serializer.fromJson<String?>(json['subscriptionType']),
      organizationUuid: serializer.fromJson<String?>(json['organizationUuid']),
      accountInfo: serializer.fromJson<String?>(json['accountInfo']),
      usageInfo: serializer.fromJson<String?>(json['usageInfo']),
      proxySoftware: serializer.fromJson<String?>(json['proxySoftware']),
      proxySubscription: serializer.fromJson<String?>(
        json['proxySubscription'],
      ),
      timezone: serializer.fromJson<String?>(json['timezone']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'token': serializer.toJson<String>(token),
      'subscriptionType': serializer.toJson<String?>(subscriptionType),
      'organizationUuid': serializer.toJson<String?>(organizationUuid),
      'accountInfo': serializer.toJson<String?>(accountInfo),
      'usageInfo': serializer.toJson<String?>(usageInfo),
      'proxySoftware': serializer.toJson<String?>(proxySoftware),
      'proxySubscription': serializer.toJson<String?>(proxySubscription),
      'timezone': serializer.toJson<String?>(timezone),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ClaudeAccount copyWith({
    String? id,
    String? name,
    String? token,
    Value<String?> subscriptionType = const Value.absent(),
    Value<String?> organizationUuid = const Value.absent(),
    Value<String?> accountInfo = const Value.absent(),
    Value<String?> usageInfo = const Value.absent(),
    Value<String?> proxySoftware = const Value.absent(),
    Value<String?> proxySubscription = const Value.absent(),
    Value<String?> timezone = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ClaudeAccount(
    id: id ?? this.id,
    name: name ?? this.name,
    token: token ?? this.token,
    subscriptionType: subscriptionType.present
        ? subscriptionType.value
        : this.subscriptionType,
    organizationUuid: organizationUuid.present
        ? organizationUuid.value
        : this.organizationUuid,
    accountInfo: accountInfo.present ? accountInfo.value : this.accountInfo,
    usageInfo: usageInfo.present ? usageInfo.value : this.usageInfo,
    proxySoftware: proxySoftware.present
        ? proxySoftware.value
        : this.proxySoftware,
    proxySubscription: proxySubscription.present
        ? proxySubscription.value
        : this.proxySubscription,
    timezone: timezone.present ? timezone.value : this.timezone,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ClaudeAccount copyWithCompanion(ClaudeAccountsCompanion data) {
    return ClaudeAccount(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      token: data.token.present ? data.token.value : this.token,
      subscriptionType: data.subscriptionType.present
          ? data.subscriptionType.value
          : this.subscriptionType,
      organizationUuid: data.organizationUuid.present
          ? data.organizationUuid.value
          : this.organizationUuid,
      accountInfo: data.accountInfo.present
          ? data.accountInfo.value
          : this.accountInfo,
      usageInfo: data.usageInfo.present ? data.usageInfo.value : this.usageInfo,
      proxySoftware: data.proxySoftware.present
          ? data.proxySoftware.value
          : this.proxySoftware,
      proxySubscription: data.proxySubscription.present
          ? data.proxySubscription.value
          : this.proxySubscription,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClaudeAccount(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('token: $token, ')
          ..write('subscriptionType: $subscriptionType, ')
          ..write('organizationUuid: $organizationUuid, ')
          ..write('accountInfo: $accountInfo, ')
          ..write('usageInfo: $usageInfo, ')
          ..write('proxySoftware: $proxySoftware, ')
          ..write('proxySubscription: $proxySubscription, ')
          ..write('timezone: $timezone, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    token,
    subscriptionType,
    organizationUuid,
    accountInfo,
    usageInfo,
    proxySoftware,
    proxySubscription,
    timezone,
    isActive,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClaudeAccount &&
          other.id == this.id &&
          other.name == this.name &&
          other.token == this.token &&
          other.subscriptionType == this.subscriptionType &&
          other.organizationUuid == this.organizationUuid &&
          other.accountInfo == this.accountInfo &&
          other.usageInfo == this.usageInfo &&
          other.proxySoftware == this.proxySoftware &&
          other.proxySubscription == this.proxySubscription &&
          other.timezone == this.timezone &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ClaudeAccountsCompanion extends UpdateCompanion<ClaudeAccount> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> token;
  final Value<String?> subscriptionType;
  final Value<String?> organizationUuid;
  final Value<String?> accountInfo;
  final Value<String?> usageInfo;
  final Value<String?> proxySoftware;
  final Value<String?> proxySubscription;
  final Value<String?> timezone;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ClaudeAccountsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.token = const Value.absent(),
    this.subscriptionType = const Value.absent(),
    this.organizationUuid = const Value.absent(),
    this.accountInfo = const Value.absent(),
    this.usageInfo = const Value.absent(),
    this.proxySoftware = const Value.absent(),
    this.proxySubscription = const Value.absent(),
    this.timezone = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClaudeAccountsCompanion.insert({
    required String id,
    required String name,
    required String token,
    this.subscriptionType = const Value.absent(),
    this.organizationUuid = const Value.absent(),
    this.accountInfo = const Value.absent(),
    this.usageInfo = const Value.absent(),
    this.proxySoftware = const Value.absent(),
    this.proxySubscription = const Value.absent(),
    this.timezone = const Value.absent(),
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       token = Value(token),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ClaudeAccount> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? token,
    Expression<String>? subscriptionType,
    Expression<String>? organizationUuid,
    Expression<String>? accountInfo,
    Expression<String>? usageInfo,
    Expression<String>? proxySoftware,
    Expression<String>? proxySubscription,
    Expression<String>? timezone,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (token != null) 'token': token,
      if (subscriptionType != null) 'subscription_type': subscriptionType,
      if (organizationUuid != null) 'organization_uuid': organizationUuid,
      if (accountInfo != null) 'account_info': accountInfo,
      if (usageInfo != null) 'usage_info': usageInfo,
      if (proxySoftware != null) 'proxy_software': proxySoftware,
      if (proxySubscription != null) 'proxy_subscription': proxySubscription,
      if (timezone != null) 'timezone': timezone,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClaudeAccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? token,
    Value<String?>? subscriptionType,
    Value<String?>? organizationUuid,
    Value<String?>? accountInfo,
    Value<String?>? usageInfo,
    Value<String?>? proxySoftware,
    Value<String?>? proxySubscription,
    Value<String?>? timezone,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ClaudeAccountsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      token: token ?? this.token,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      organizationUuid: organizationUuid ?? this.organizationUuid,
      accountInfo: accountInfo ?? this.accountInfo,
      usageInfo: usageInfo ?? this.usageInfo,
      proxySoftware: proxySoftware ?? this.proxySoftware,
      proxySubscription: proxySubscription ?? this.proxySubscription,
      timezone: timezone ?? this.timezone,
      isActive: isActive ?? this.isActive,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (subscriptionType.present) {
      map['subscription_type'] = Variable<String>(subscriptionType.value);
    }
    if (organizationUuid.present) {
      map['organization_uuid'] = Variable<String>(organizationUuid.value);
    }
    if (accountInfo.present) {
      map['account_info'] = Variable<String>(accountInfo.value);
    }
    if (usageInfo.present) {
      map['usage_info'] = Variable<String>(usageInfo.value);
    }
    if (proxySoftware.present) {
      map['proxy_software'] = Variable<String>(proxySoftware.value);
    }
    if (proxySubscription.present) {
      map['proxy_subscription'] = Variable<String>(proxySubscription.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
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
    return (StringBuffer('ClaudeAccountsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('token: $token, ')
          ..write('subscriptionType: $subscriptionType, ')
          ..write('organizationUuid: $organizationUuid, ')
          ..write('accountInfo: $accountInfo, ')
          ..write('usageInfo: $usageInfo, ')
          ..write('proxySoftware: $proxySoftware, ')
          ..write('proxySubscription: $proxySubscription, ')
          ..write('timezone: $timezone, ')
          ..write('isActive: $isActive, ')
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
  late final $CursorAccountsTable cursorAccounts = $CursorAccountsTable(this);
  late final $ClaudeAccountsTable claudeAccounts = $ClaudeAccountsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    providerProfiles,
    cursorAccounts,
    claudeAccounts,
  ];
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
      Value<String?> vscodeModel,
      Value<String?> vscodeModelMode,
      Value<String?> defaultHaikuModel,
      Value<String?> defaultSonnetModel,
      Value<String?> defaultOpusModel,
      Value<String?> configContent,
      Value<bool> isOfficialProvider,
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
      Value<String?> vscodeModel,
      Value<String?> vscodeModelMode,
      Value<String?> defaultHaikuModel,
      Value<String?> defaultSonnetModel,
      Value<String?> defaultOpusModel,
      Value<String?> configContent,
      Value<bool> isOfficialProvider,
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

  ColumnFilters<String> get vscodeModel => $composableBuilder(
    column: $table.vscodeModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vscodeModelMode => $composableBuilder(
    column: $table.vscodeModelMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultHaikuModel => $composableBuilder(
    column: $table.defaultHaikuModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultSonnetModel => $composableBuilder(
    column: $table.defaultSonnetModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultOpusModel => $composableBuilder(
    column: $table.defaultOpusModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configContent => $composableBuilder(
    column: $table.configContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOfficialProvider => $composableBuilder(
    column: $table.isOfficialProvider,
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

  ColumnOrderings<String> get vscodeModel => $composableBuilder(
    column: $table.vscodeModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vscodeModelMode => $composableBuilder(
    column: $table.vscodeModelMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultHaikuModel => $composableBuilder(
    column: $table.defaultHaikuModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultSonnetModel => $composableBuilder(
    column: $table.defaultSonnetModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultOpusModel => $composableBuilder(
    column: $table.defaultOpusModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configContent => $composableBuilder(
    column: $table.configContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOfficialProvider => $composableBuilder(
    column: $table.isOfficialProvider,
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

  GeneratedColumn<String> get vscodeModel => $composableBuilder(
    column: $table.vscodeModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vscodeModelMode => $composableBuilder(
    column: $table.vscodeModelMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultHaikuModel => $composableBuilder(
    column: $table.defaultHaikuModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultSonnetModel => $composableBuilder(
    column: $table.defaultSonnetModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultOpusModel => $composableBuilder(
    column: $table.defaultOpusModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get configContent => $composableBuilder(
    column: $table.configContent,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isOfficialProvider => $composableBuilder(
    column: $table.isOfficialProvider,
    builder: (column) => column,
  );

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
                Value<String?> vscodeModel = const Value.absent(),
                Value<String?> vscodeModelMode = const Value.absent(),
                Value<String?> defaultHaikuModel = const Value.absent(),
                Value<String?> defaultSonnetModel = const Value.absent(),
                Value<String?> defaultOpusModel = const Value.absent(),
                Value<String?> configContent = const Value.absent(),
                Value<bool> isOfficialProvider = const Value.absent(),
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
                vscodeModel: vscodeModel,
                vscodeModelMode: vscodeModelMode,
                defaultHaikuModel: defaultHaikuModel,
                defaultSonnetModel: defaultSonnetModel,
                defaultOpusModel: defaultOpusModel,
                configContent: configContent,
                isOfficialProvider: isOfficialProvider,
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
                Value<String?> vscodeModel = const Value.absent(),
                Value<String?> vscodeModelMode = const Value.absent(),
                Value<String?> defaultHaikuModel = const Value.absent(),
                Value<String?> defaultSonnetModel = const Value.absent(),
                Value<String?> defaultOpusModel = const Value.absent(),
                Value<String?> configContent = const Value.absent(),
                Value<bool> isOfficialProvider = const Value.absent(),
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
                vscodeModel: vscodeModel,
                vscodeModelMode: vscodeModelMode,
                defaultHaikuModel: defaultHaikuModel,
                defaultSonnetModel: defaultSonnetModel,
                defaultOpusModel: defaultOpusModel,
                configContent: configContent,
                isOfficialProvider: isOfficialProvider,
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
typedef $$CursorAccountsTableCreateCompanionBuilder =
    CursorAccountsCompanion Function({
      required String id,
      required String name,
      Value<String?> email,
      Value<String?> accessToken,
      Value<String?> refreshToken,
      Value<String?> membershipType,
      Value<String?> signUpType,
      Value<String?> machineId,
      Value<String?> macMachineId,
      Value<String?> devDeviceId,
      Value<String?> sqmId,
      Value<bool> isActive,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CursorAccountsTableUpdateCompanionBuilder =
    CursorAccountsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> email,
      Value<String?> accessToken,
      Value<String?> refreshToken,
      Value<String?> membershipType,
      Value<String?> signUpType,
      Value<String?> machineId,
      Value<String?> macMachineId,
      Value<String?> devDeviceId,
      Value<String?> sqmId,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CursorAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $CursorAccountsTable> {
  $$CursorAccountsTableFilterComposer({
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

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accessToken => $composableBuilder(
    column: $table.accessToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refreshToken => $composableBuilder(
    column: $table.refreshToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get membershipType => $composableBuilder(
    column: $table.membershipType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signUpType => $composableBuilder(
    column: $table.signUpType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get machineId => $composableBuilder(
    column: $table.machineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get macMachineId => $composableBuilder(
    column: $table.macMachineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get devDeviceId => $composableBuilder(
    column: $table.devDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sqmId => $composableBuilder(
    column: $table.sqmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
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

class $$CursorAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $CursorAccountsTable> {
  $$CursorAccountsTableOrderingComposer({
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

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accessToken => $composableBuilder(
    column: $table.accessToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refreshToken => $composableBuilder(
    column: $table.refreshToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get membershipType => $composableBuilder(
    column: $table.membershipType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signUpType => $composableBuilder(
    column: $table.signUpType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get machineId => $composableBuilder(
    column: $table.machineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get macMachineId => $composableBuilder(
    column: $table.macMachineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get devDeviceId => $composableBuilder(
    column: $table.devDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sqmId => $composableBuilder(
    column: $table.sqmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
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

class $$CursorAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CursorAccountsTable> {
  $$CursorAccountsTableAnnotationComposer({
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

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get accessToken => $composableBuilder(
    column: $table.accessToken,
    builder: (column) => column,
  );

  GeneratedColumn<String> get refreshToken => $composableBuilder(
    column: $table.refreshToken,
    builder: (column) => column,
  );

  GeneratedColumn<String> get membershipType => $composableBuilder(
    column: $table.membershipType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signUpType => $composableBuilder(
    column: $table.signUpType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get machineId =>
      $composableBuilder(column: $table.machineId, builder: (column) => column);

  GeneratedColumn<String> get macMachineId => $composableBuilder(
    column: $table.macMachineId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get devDeviceId => $composableBuilder(
    column: $table.devDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sqmId =>
      $composableBuilder(column: $table.sqmId, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CursorAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CursorAccountsTable,
          CursorAccount,
          $$CursorAccountsTableFilterComposer,
          $$CursorAccountsTableOrderingComposer,
          $$CursorAccountsTableAnnotationComposer,
          $$CursorAccountsTableCreateCompanionBuilder,
          $$CursorAccountsTableUpdateCompanionBuilder,
          (
            CursorAccount,
            BaseReferences<_$AppDatabase, $CursorAccountsTable, CursorAccount>,
          ),
          CursorAccount,
          PrefetchHooks Function()
        > {
  $$CursorAccountsTableTableManager(
    _$AppDatabase db,
    $CursorAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CursorAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CursorAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CursorAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> accessToken = const Value.absent(),
                Value<String?> refreshToken = const Value.absent(),
                Value<String?> membershipType = const Value.absent(),
                Value<String?> signUpType = const Value.absent(),
                Value<String?> machineId = const Value.absent(),
                Value<String?> macMachineId = const Value.absent(),
                Value<String?> devDeviceId = const Value.absent(),
                Value<String?> sqmId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CursorAccountsCompanion(
                id: id,
                name: name,
                email: email,
                accessToken: accessToken,
                refreshToken: refreshToken,
                membershipType: membershipType,
                signUpType: signUpType,
                machineId: machineId,
                macMachineId: macMachineId,
                devDeviceId: devDeviceId,
                sqmId: sqmId,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> email = const Value.absent(),
                Value<String?> accessToken = const Value.absent(),
                Value<String?> refreshToken = const Value.absent(),
                Value<String?> membershipType = const Value.absent(),
                Value<String?> signUpType = const Value.absent(),
                Value<String?> machineId = const Value.absent(),
                Value<String?> macMachineId = const Value.absent(),
                Value<String?> devDeviceId = const Value.absent(),
                Value<String?> sqmId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CursorAccountsCompanion.insert(
                id: id,
                name: name,
                email: email,
                accessToken: accessToken,
                refreshToken: refreshToken,
                membershipType: membershipType,
                signUpType: signUpType,
                machineId: machineId,
                macMachineId: macMachineId,
                devDeviceId: devDeviceId,
                sqmId: sqmId,
                isActive: isActive,
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

typedef $$CursorAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CursorAccountsTable,
      CursorAccount,
      $$CursorAccountsTableFilterComposer,
      $$CursorAccountsTableOrderingComposer,
      $$CursorAccountsTableAnnotationComposer,
      $$CursorAccountsTableCreateCompanionBuilder,
      $$CursorAccountsTableUpdateCompanionBuilder,
      (
        CursorAccount,
        BaseReferences<_$AppDatabase, $CursorAccountsTable, CursorAccount>,
      ),
      CursorAccount,
      PrefetchHooks Function()
    >;
typedef $$ClaudeAccountsTableCreateCompanionBuilder =
    ClaudeAccountsCompanion Function({
      required String id,
      required String name,
      required String token,
      Value<String?> subscriptionType,
      Value<String?> organizationUuid,
      Value<String?> accountInfo,
      Value<String?> usageInfo,
      Value<String?> proxySoftware,
      Value<String?> proxySubscription,
      Value<String?> timezone,
      Value<bool> isActive,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ClaudeAccountsTableUpdateCompanionBuilder =
    ClaudeAccountsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> token,
      Value<String?> subscriptionType,
      Value<String?> organizationUuid,
      Value<String?> accountInfo,
      Value<String?> usageInfo,
      Value<String?> proxySoftware,
      Value<String?> proxySubscription,
      Value<String?> timezone,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ClaudeAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $ClaudeAccountsTable> {
  $$ClaudeAccountsTableFilterComposer({
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

  ColumnFilters<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subscriptionType => $composableBuilder(
    column: $table.subscriptionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get organizationUuid => $composableBuilder(
    column: $table.organizationUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountInfo => $composableBuilder(
    column: $table.accountInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usageInfo => $composableBuilder(
    column: $table.usageInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proxySoftware => $composableBuilder(
    column: $table.proxySoftware,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get proxySubscription => $composableBuilder(
    column: $table.proxySubscription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
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

class $$ClaudeAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClaudeAccountsTable> {
  $$ClaudeAccountsTableOrderingComposer({
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

  ColumnOrderings<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subscriptionType => $composableBuilder(
    column: $table.subscriptionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get organizationUuid => $composableBuilder(
    column: $table.organizationUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountInfo => $composableBuilder(
    column: $table.accountInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usageInfo => $composableBuilder(
    column: $table.usageInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proxySoftware => $composableBuilder(
    column: $table.proxySoftware,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get proxySubscription => $composableBuilder(
    column: $table.proxySubscription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
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

class $$ClaudeAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClaudeAccountsTable> {
  $$ClaudeAccountsTableAnnotationComposer({
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

  GeneratedColumn<String> get token =>
      $composableBuilder(column: $table.token, builder: (column) => column);

  GeneratedColumn<String> get subscriptionType => $composableBuilder(
    column: $table.subscriptionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get organizationUuid => $composableBuilder(
    column: $table.organizationUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountInfo => $composableBuilder(
    column: $table.accountInfo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get usageInfo =>
      $composableBuilder(column: $table.usageInfo, builder: (column) => column);

  GeneratedColumn<String> get proxySoftware => $composableBuilder(
    column: $table.proxySoftware,
    builder: (column) => column,
  );

  GeneratedColumn<String> get proxySubscription => $composableBuilder(
    column: $table.proxySubscription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timezone =>
      $composableBuilder(column: $table.timezone, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ClaudeAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClaudeAccountsTable,
          ClaudeAccount,
          $$ClaudeAccountsTableFilterComposer,
          $$ClaudeAccountsTableOrderingComposer,
          $$ClaudeAccountsTableAnnotationComposer,
          $$ClaudeAccountsTableCreateCompanionBuilder,
          $$ClaudeAccountsTableUpdateCompanionBuilder,
          (
            ClaudeAccount,
            BaseReferences<_$AppDatabase, $ClaudeAccountsTable, ClaudeAccount>,
          ),
          ClaudeAccount,
          PrefetchHooks Function()
        > {
  $$ClaudeAccountsTableTableManager(
    _$AppDatabase db,
    $ClaudeAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClaudeAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClaudeAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClaudeAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> token = const Value.absent(),
                Value<String?> subscriptionType = const Value.absent(),
                Value<String?> organizationUuid = const Value.absent(),
                Value<String?> accountInfo = const Value.absent(),
                Value<String?> usageInfo = const Value.absent(),
                Value<String?> proxySoftware = const Value.absent(),
                Value<String?> proxySubscription = const Value.absent(),
                Value<String?> timezone = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClaudeAccountsCompanion(
                id: id,
                name: name,
                token: token,
                subscriptionType: subscriptionType,
                organizationUuid: organizationUuid,
                accountInfo: accountInfo,
                usageInfo: usageInfo,
                proxySoftware: proxySoftware,
                proxySubscription: proxySubscription,
                timezone: timezone,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String token,
                Value<String?> subscriptionType = const Value.absent(),
                Value<String?> organizationUuid = const Value.absent(),
                Value<String?> accountInfo = const Value.absent(),
                Value<String?> usageInfo = const Value.absent(),
                Value<String?> proxySoftware = const Value.absent(),
                Value<String?> proxySubscription = const Value.absent(),
                Value<String?> timezone = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ClaudeAccountsCompanion.insert(
                id: id,
                name: name,
                token: token,
                subscriptionType: subscriptionType,
                organizationUuid: organizationUuid,
                accountInfo: accountInfo,
                usageInfo: usageInfo,
                proxySoftware: proxySoftware,
                proxySubscription: proxySubscription,
                timezone: timezone,
                isActive: isActive,
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

typedef $$ClaudeAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClaudeAccountsTable,
      ClaudeAccount,
      $$ClaudeAccountsTableFilterComposer,
      $$ClaudeAccountsTableOrderingComposer,
      $$ClaudeAccountsTableAnnotationComposer,
      $$ClaudeAccountsTableCreateCompanionBuilder,
      $$ClaudeAccountsTableUpdateCompanionBuilder,
      (
        ClaudeAccount,
        BaseReferences<_$AppDatabase, $ClaudeAccountsTable, ClaudeAccount>,
      ),
      ClaudeAccount,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProviderProfilesTableTableManager get providerProfiles =>
      $$ProviderProfilesTableTableManager(_db, _db.providerProfiles);
  $$CursorAccountsTableTableManager get cursorAccounts =>
      $$CursorAccountsTableTableManager(_db, _db.cursorAccounts);
  $$ClaudeAccountsTableTableManager get claudeAccounts =>
      $$ClaudeAccountsTableTableManager(_db, _db.claudeAccounts);
}
