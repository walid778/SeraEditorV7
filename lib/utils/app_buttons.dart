
import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppButtons {
  AppButtons._();

  // =================================================
  // Primary Button - Gold
  // =================================================

  static ButtonStyle _primaryStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppTheme.button,
      foregroundColor: AppTheme.background,
      disabledBackgroundColor: AppTheme.disabled,
      disabledForegroundColor: AppTheme.mutedText,
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static Widget primary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool loading = false,
    bool expand = false,
  }) {
    final button = ElevatedButton.icon(
      onPressed: loading ? null : onPressed,
      style: _primaryStyle(),
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.background,
              ),
            )
          : Icon(
              icon ?? Icons.check_rounded,
              size: 20,
            ),
      label: Text(label),
    );

    return expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  // =================================================
  // Secondary Button - Outlined Gold
  // =================================================

  static Widget secondary({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool expand = false,
  }) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.goldLight,
        disabledForegroundColor: AppTheme.mutedText,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        minimumSize: const Size(0, 48),
        side: BorderSide(
          color: onPressed == null
              ? AppTheme.disabled
              : AppTheme.borderHover,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      icon: Icon(
        icon ?? Icons.arrow_forward_rounded,
        size: 20,
      ),
      label: Text(label),
    );

    return expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  // =================================================
  // Danger Icon - Soft Red
  // =================================================

  static Widget dangerIcon({
    required VoidCallback? onPressed,
    String tooltip = 'حذف',
  }) {
    final isDisabled = onPressed == null;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: isDisabled
            ? AppTheme.mutedText
            : AppTheme.error,
        backgroundColor: isDisabled
            ? AppTheme.disabled.withOpacity(0.12)
            : AppTheme.error.withOpacity(0.10),
        disabledForegroundColor: AppTheme.mutedText,
        disabledBackgroundColor: AppTheme.disabled.withOpacity(0.08),
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDisabled
                ? AppTheme.divider
                : AppTheme.error.withOpacity(0.25),
          ),
        ),
      ),
      icon: const Icon(Icons.delete_outline_rounded),
    );
  }


static Widget danger({
  required String label,
  required VoidCallback? onPressed,
  IconData icon = Icons.delete_outline_rounded,
  bool expand = false,
}) {
  final button = OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppTheme.error,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      minimumSize: const Size(0, 48),
      side: BorderSide(
        color: AppTheme.error.withOpacity(0.4),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  return expand
      ? SizedBox(width: double.infinity, child: button)
      : button;
}

}
