import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/editor_type.dart';
import '../../services/config_service.dart';
import '../l10n/s.dart';
import 'components/styled_popup_menu.dart';
import 'components/custom_toast.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<EditorType, TextEditingController> _pathControllers = {};

  // Mock Settings State for UI Demo

  int _selectedThemeIndex = 2;    // 2: System
  bool _launchAtStartup = false;
  bool _minimizeToTray = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPaths();
  }

  Future<void> _loadPaths() async {
    final configService = Provider.of<ConfigService>(context, listen: false);
    
    // Theme mapping
    int themeIndex = 2; // System default
    final mode = configService.themeModeNotifier.value;
    if (mode == ThemeMode.light)
      themeIndex = 0;
    else if (mode == ThemeMode.dark)
      themeIndex = 1;

    setState(() {
      _selectedThemeIndex = themeIndex;
      _launchAtStartup = configService.launchAtStartup;
      _minimizeToTray = configService.minimizeToTray;
      for (var type in EditorType.values) {
        _pathControllers[type] = TextEditingController(text: configService.getConfigPath(type));
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pathControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  Future<void> _savePath(EditorType type, String value) async {
    final configService = Provider.of<ConfigService>(context, listen: false);
    await configService.setConfigPath(type, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(),
            const SizedBox(height: 16),
            _buildTabBar(),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe to match desktop feel
                children: [
                  _buildGeneralTab(),
                  _buildAdvancedTab(),
                  _buildAboutTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      padding: const EdgeInsets.only(top: 38, left: 16, right: 16, bottom: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, size: 20, color: textColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: '返回',
            ),
          ),
          const SizedBox(width: 16),
          Text(
            S.get('settings'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
       height: 32,
       margin: const EdgeInsets.symmetric(horizontal: 16),
       decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : const Color(0xFF767680).withOpacity(0.12),
         borderRadius: BorderRadius.circular(8),
       ),
       child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF636366) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        labelColor: isDark ? Colors.white : Colors.black,
        unselectedLabelColor: isDark
            ? Colors.grey.shade400
            : Colors.grey.shade600,
        labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        padding: const EdgeInsets.all(2),
        splashFactory: NoSplash.splashFactory,
        overlayColor: MaterialStateProperty.resolveWith<Color?>((states) => Colors.transparent),
        tabs: [
          Tab(text: S.get('general')),
          Tab(text: S.get('advanced')),
          Tab(text: S.get('about')),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle(S.get('interface_language')),
        Text(
          S.get('interface_language_desc'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildLanguageOption('中文', const Locale('zh')),
            const SizedBox(width: 16),
            _buildLanguageOption('English', const Locale('en')),
          ],
        ),
        
        const SizedBox(height: 32),
        
        _buildSectionTitle(S.get('appearance_theme')),
        Text(
          S.get('appearance_theme_desc'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _buildSegmentedControl(
          [
            '☀ ${S.get('theme_light')}',
            '☾ ${S.get('theme_dark')}',
            '🖥 ${S.get('theme_system')}',
          ],
          _selectedThemeIndex,
          (index) {
            setState(() => _selectedThemeIndex = index);
            final configService = Provider.of<ConfigService>(
              context,
              listen: false,
            );
            ThemeMode mode = ThemeMode.system;
            if (index == 0)
              mode = ThemeMode.light;
            else if (index == 1)
              mode = ThemeMode.dark;
            configService.setThemeMode(mode);
          },
        ),

        const SizedBox(height: 32),

        _buildSectionTitle(S.get('window_behavior')),
        Text(
          S.get('window_behavior_desc'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),

        _buildSwitchTile(
          S.get('launch_at_startup'),
          S.isEn
              ? 'Automatically start MCP Switch at login'
              : '随系统启动自动运行 MCP Switch',
          _launchAtStartup,
          (v) {
            setState(() => _launchAtStartup = v);
            Provider.of<ConfigService>(
              context,
              listen: false,
            ).setLaunchAtStartup(v);
          },
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          S.get('minimize_to_tray'),
          S.get('minimize_to_tray_desc'),
          _minimizeToTray,
          (v) {
            setState(() => _minimizeToTray = v);
            Provider.of<ConfigService>(
              context,
              listen: false,
            ).setMinimizeToTray(v);
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedTab() {
     return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle(S.get('mcp_switch_config_file')),
        Text(
          S.get('mcp_switch_config_description'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _buildPathField(
          S.get('mcp_switch_config_file_label'),
          TextEditingController(
            text: '${Platform.environment['HOME']}/.mcp-switch',
          ),
        ), // Mock for app config path
        
        const SizedBox(height: 32),
        
        _buildSectionTitle(S.get('config_override_advanced')),
        Text(
          S.get('config_override_description'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),

        ...EditorType.values.map((type) {
           final controller = _pathControllers[type];
           if (controller == null) return const SizedBox.shrink();
           return Padding(
             padding: const EdgeInsets.only(bottom: 16),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                Text(
                  type == EditorType.claude
                      ? S.get('claude_code_config_file')
                      : '${type.label} ${S.get('config_file')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                 const SizedBox(height: 8),
                 _buildPathField(type.label, controller, onChanged: (v) => _savePath(type, v)),
               ],
             ),
           );
        }).toList(),
      ],
    );
  }

  Widget _buildAboutTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.hub, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text('MCP Switch', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Version 1.0.0 (Build 100)', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          const Text(
            'Designed by jasonhuang',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildSegmentedControl(List<String> labels, int selectedIndex, ValueChanged<int> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade300;

    return Row(
      children: List.generate(labels.length, (index) {
        final isSelected = selectedIndex == index;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            onTap: () => onChanged(index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.blue : borderColor,
                ),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade200;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOpenAction(String path, String action) async {
    if (path.isEmpty) return;
    try {
      List<String> args = [];
      switch (action) {
        case 'vscode':
          args = ['-a', 'Visual Studio Code', path];
          break;
        case 'cursor':
          args = ['-a', 'Cursor', path];
          break;
        case 'windsurf':
          args = ['-a', 'Windsurf', path];
          break;
        case 'textedit':
          args = ['-a', 'TextEdit', path];
          break;
        case 'finder':
          args = ['-R', path];
          break;
        case 'default':
        default:
          args = [path];
          break;
      }
      await Process.run('open', args);
    } catch (e) {
      if (mounted) {
        Toast.show(
          context,
          message: 'Action failed: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Widget _buildPathField(String label, TextEditingController controller, {ValueChanged<String>? onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade300;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48, // Fixed height for alignment
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Select or type path...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade500 : Colors.grey,
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Menlo',
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildOpenMenu(controller.text),

      ],
    );
  }

  Widget _buildOpenMenu(String path) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade300;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
        color: cardColor,
      ),
      child: Center(
        child: StyledPopupMenu<String>(
          icon: Icons.edit_note,
          tooltip: 'Open with...',
          onSelected: (value) => _handleOpenAction(path, value),
          items: const [
            StyledPopupMenuItem(
              value: 'vscode',
              label: 'Visual Studio Code',
              icon: Icons.code,
            ),
            StyledPopupMenuItem(
              value: 'cursor',
              label: 'Cursor',
              icon: Icons.terminal,
            ),
            StyledPopupMenuItem(
              value: 'windsurf',
              label: 'Windsurf',
              icon: Icons.waves,
            ),
            StyledPopupMenuItem(
              value: 'textedit',
              label: 'TextEdit (文本编辑)',
              icon: Icons.text_snippet,
            ),
            StyledPopupMenuItem.divider(),
            StyledPopupMenuItem(
              value: 'default',
              label: '默认应用打开',
              icon: Icons.open_in_new,
            ),
            StyledPopupMenuItem(
              value: 'finder',
              label: '在 Finder 中显示',
              icon: Icons.folder_open,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String label, Locale locale) {
    final isSelected = S.localeNotifier.value == locale;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade300;

    return InkWell(
      onTap: () {
        S.setLocale(locale);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white : Colors.black87),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }


}

