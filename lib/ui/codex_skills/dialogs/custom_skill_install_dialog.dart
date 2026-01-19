part of '../../codex_skills_screen.dart';

/// Codex 自定义 Skill 安装弹窗
class _CodexCustomSkillInstallDialog extends StatefulWidget {
  final VoidCallback onInstalled;

  const _CodexCustomSkillInstallDialog({required this.onInstalled});

  @override
  State<_CodexCustomSkillInstallDialog> createState() => _CodexCustomSkillInstallDialogState();
}

class _CodexCustomSkillInstallDialogState extends State<_CodexCustomSkillInstallDialog> {
  bool _isInstalling = false;
  String? _statusMessage;

  // 解析 GitHub URL 获取 owner, repo, branch, path
  Map<String, String>? _parseGitHubUrl(String url) {
    final treeMatch = RegExp(
      r'github\.com/([^/]+)/([^/]+)/tree/([^/]+)/(.+)',
    ).firstMatch(url);

    if (treeMatch != null) {
      return {
        'owner': treeMatch.group(1)!,
        'repo': treeMatch.group(2)!,
        'branch': treeMatch.group(3)!,
        'path': treeMatch.group(4)!,
      };
    }

    final blobMatch = RegExp(
      r'github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)',
    ).firstMatch(url);

    if (blobMatch != null) {
      final filePath = blobMatch.group(4)!;
      final dirPath = filePath.endsWith('SKILL.md')
          ? filePath.substring(0, filePath.length - 9)
          : filePath.contains('/')
              ? filePath.substring(0, filePath.lastIndexOf('/'))
              : '';
      return {
        'owner': blobMatch.group(1)!,
        'repo': blobMatch.group(2)!,
        'branch': blobMatch.group(3)!,
        'path': dirPath.isEmpty ? '' : dirPath,
      };
    }

    return null;
  }

