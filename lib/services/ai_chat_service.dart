import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/ai_system_prompt.dart';
import '../models/chat_message.dart';
import '../utils/platform_utils.dart';
import 'skills_service.dart';
import 'terminal_service.dart';

/// AI 聊天服务
/// 负责与 Claude API 交互、管理对话历史、执行工具调用
class AiChatService extends ChangeNotifier {
  final SkillsService _skillsService = SkillsService();
  TerminalService? _terminalService;

  AnthropicClient? _client;
  String _model = 'claude-sonnet-4-20250514';
  String? _apiKey;
  String? _baseUrl;

  // 流式输出：当前正在生成的消息内容
  String _streamingContent = '';
  String get streamingContent => _streamingContent;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isPanelOpen = false;
  bool get isPanelOpen => _isPanelOpen;

  bool _showFloatingIcon = true;
  bool get showFloatingIcon => _showFloatingIcon;

  String? _error;
  String? get error => _error;

  // 聊天历史文件路径（跨平台）
  String get _historyPath =>
      PlatformUtils.joinPath(PlatformUtils.userHome, '.mcp-switch', 'chat_history.json');

  // System Prompt（从单独文件引用，便于维护）
  static String get _systemPrompt => AiSystemPrompt.prompt;

  /// 初始化
  Future<void> init(String? apiKey, {String? baseUrl, String? model}) async {
    _initClient(apiKey, baseUrl);
    if (model != null) _model = model;
    await _loadHistory();
    notifyListeners();
  }

  /// 设置 Terminal Service 引用
  void setTerminalService(TerminalService service) {
    _terminalService = service;
  }

  /// 更新 API 配置
  Future<void> updateApiConfig(String? apiKey, {String? baseUrl, String? model}) async {
    _initClient(apiKey, baseUrl);
    if (model != null) _model = model;
    notifyListeners();
  }

  /// 初始化 Anthropic Client
  void _initClient(String? apiKey, String? baseUrl) {
    _apiKey = apiKey;
    if (apiKey != null && apiKey.isNotEmpty) {
      // 处理 base URL：
      // 1. 去掉末尾斜杠
      // 2. 如果以 /v1 结尾，去掉 /v1（因为 SDK 会自动加）
      // 3. 如果以 /api 结尾，保持不变（SDK 会加 /v1/messages）
      String? sanitizedBaseUrl = baseUrl;
      if (baseUrl != null && baseUrl.isNotEmpty) {
        var url = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
        // 如果用户输入了 /v1 结尾，去掉它，因为 SDK 会自动添加
        if (url.endsWith('/v1')) {
          url = url.substring(0, url.length - 3);
        }
        sanitizedBaseUrl = url;
      }
      _baseUrl = baseUrl; // 保存原始 URL 用于手动请求
      _client = AnthropicClient(
        apiKey: apiKey,
        baseUrl: sanitizedBaseUrl, // 给 SDK 用处理后的 URL
      );
    } else {
      _baseUrl = null;
      _client = null;
    }
  }

  /// 打开聊天面板
  void openPanel() {
    _isPanelOpen = true;
    notifyListeners();
  }

  /// 关闭聊天面板
  void closePanel() {
    _isPanelOpen = false;
    notifyListeners();
  }

  /// 设置悬浮图标显示状态
  Future<void> setShowFloatingIcon(bool show) async {
    _showFloatingIcon = show;
    notifyListeners();
  }

