
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:seraeditor/screens/home_page.dart';
import 'package:seraeditor/services/license_service.dart';
import 'package:seraeditor/services/device_identity_service.dart';

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  final TextEditingController _licenseController =
      TextEditingController();

  bool? isLicenseValid;
  bool isActivating = false;

  String? errorMessage;
  String? deviceId;
  String? deviceError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await Future.wait([
      checkLicense(),
      loadDeviceId(),
    ]);
  }

  Future<void> checkLicense() async {
    try {
      final valid =
          await LicenseService.instance.validateLicense();

      if (!mounted) return;

      setState(() {
        isLicenseValid = valid;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLicenseValid = false;
      });
    }
  }

  Future<void> loadDeviceId() async {
    try {
      final id =
          await DeviceIdentityService.instance.getDeviceId();

      if (!mounted) return;

      setState(() {
        deviceId = id;
        deviceError = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        deviceError = 'تعذر إنشاء معرّف الجهاز.';
      });
    }
  }

  Future<void> copyDeviceId() async {
    final id = deviceId;

    if (id == null || id.isEmpty) return;

    await Clipboard.setData(
      ClipboardData(text: id),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ معرّف الجهاز'),
      ),
    );
  }

  Future<void> activateLicense() async {
    if (isActivating) return;

    final code = _licenseController.text.trim();

    if (code.isEmpty) {
      setState(() {
        errorMessage = 'أدخل كود التفعيل أولًا.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      isActivating = true;
      errorMessage = null;
    });

    try {
      final success =
          await LicenseService.instance.activate(code);

      if (!mounted) return;

      setState(() {
        isActivating = false;
        isLicenseValid = success;
        errorMessage = success
            ? null
            : 'كود التفعيل غير صحيح، أو غير مخصص لهذا الجهاز، '
                'أو انتهت صلاحيته.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isActivating = false;
        isLicenseValid = false;
        errorMessage = 'تعذر التحقق من الترخيص. حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLicenseValid == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (isLicenseValid == false) {
      return const HomePage();
    }
//flutter build web --release --base-href "/SeraEditorV7/"
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 440,
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 64,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'تفعيل Sera Editor',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'انسخ معرّف جهازك وأرسله إلى إدارة التراخيص، '
                        'ثم أدخل كود التفعيل الذي يصدر لك.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // معرّف التثبيت الحالي
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'معرّف الجهاز',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (deviceId != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SelectableText(
                            deviceId!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        Text(
                          deviceError ?? 'جارٍ تجهيز معرّف الجهاز...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: deviceError == null
                                ? null
                                : Colors.red,
                          ),
                        ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: deviceId == null
                              ? null
                              : copyDeviceId,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('نسخ معرّف الجهاز'),
                        ),
                      ),

                      const SizedBox(height: 24),

                      TextField(
                        controller: _licenseController,
                        enabled: !isActivating,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => activateLicense(),
                        decoration: const InputDecoration(
                          labelText: 'كود التفعيل',
                          hintText: 'أدخل كود الترخيص',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.key_rounded),
                        ),
                      ),

                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isActivating || deviceId == null
                              ? null
                              : activateLicense,
                          icon: isActivating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.lock_open_rounded,
                                ),
                          label: Text(
                            isActivating
                                ? 'جارٍ التحقق...'
                                : 'تفعيل التطبيق',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}