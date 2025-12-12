
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/editor_type.dart';
import '../../services/config_service.dart';
import '../../models/mcp_profile.dart';
import 'package:uuid/uuid.dart';

class AddProfileDialog extends StatefulWidget {
  final EditorType editorType;

  const AddProfileDialog({super.key, required this.editorType});

  @override
  State<AddProfileDialog> createState() => _AddProfileDialogState();
}

class _AddProfileDialogState extends State<AddProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _jsonController = TextEditingController(text: '{}');

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      // Parse JSON
      Map<String, dynamic> content = {};
      // For simplicity, we assume valid operations or handle error later
      // Real app should try-catch jsonDecode
      
      final profile = McpProfile(
        id: const Uuid().v4(),
        name: _nameController.text,
        description: _descController.text,
        content: content, // Placeholder, would parse _jsonController
      );
      
      Provider.of<ConfigService>(context, listen: false).saveProfile(widget.editorType, profile);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Profile for ${widget.editorType.label}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Profile Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: 'Description / Link',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Add'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