  /// 测试 API 连接速度
  /// 使用自定义 HTTP 请求确保 URL 处理一致
  Future<({int? latency, String? error})> testConnection() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return (latency: null, error: 'API Key 未配置');
    }

    final stopwatch = Stopwatch()..start();
    try {
      final baseUrl = _baseUrl ?? 'https://api.anthropic.com';
      final uri = Uri.parse(_buildApiUrl(baseUrl));

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey!,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 10,
          'messages': [
            {'role': 'user', 'content': 'Hi'},
          ],
        }),
      );

      stopwatch.stop();

      if (response.statusCode == 200) {
        return (latency: stopwatch.elapsedMilliseconds, error: null);
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMap = errorBody['error'] as Map<String, dynamic>?;
        final errorMsg = errorMap?['message']?.toString() ?? 'HTTP ${response.statusCode}';
        return (latency: null, error: errorMsg);
      }
    } catch (e) {
      stopwatch.stop();
      return (latency: null, error: e.toString());
    }
  }

  /// 发送消息（流式输出，支持图片）
  Future<void> sendMessage(String content, {List<ChatImage>? images}) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      _error = 'API Key 未配置';
      notifyListeners();
      return;
    }

    // 如果内容和图片都为空，不发送
    if (content.trim().isEmpty && (images == null || images.isEmpty)) {
      return;
    }

    _error = null;
    _isLoading = true;
    _streamingContent = '';

    // 添加用户消息（带图片）
    final userMessage = ChatMessage.user(content, images: images);
    _messages.add(userMessage);
    notifyListeners();

    try {
      // 构建消息历史（用于 API 请求）
      final apiMessages = _buildApiMessages();

      // 使用流式 API
      await _sendStreamingRequest(apiMessages);
    } catch (e) {
      _error = e.toString();
      if (_streamingContent.isEmpty) {
        _messages.add(ChatMessage.assistant('抱歉，发生了错误：$e'));
      }
    } finally {
      _isLoading = false;
      _streamingContent = '';
      await _saveHistory();
      notifyListeners();
    }
  }

  /// 构建 API 消息格式（支持图片）
  List<Map<String, dynamic>> _buildApiMessages() {
    final apiMessages = <Map<String, dynamic>>[];

    for (final m in _messages) {
      if (m.role == ChatRole.system) continue;

      if (m.role == ChatRole.user) {
        // 用户消息可能包含图片
        if (m.hasImages) {
          // 多模态消息：图片 + 文本
          final contentBlocks = <Map<String, dynamic>>[];

          // 先添加图片
          for (final img in m.images!) {
            contentBlocks.add({
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': img.mediaType,
                'data': img.base64Data,
              },
            });
          }

          // 再添加文本
          if (m.content.isNotEmpty) {
            contentBlocks.add({
              'type': 'text',
              'text': m.content,
            });
          }

          apiMessages.add({
            'role': 'user',
            'content': contentBlocks,
          });
        } else {
          // 纯文本消息
          apiMessages.add({
            'role': 'user',
            'content': m.content,
          });
        }
      } else {
        // 助手消息
        apiMessages.add({
          'role': 'assistant',
          'content': m.content,
        });
      }
    }

    return apiMessages;
  }

  /// 智能构建 API URL
  /// 处理各种 base URL 格式：
  /// - https://api.anthropic.com → /v1/messages
  /// - https://example.com/api → /v1/messages
  /// - https://example.com/api/v1 → /messages
  /// - https://example.com/api/ → /v1/messages (去掉末尾斜杠)
  String _buildApiUrl(String baseUrl) {
    // 去掉末尾斜杠
    var url = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

    // 检查是否已经包含 /v1 结尾或 /v1/ 结尾
    if (url.endsWith('/v1')) {
      return '$url/messages';
    }

    // 检查是否包含 /v1/ 中间路径（不太可能但以防万一）
    if (url.contains('/v1/')) {
      // 已经有 /v1/xxx 的路径，直接追加 messages
      return url.endsWith('/messages') ? url : '$url/messages';
    }

    // 默认添加 /v1/messages
    return '$url/v1/messages';
  }

  /// 发送流式请求
  Future<void> _sendStreamingRequest(List<Map<String, dynamic>> apiMessages) async {
    final baseUrl = _baseUrl ?? 'https://api.anthropic.com';
    final uri = Uri.parse(_buildApiUrl(baseUrl));

    // 构建请求体
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 4096,
      'system': _systemPrompt,
      'messages': apiMessages,
      'stream': true,
      'tools': _buildToolsJson(),
    });

    final request = http.Request('POST', uri);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'x-api-key': _apiKey!,
      'anthropic-version': '2023-06-01',
    });
    request.body = body;

    final client = http.Client();
    try {
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        throw Exception('API 错误 (${response.statusCode}): $errorBody');
      }

      // 处理 SSE 流
      final textBuffer = StringBuffer();
      final toolCalls = <ToolCall>[];
      String? currentToolId;
      String? currentToolName;
      final toolInputBuffer = StringBuffer();

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        // SSE 格式：每行以 "data: " 开头
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data.isEmpty || data == '[DONE]') continue;

          try {
            final event = jsonDecode(data) as Map<String, dynamic>;
            final eventType = event['type'] as String?;

            switch (eventType) {
              case 'content_block_start':
                final block = event['content_block'] as Map<String, dynamic>?;
                if (block != null && block['type'] == 'tool_use') {
                  currentToolId = block['id'] as String?;
                  currentToolName = block['name'] as String?;
                  toolInputBuffer.clear();
                }
                break;

              case 'content_block_delta':
                final delta = event['delta'] as Map<String, dynamic>?;
                if (delta != null) {
                  final deltaType = delta['type'] as String?;
                  if (deltaType == 'text_delta') {
                    final text = delta['text'] as String? ?? '';
                    textBuffer.write(text);
                    _streamingContent = textBuffer.toString();
                    notifyListeners();
                  } else if (deltaType == 'input_json_delta') {
                    final partialJson = delta['partial_json'] as String? ?? '';
                    toolInputBuffer.write(partialJson);
                  }
                }
                break;

              case 'content_block_stop':
                if (currentToolId != null && currentToolName != null) {
                  Map<String, dynamic> input = {};
                  try {
                    final inputStr = toolInputBuffer.toString();
                    if (inputStr.isNotEmpty) {
                      input = jsonDecode(inputStr) as Map<String, dynamic>;
                    }
                  } catch (_) {}
                  toolCalls.add(ToolCall(
                    id: currentToolId!,
                    name: currentToolName!,
                    input: input,
                  ));
                  currentToolId = null;
                  currentToolName = null;
                  toolInputBuffer.clear();
                }
                break;

              case 'message_stop':
                // 消息结束
                break;
            }
          } catch (_) {
            // 忽略解析错误
          }
        }
      }

      // 消息完成，添加到历史
      final finalContent = textBuffer.toString();
      if (toolCalls.isNotEmpty) {
        // 有工具调用
        final executedCalls = <ToolCall>[];
        for (final call in toolCalls) {
          final result = await _executeToolCall(call);
          executedCalls.add(result);
        }
        _messages.add(ChatMessage.assistant(finalContent, toolCalls: executedCalls));
        notifyListeners();

        // 继续处理工具结果
        await _continueWithToolResults(executedCalls);
      } else if (finalContent.isNotEmpty) {
        _messages.add(ChatMessage.assistant(finalContent));
      }
    } finally {
      client.close();
    }
  }

  /// 构建工具定义（JSON 格式，用于流式请求）
  List<Map<String, dynamic>> _buildToolsJson() {
    return [
      {
        'name': 'list_plugins',
        'description': '列出所有已安装的 Claude Code 插件，包括版本、来源和启用状态',
        'input_schema': {'type': 'object', 'properties': {}, 'required': []},
      },
      {
        'name': 'list_marketplaces',
        'description': '列出所有已添加的插件市场',
        'input_schema': {'type': 'object', 'properties': {}, 'required': []},
      },
      {
        'name': 'list_skills',
        'description': '列出所有已安装的社区 Skills',
        'input_schema': {'type': 'object', 'properties': {}, 'required': []},
      },
      {
        'name': 'get_plugin_info',
        'description': '获取指定插件的详细信息',
        'input_schema': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': '插件名称（可以是部分名称）'},
          },
          'required': ['name'],
        },
      },
      {
        'name': 'add_marketplace',
        'description': '添加一个新的插件市场',
        'input_schema': {
          'type': 'object',
          'properties': {
            'repo': {'type': 'string', 'description': '市场仓库地址，格式：owner/repo'},
          },
          'required': ['repo'],
        },
      },
      {
        'name': 'install_plugin',
        'description': '安装指定的插件',
        'input_schema': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': '要安装的插件名称'},
            'marketplace': {'type': 'string', 'description': '可选，指定从哪个市场安装'},
          },
          'required': ['name'],
        },
      },
      {
        'name': 'uninstall_plugin',
        'description': '卸载指定的插件',
        'input_schema': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': '要卸载的插件名称'},
          },
          'required': ['name'],
        },
      },
      {
        'name': 'run_terminal_command',
        'description': '执行终端命令（仅限 claude 相关命令）',
        'input_schema': {
          'type': 'object',
          'properties': {
            'command': {'type': 'string', 'description': '要执行的命令'},
          },
          'required': ['command'],
        },
      },
    ];
  }

  /// 处理 API 响应
  Future<void> _handleResponse(Message response) async {
    final textParts = <String>[];
    final toolCalls = <ToolCall>[];

    // MessageContent 是 sealed class，需要用 switch 处理
    switch (response.content) {
      case MessageContentBlocks(value: final blocks):
        for (final block in blocks) {
          switch (block) {
            case TextBlock(text: final text):
              textParts.add(text);
            case ToolUseBlock(id: final id, name: final name, input: final input):
              toolCalls.add(ToolCall(id: id, name: name, input: input));
            case ImageBlock():
            case ToolResultBlock():
              // 忽略
              break;
          }
        }
      case MessageContentText(value: final text):
        textParts.add(text);
    }

    // 如果有工具调用，执行工具
    if (toolCalls.isNotEmpty) {
      final executedCalls = <ToolCall>[];
      for (final call in toolCalls) {
        final result = await _executeToolCall(call);
        executedCalls.add(result);
      }

      // 添加带工具调用的助手消息
      _messages.add(ChatMessage.assistant(
        textParts.join('\n'),
        toolCalls: executedCalls,
      ));

      // 如果需要继续对话（发送工具结果给 Claude）
      await _continueWithToolResults(executedCalls);
    } else {
      // 普通文本响应
      _messages.add(ChatMessage.assistant(textParts.join('\n')));
    }
  }

  /// 执行工具调用
  Future<ToolCall> _executeToolCall(ToolCall call) async {
    try {
      String result;
      switch (call.name) {
        case 'list_plugins':
          result = await _listPlugins();
          break;
        case 'list_marketplaces':
          result = await _listMarketplaces();
          break;
        case 'list_skills':
          result = await _listSkills();
          break;
        case 'get_plugin_info':
          result = await _getPluginInfo(call.input['name'] as String?);
          break;
        case 'run_terminal_command':
          result = await _runTerminalCommand(call.input['command'] as String?);
          break;
        case 'add_marketplace':
          result = await _addMarketplace(call.input['repo'] as String?);
          break;
        case 'install_plugin':
          result = await _installPlugin(
            call.input['name'] as String?,
            call.input['marketplace'] as String?,
          );
          break;
        case 'uninstall_plugin':
          result = await _uninstallPlugin(call.input['name'] as String?);
          break;
        default:
          result = '未知工具: ${call.name}';
      }
      return call.copyWith(
        result: result,
        status: ToolCallStatus.completed,
      );
    } catch (e) {
      return call.copyWith(
        error: e.toString(),
        status: ToolCallStatus.failed,
      );
    }
  }

  /// 发送工具结果继续对话（使用自定义 HTTP，确保 URL 一致）
  Future<void> _continueWithToolResults(List<ToolCall> toolCalls) async {
    try {
      // 构建完整消息历史（JSON 格式）
      final apiMessages = <Map<String, dynamic>>[];

      for (final m in _messages) {
        if (m.role == ChatRole.user) {
          // 用户消息可能包含图片
          if (m.hasImages) {
            final contentBlocks = <Map<String, dynamic>>[];
            for (final img in m.images!) {
              contentBlocks.add({
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': img.mediaType,
                  'data': img.base64Data,
                },
              });
            }
            if (m.content.isNotEmpty) {
              contentBlocks.add({'type': 'text', 'text': m.content});
            }
            apiMessages.add({'role': 'user', 'content': contentBlocks});
          } else {
            apiMessages.add({'role': 'user', 'content': m.content});
          }
        } else if (m.role == ChatRole.assistant) {
          if (m.toolCalls != null && m.toolCalls!.isNotEmpty) {
            // 带工具调用的助手消息
            final content = <Map<String, dynamic>>[];
            if (m.content.isNotEmpty) {
              content.add({'type': 'text', 'text': m.content});
            }
            for (final tc in m.toolCalls!) {
              content.add({
                'type': 'tool_use',
                'id': tc.id,
                'name': tc.name,
                'input': tc.input,
              });
            }
            apiMessages.add({
              'role': 'assistant',
              'content': content,
            });

            // 立即添加对应的 tool_result 消息
            final toolResults = m.toolCalls!.map((tc) => {
              'type': 'tool_result',
              'tool_use_id': tc.id,
              'content': tc.result ?? tc.error ?? '',
            }).toList();
            apiMessages.add({
              'role': 'user',
              'content': toolResults,
            });
          } else {
            apiMessages.add({
              'role': 'assistant',
              'content': m.content,
            });
          }
        }
      }

      // 使用自定义 HTTP 请求（与 _sendStreamingRequest 一致）
      final baseUrl = _baseUrl ?? 'https://api.anthropic.com';
      final uri = Uri.parse(_buildApiUrl(baseUrl));

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey!,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 4096,
          'system': _systemPrompt,
          'messages': apiMessages,
          'tools': _buildToolsJson(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('API 错误 (${response.statusCode}): ${response.body}');
      }

      // 解析响应
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>?;

      if (content == null || content.isEmpty) {
        return;
      }

      // 处理响应内容
      final textParts = <String>[];
      final newToolCalls = <ToolCall>[];

      for (final block in content) {
        final blockMap = block as Map<String, dynamic>;
        final blockType = blockMap['type'] as String?;

        if (blockType == 'text') {
          textParts.add(blockMap['text'] as String? ?? '');
        } else if (blockType == 'tool_use') {
          newToolCalls.add(ToolCall(
            id: blockMap['id'] as String,
            name: blockMap['name'] as String,
            input: blockMap['input'] as Map<String, dynamic>? ?? {},
          ));
        }
      }

      // 如果有新的工具调用，执行并继续
      if (newToolCalls.isNotEmpty) {
        final executedCalls = <ToolCall>[];
        for (final call in newToolCalls) {
          final result = await _executeToolCall(call);
          executedCalls.add(result);
        }
        _messages.add(ChatMessage.assistant(
          textParts.join('\n'),
          toolCalls: executedCalls,
        ));
        notifyListeners();

        // 递归处理
        await _continueWithToolResults(executedCalls);
      } else if (textParts.isNotEmpty) {
        _messages.add(ChatMessage.assistant(textParts.join('\n')));
      }
    } catch (e) {
      _error = e.toString();
      _messages.add(ChatMessage.assistant('处理工具结果时发生错误：$e'));
    }
  }

  // ==================== 工具实现 ====================

  Future<String> _listPlugins() async {
    final plugins = await _skillsService.loadPlugins();
    if (plugins.isEmpty) {
      return '当前没有安装任何插件。';
    }
    final buffer = StringBuffer('已安装的插件：\n\n');
    for (final p in plugins) {
      buffer.writeln('- ${p.name}');
      buffer.writeln('  版本: ${p.version}');
      buffer.writeln('  来源: ${p.scope}');
      buffer.writeln('  状态: ${p.isEnabled ? "已启用" : "已禁用"}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  Future<String> _listMarketplaces() async {
    final marketplaces = await _skillsService.loadMarketplaces();
    if (marketplaces.isEmpty) {
      return '当前没有添加任何插件市场。';
    }
    final buffer = StringBuffer('已添加的插件市场：\n\n');
    for (final m in marketplaces) {
      buffer.writeln('- ${m.name}');
      buffer.writeln('  仓库: ${m.repo}');
      buffer.writeln('  类型: ${m.isOfficial ? "官方" : "社区"}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  Future<String> _listSkills() async {
    final skills = await _skillsService.loadCommunitySkills();
    if (skills.isEmpty) {
      return '当前没有安装任何社区 Skills。';
    }
    final buffer = StringBuffer('已安装的社区 Skills：\n\n');
    for (final s in skills) {
      buffer.writeln('- ${s.name}');
      if (s.description != null) {
        buffer.writeln('  描述: ${s.description}');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  Future<String> _getPluginInfo(String? name) async {
    if (name == null || name.isEmpty) {
      return '请提供插件名称。';
    }
    final plugins = await _skillsService.loadPlugins();
    final plugin = plugins.where((p) => p.name.contains(name)).firstOrNull;
    if (plugin == null) {
      return '未找到名为 "$name" 的插件。';
    }
    return '''
插件详情：
- 名称: ${plugin.name}
- 版本: ${plugin.version}
- 来源: ${plugin.scope}
- 安装路径: ${plugin.installPath}
- 安装时间: ${_skillsService.formatDate(plugin.installedAt)}
- 最后更新: ${_skillsService.formatDate(plugin.lastUpdated)}
- 状态: ${plugin.isEnabled ? "已启用" : "已禁用"}
''';
  }

  Future<String> _runTerminalCommand(String? command) async {
    if (command == null || command.isEmpty) {
      return '请提供要执行的命令。';
    }

    // 安全检查：只允许 claude 相关命令
    final allowedPrefixes = [
      'claude ',
    ];

    final isAllowed =
        allowedPrefixes.any((prefix) => command.startsWith(prefix));
    if (!isAllowed) {
      return '安全限制：只允许执行 claude 相关命令。';
    }

    // 静默执行命令，捕获输出（不会发到终端，避免重复执行）
    // 使用跨平台工具类执行命令
    try {
      final result = await PlatformUtils.runCommand(command);

      final stdout = (result.stdout as String).trim();
      final stderr = (result.stderr as String).trim();

      if (result.exitCode == 0) {
        return '```bash\n\$ $command\n${stdout.isNotEmpty ? stdout : "(命令执行成功)"}\n```';
      } else {
        return '```bash\n\$ $command\n[退出码: ${result.exitCode}]\n${stderr.isNotEmpty ? stderr : stdout}\n```';
      }
    } catch (e) {
      return '```bash\n\$ $command\n[执行出错] $e\n```';
    }
  }

  Future<String> _addMarketplace(String? repo) async {
    if (repo == null || repo.isEmpty) {
      return '请提供市场仓库地址（格式：owner/repo）。';
    }
    final command = 'claude plugin marketplace add $repo';
    return await _runTerminalCommand(command);
  }

  Future<String> _installPlugin(String? name, String? marketplace) async {
    if (name == null || name.isEmpty) {
      return '请提供插件名称。';
    }
    String command;
    if (marketplace != null && marketplace.isNotEmpty) {
      // 格式：claude plugin install <plugin>@<marketplace>
      command = 'claude plugin install $name@$marketplace';
    } else {
      command = 'claude plugin install $name';
    }
    return await _runTerminalCommand(command);
  }

  Future<String> _uninstallPlugin(String? name) async {
    if (name == null || name.isEmpty) {
      return '请提供要卸载的插件名称。';
    }
    final command = 'claude plugin uninstall $name';
    return await _runTerminalCommand(command);
  }

  // ==================== 工具定义 ====================

  List<Tool> _buildTools() {
    return [
      Tool(
        name: 'list_plugins',
        description: '列出所有已安装的 Claude Code 插件，包括版本、来源和启用状态',
        inputSchema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      Tool(
        name: 'list_marketplaces',
        description: '列出所有已添加的插件市场',
        inputSchema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      Tool(
        name: 'list_skills',
        description: '列出所有已安装的社区 Skills',
        inputSchema: {
          'type': 'object',
          'properties': {},
          'required': [],
        },
      ),
      Tool(
        name: 'get_plugin_info',
        description: '获取指定插件的详细信息',
        inputSchema: {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description': '插件名称（可以是部分名称）',
            },
          },
          'required': ['name'],
        },
      ),
      Tool(
        name: 'add_marketplace',
        description: '添加一个新的插件市场',
        inputSchema: {
          'type': 'object',
          'properties': {
            'repo': {
              'type': 'string',
              'description': '市场仓库地址，格式：owner/repo（如 anthropics/claude-plugins）',
            },
          },
          'required': ['repo'],
        },
      ),
      Tool(
        name: 'install_plugin',
        description: '安装指定的插件',
        inputSchema: {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description': '要安装的插件名称',
            },
            'marketplace': {
              'type': 'string',
              'description': '可选，指定从哪个市场安装',
            },
          },
          'required': ['name'],
        },
      ),
      Tool(
        name: 'uninstall_plugin',
        description: '卸载指定的插件',
        inputSchema: {
          'type': 'object',
          'properties': {
            'name': {
              'type': 'string',
              'description': '要卸载的插件名称',
            },
          },
          'required': ['name'],
        },
      ),
      Tool(
        name: 'run_terminal_command',
        description: '执行终端命令（仅限 claude 相关命令）',
        inputSchema: {
          'type': 'object',
          'properties': {
            'command': {
              'type': 'string',
              'description': '要执行的命令',
            },
          },
          'required': ['command'],
        },
      ),
    ];
  }

  // ==================== 历史记录管理 ====================

  Future<void> _loadHistory() async {
    try {
      final file = File(_historyPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as List;
        _messages.clear();
        _messages.addAll(
          json.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      debugPrint('加载聊天历史失败: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final file = File(_historyPath);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final json = _messages.map((m) => m.toJson()).toList();
      await file.writeAsString(jsonEncode(json));
    } catch (e) {
      debugPrint('保存聊天历史失败: $e');
    }
  }

  /// 清空聊天历史
  Future<void> clearHistory() async {
    _messages.clear();
    await _saveHistory();
    notifyListeners();
  }

  /// 导出聊天历史
  Future<String> exportHistory() async {
    final buffer = StringBuffer();
    buffer.writeln('# MCP Switch AI 聊天记录');
    buffer.writeln('导出时间: ${DateTime.now().toIso8601String()}');
    buffer.writeln('---\n');

    for (final message in _messages) {
      final role = message.role == ChatRole.user ? '用户' : 'AI';
      buffer.writeln('### $role (${message.timestamp.toIso8601String()})');
      buffer.writeln(message.content);
      if (message.toolCalls != null && message.toolCalls!.isNotEmpty) {
        buffer.writeln('\n**工具调用:**');
        for (final tc in message.toolCalls!) {
          buffer.writeln('- ${tc.name}: ${tc.status.name}');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}