  Future<void> _downloadDirectory(
    String owner,
    String repo,
    String branch,
    String remotePath,
    String localPath,
  ) async {
    final contentsUrl =
        'https://api.github.com/repos/$owner/$repo/contents/$remotePath?ref=$branch';
    final response = await http
        .get(
          Uri.parse(contentsUrl),
          headers: {'Accept': 'application/vnd.github.v3+json'},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) return;

    final contents = jsonDecode(response.body);
    if (contents is! List) return;

    final dir = Directory(localPath);
    await dir.create(recursive: true);

    for (final item in contents) {
      if (item['type'] == 'file') {
        final fileName = item['name'] as String;
        final downloadUrl = item['download_url'] as String?;

        if (downloadUrl != null) {
          final fileResponse =
              await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 30));

          if (fileResponse.statusCode == 200) {
            final file = File('$localPath/$fileName');
            await file.writeAsBytes(fileResponse.bodyBytes);
          }
        }
      } else if (item['type'] == 'dir') {
        await _downloadDirectory(
          owner,
          repo,
          branch,
          '$remotePath/${item['name']}',
          '$localPath/${item['name']}',
        );
      }
    }
  }

  void _showInstallFormDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => _CodexSkillInstallFormDialog(
        onInstall: (url, name) async {
          Navigator.of(context).pop();
          await _doInstall(url, name);
        },
      ),
    );
  }

  Future<void> _doInstall(String url, String skillName) async {
    final parsed = _parseGitHubUrl(url);
    if (parsed == null) {
      if (mounted) {
        Toast.show(context, message: S.get('invalid_github_url'), type: ToastType.error);
      }
      return;
    }

    setState(() {
      _isInstalling = true;
      _statusMessage = S.get('fetching_skill');
    });

    try {
      final owner = parsed['owner']!;
      final repo = parsed['repo']!;
      final branch = parsed['branch']!;
      final path = parsed['path']!;

      final contentsUrl =
          'https://api.github.com/repos/$owner/$repo/contents/$path?ref=$branch';
      final contentsResponse = await http
          .get(
            Uri.parse(contentsUrl),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 30));

      if (contentsResponse.statusCode != 200) {
        throw Exception('Failed to fetch: ${contentsResponse.statusCode}');
      }

      final contents = jsonDecode(contentsResponse.body);
      if (contents is! List) throw Exception('Invalid directory contents');

      final home = PlatformUtils.userHome;
      final skillDir = Directory(PlatformUtils.joinPath(home, '.codex', 'skills', skillName));
      if (await skillDir.exists()) {
        throw Exception('Skill directory already exists: $skillName');
      }
      await skillDir.create(recursive: true);

      setState(() => _statusMessage = S.get('installing_skill'));

      for (final item in contents) {
        if (item['type'] == 'file') {
          final fileName = item['name'] as String;
          final downloadUrl = item['download_url'] as String?;
          if (downloadUrl != null) {
            final fileResponse =
                await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 30));
            if (fileResponse.statusCode == 200) {
              final file = File(PlatformUtils.joinPath(skillDir.path, fileName));
              await file.writeAsBytes(fileResponse.bodyBytes);
            }
          }
        } else if (item['type'] == 'dir') {
          await _downloadDirectory(owner, repo, branch, '$path/${item['name']}',
              PlatformUtils.joinPath(skillDir.path, item['name'] as String));
        }
      }

      final skillMdFile = File(PlatformUtils.joinPath(skillDir.path, 'SKILL.md'));
      if (!await skillMdFile.exists()) {
        await skillDir.delete(recursive: true);
        throw Exception('No SKILL.md found in the directory');
      }

      setState(() {
        _isInstalling = false;
        _statusMessage = null;
      });

      if (mounted) {
        Toast.show(context, message: S.get('skill_install_success'), type: ToastType.success);
        Navigator.of(context).pop();
        widget.onInstalled();
      }
    } catch (e) {
      setState(() {
        _isInstalling = false;
        _statusMessage = null;
      });
      if (mounted) {
        Toast.show(context, message: '${S.get('skill_install_failed')}: $e', type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 550),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.download, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        S.get('custom_skill_install'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    S.get('codex_custom_skill_desc'),
                    style: TextStyle(fontSize: 13, color: Colors.grey.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 安全提示
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              S.get('skill_security_warning'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.orange.shade200 : Colors.orange.shade800,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 状态信息
                    if (_isInstalling && _statusMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _statusMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.green.shade200 : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 安装按钮
                    InkWell(
                      onTap: _isInstalling ? null : _showInstallFormDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isInstalling)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                              )
                            else
                              const Icon(Icons.add_link, size: 18, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              S.get('custom_skill_install'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 20),

                    // 社区资源部分
                    _buildCommunityResourcesSection(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityResourcesSection(bool isDark) {
    const awesomeRepos = [
      {'name': 'openai/skills', 'url': 'https://github.com/openai/skills'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.explore, size: 18, color: Colors.teal),
            const SizedBox(width: 8),
            Text(
              S.get('community_resources'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          S.get('community_resources_desc'),
          style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 12),

        Text(
          S.get('awesome_skills_repos'),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: awesomeRepos
              .map((repo) => _buildResourceChip(
                    repo['name']!,
                    repo['url']!,
                    Icons.star_border,
                    Colors.green,
                    isDark,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildResourceChip(String name, String url, IconData icon, Color color, bool isDark) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 12, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

/// Codex Skill 安装表单弹窗
class _CodexSkillInstallFormDialog extends StatefulWidget {
  final Future<void> Function(String url, String name) onInstall;

  const _CodexSkillInstallFormDialog({required this.onInstall});

  @override
  State<_CodexSkillInstallFormDialog> createState() => _CodexSkillInstallFormDialogState();
}

class _CodexSkillInstallFormDialogState extends State<_CodexSkillInstallFormDialog> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final url = _urlController.text.trim();
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = S.get('skill_name_required'));
      return;
    }

    if (url.isEmpty || !url.contains('github.com')) {
      setState(() => _errorMessage = S.get('invalid_github_url'));
      return;
    }

    widget.onInstall(url, name);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  S.get('github_url'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Text(
                  S.get('github_url'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: S.get('github_url_tooltip'),
                  child: Icon(
                    Icons.help_outline,
                    size: 14,
                    color: Colors.grey.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: S.get('github_url_hint'),
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.6)),
                prefixIcon: const Icon(Icons.link, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),

            Text(
              S.get('skill_name'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: S.get('skill_name_hint'),
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.6)),
                prefixIcon: const Icon(Icons.label_outline, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.green),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              style: const TextStyle(fontSize: 13),
              onSubmitted: (_) => _onSubmit(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.red.shade200 : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(S.get('cancel')),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _onSubmit,
                  icon: const Icon(Icons.download, size: 18),
                  label: Text(S.get('add')),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
