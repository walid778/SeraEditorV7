import 'package:flutter/material.dart';

class SearchableBikeField extends StatelessWidget {
  final String label;
  final List<String> options;
  final TextEditingController controller;
  final ValueChanged<String>? onSelected;

  const SearchableBikeField({
    super.key,
    required this.label,
    required this.options,
    required this.controller,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(
        text: controller.text,
      ),
      displayStringForOption: (option) => option,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim();

        if (query.isEmpty) {
          return options;
        }

        return options.where(
          (option) => option.toLowerCase().contains(
                query.toLowerCase(),
              ),
        );
      },
      onSelected: (value) {
        controller.text = value;
        onSelected?.call(value);
      },
      fieldViewBuilder: (
        context,
        fieldController,
        focusNode,
        onFieldSubmitted,
      ) {
        fieldController.value = controller.value;

        fieldController.addListener(() {
          if (controller.text != fieldController.text) {
            controller.value = fieldController.value;
          }
        });

        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(
              Icons.arrow_drop_down,
            ),
          ),
          onChanged: (value) {
            controller.value = fieldController.value;
          },
        );
      },
    );
  }
}