import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final String? initialValue;

  const OtpInput({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.initialValue,
  });

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    widget.onChanged(text);
    if (text.length == widget.length) {
      widget.onCompleted?.call(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Hidden TextField to capture input
        SizedBox(
          width: 1,
          height: 1,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(widget.length),
            ],
            // Hide the cursor and text
            showCursor: false,
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
            ),
            style: TextStyle(
              color: colorScheme.surface.withValues(alpha: 0.0),
            ),
          ),
        ),
        // Visible Boxes
        GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(_focusNode);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (index) {
              final text = _controller.text;
              final char = index < text.length ? text[index] : '';

              // If the field is full, the last box is "focused" in terms of border color if we want
              // But typically we only show focus on the empty slot or the last filled one.
              // Let's just highlight the current active slot (index == text.length)
              // Or if text is full, maybe highlight the last one?
              // Let's highlight the box that will receive the next character.
              // If full, maybe no highlight or highlight all?
              // Actually, usually all boxes have a border, and the active one has a primary color border.

              final isActive = index == text.length ||
                  (index == widget.length - 1 && text.length == widget.length);

              return Container(
                width: 44,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive && _focusNode.hasFocus
                        ? colorScheme.primary
                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: isActive && _focusNode.hasFocus ? 2 : 1,
                  ),
                  boxShadow: [
                    if (isActive && _focusNode.hasFocus)
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Text(
                  char,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
