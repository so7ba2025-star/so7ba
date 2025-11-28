import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionRepository {
  final _supabase = Supabase.instance.client;
  
  // الحصول على معلومات الإصدار الحالي
  Future<Map<String, dynamic>> getCurrentAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return {
      'version': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
    };
  }

  // التحقق من توفر تحديث
  Future<Map<String, dynamic>> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentAppVersion();
      
      final response = await _supabase
          .from('app_versions')
          .select()
          .eq('version', currentVersion['version']!)
          .single();
      
      final versionInfo = response as Map<String, dynamic>;
      
      return {
        'needsUpdate': versionInfo['is_required'] == true,
        'currentVersion': currentVersion['version'],
        'latestVersion': versionInfo['latest_version'],
        'updateUrl': versionInfo['update_url'],
        'isRequired': versionInfo['is_required'] == true,
        'message': versionInfo['message'],
      };
    } catch (e) {
      // في حالة عدم وجود الإصدار في قاعدة البيانات، نعتبره غير مدعوم
      return {
        'needsUpdate': true,
        'isRequired': true,
        'message': 'الإصدار الحالي غير مدعوم. يرجى تحديث التطبيق',
      };
    }
  }
}
