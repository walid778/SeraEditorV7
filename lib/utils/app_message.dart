import 'package:flutter/material.dart';
import 'package:seraeditor/services/toast_service.dart';

class AppMessage {
  AppMessage._();

  static void success(BuildContext context, String message) {
    ToastService.showSuccess(context, message);
  }

  static void error(BuildContext context, String message) {
    ToastService.showError(context, message);
  }

  static void warning(BuildContext context, String message) {
    ToastService.showWarning(context, message);
  }

  static void info(BuildContext context, String message) {
    ToastService.showInfo(context, message);
  }
}