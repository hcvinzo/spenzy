import 'package:flutter/material.dart';
import 'package:spenzy_app/generated/proto/expense/expense.pb.dart'
    as expense_pb;
import 'package:spenzy_app/services/tag_service.dart';

class TagInput extends StatefulWidget {
  final List<expense_pb.Tag> initialTags;
  final Function(List<expense_pb.Tag>) onTagsChanged;
  final bool enabled;

  const TagInput({
    super.key,
    required this.initialTags,
    required this.onTagsChanged,
    this.enabled = true,
  });

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _tagService = TagService();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  List<expense_pb.Tag> _selectedTags = [];
  List<expense_pb.Tag> _suggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialTags);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _loadSuggestions(_textController.text);
    }
  }

  Future<void> _loadSuggestions(String query) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tags = await _tagService.listTags(query: query);
      if (mounted) {
        setState(() {
          _suggestions = tags
              .where((tag) =>
                  !_selectedTags.any((selected) => selected.id == tag.id))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tags: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createTag(String name) async {
    try {
      final tag = await _tagService.createTag(name);
      if (mounted) {
        setState(() {
          _selectedTags.add(tag);
          _textController.clear();
        });
        widget.onTagsChanged(_selectedTags);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating tag: $e')),
        );
      }
    }
  }

  void _removeTag(expense_pb.Tag tag) {
    setState(() {
      _selectedTags.removeWhere((t) => t.id == tag.id);
    });
    widget.onTagsChanged(_selectedTags);
  }

  void _addTag(expense_pb.Tag tag) {
    setState(() {
      _selectedTags.add(tag);
      _textController.clear();
      _suggestions.clear();
    });
    widget.onTagsChanged(_selectedTags);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _selectedTags.map((tag) {
            return Chip(
              label:
                  Text(tag.name, style: const TextStyle(color: Colors.white)),
              onDeleted: widget.enabled ? () => _removeTag(tag) : null,
              deleteIcon:
                  widget.enabled ? const Icon(Icons.close, size: 18) : null,
            );
          }).toList(),
        ),
        if (widget.enabled) ...[
          const SizedBox(height: 8),
          Autocomplete<expense_pb.Tag>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<expense_pb.Tag>.empty();
              }
              _loadSuggestions(textEditingValue.text);
              return _suggestions;
            },
            displayStringForOption: (expense_pb.Tag tag) => tag.name,
            onSelected: _addTag,
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add tags...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  suffixIcon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: controller.text.isNotEmpty
                              ? () {
                                  _createTag(controller.text);
                                  controller.clear();
                                }
                              : null,
                        ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _createTag(value);
                    controller.clear();
                  }
                },
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  child: SizedBox(
                    width: 250,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          title: Text(option.name,
                              style: const TextStyle(color: Colors.white)),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
