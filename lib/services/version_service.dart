import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class VersionService {
  static final VersionService _instance = VersionService._internal();
  factory VersionService() => _instance;
  VersionService._internal();

  final _supabase = Supabase.instance.client;
  
  Future<Map<String, dynamic>> getAppVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      final response = await _supabase
          .from('app_versions')
          .select()
          .eq('version', currentVersion)
          .maybeSingle();
      
      if (response == null) {
        // إذا لم يتم العثور على الإصدار، نعتبره غير مدعوم
        return {
          'isSupported': false,
          'isUpdateRequired': true,
          'currentVersion': currentVersion,
          'latestVersion': currentVersion,
          'updateUrl': 'https://play.google.com/store/apps/details?id=com.ashraf.so7ba_online',
          'message': 'الإصدار الحالي غير مدعوم. يرجى تحديث التطبيق',
        };
      }
      
      final versionInfo = Map<String, dynamic>.from(response);
      
      return {
        'isSupported': true,
        'isUpdateRequired': versionInfo['is_required'] == true,
        'currentVersion': currentVersion,
        'latestVersion': versionInfo['latest_version'],
        'updateUrl': versionInfo['update_url'] ?? 'https://play.google.com/store/apps/details?id=com.ashraf.so7ba_online',
        'message': versionInfo['message'] ?? 'يتوفر تحديث جديد',
      };
    } catch (e) {
      // في حالة حدوث خطأ، نعتبر التطبيق مدعوماً لتجنب منع المستخدم من الاستخدام
      return {
        'isSupported': true,
        'isUpdateRequired': false,
        'error': e.toString(),
      };
    }
  }

  static Future<bool> showUpdateDialog({
    required BuildContext context,
    required bool isRequired,
    required String message,
    required String updateUrl,
  }) async {
    bool shouldUpdate = false;
    
    await showDialog(
      context: context,
      barrierDismissible: !isRequired,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => !isRequired,
          child: AlertDialog(
            title: Text(isRequired ? 'تحديث إلزامي' : 'تحديث متاح'),
            content: Text(message),
            actions: <Widget>[
              if (!isRequired)
                TextButton(
                  child: const Text('لاحقاً'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              TextButton(
                child: const Text('تحديث الآن'),
                onPressed: () async {
                  shouldUpdate = true;
                  final uri = Uri.parse(updateUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
    
    return shouldUpdate;
  }
}
