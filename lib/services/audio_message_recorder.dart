import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// نتيجة رفع الرسالة الصوتية.
class AudioMessageUploadResult {
  final String url;
  final Duration duration;

  const AudioMessageUploadResult({required this.url, required this.duration});
}

/// وحدة مستقلّة لإدارة تسجيل الرسائل الصوتية ورفعها إلى Supabase Storage.
class AudioMessageRecorder {
  AudioMessageRecorder({
    AudioRecorder? recorder,
    SupabaseClient? supabaseClient,
    String storageBucket = 'room-assets',
    this.folderPrefix = 'room_voice',
  })  : _recorder = recorder ?? AudioRecorder(),
        _supabase = supabaseClient ?? Supabase.instance.client,
        _storageBucket = storageBucket;

  final AudioRecorder _recorder;
  final SupabaseClient _supabase;
  final String _storageBucket;
  final String folderPrefix;

  final _progressController = StreamController<Duration>.broadcast();
  Timer? _progressTimer;
  bool _isRecording = false;
  String? _currentPath;
  Duration _lastDuration = Duration.zero;
  DateTime? _recordStartTime;

  /// يوفّر تدفقاً لمدة التسجيل الحالية لتحديث الواجهة.
  Stream<Duration> get progressStream => _progressController.stream;

  bool get isRecording => _isRecording;

  /// يبدأ التسجيل ويحفظ المسار المؤقت للملف.
  Future<void> startRecording() async {
    if (_isRecording) {
      return;
    }

    if (!await _recorder.hasPermission()) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception('لم يتم منح إذن الميكروفون');
      }
    }

    final tempDir = await getTemporaryDirectory();
    final fileName =
        'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final filePath = p.join(tempDir.path, folderPrefix, fileName);

    final fileDirectory = Directory(p.dirname(filePath));
    if (!await fileDirectory.exists()) {
      await fileDirectory.create(recursive: true);
    }

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 22050,
      ),
      path: filePath,
    );

    _isRecording = true;
    _currentPath = filePath;
    _lastDuration = Duration.zero;
    _recordStartTime = DateTime.now();

    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (_recordStartTime != null) {
        _lastDuration = DateTime.now().difference(_recordStartTime!);
        _progressController.add(_lastDuration);
      }
    });
  }

  /// يوقف التسجيل، يرفع الملف ويعيد رابط التشغيل والمدة.
  Future<AudioMessageUploadResult> stopAndUpload({
    required String roomId,
  }) async {
    if (!_isRecording) {
      throw Exception('لا يوجد تسجيل نشط لإيقافه.');
    }

    final path = await _recorder.stop();
    _progressTimer?.cancel();
    _progressTimer = null;
    _isRecording = false;

    if (_recordStartTime != null) {
      _lastDuration = DateTime.now().difference(_recordStartTime!);
    }
    _recordStartTime = null;

    final resolvedPath = path ?? _currentPath;
    _currentPath = null;

    if (resolvedPath == null) {
      throw Exception('فشل حفظ التسجيل الصوتي.');
    }

    final file = File(resolvedPath);
    if (!await file.exists()) {
      throw Exception('الملف الصوتي غير موجود.');
    }

    final storagePath =
        '$folderPrefix/$roomId/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final bytes = await file.readAsBytes();

    const int maxUploadBytes = 2 * 1024 * 1024; // 2MB safety limit to avoid storage 413
    if (bytes.length > maxUploadBytes) {
      throw Exception('حجم الملف الصوتي كبير جدًا. حاول تسجيل مدة أقصر.');
    }
    
    // رفع الملف مع إعدادات الوصول العام
    await _supabase.storage.from(_storageBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'audio/m4a',
          ),
        );

    // التأكد من أن الرابط العام يعمل بشكل صحيح
    final publicUrl =
        _supabase.storage.from(_storageBucket).getPublicUrl(storagePath);
    
    // إضافة تحقق بسيط من صحة الرابط
    if (!publicUrl.contains('http')) {
      throw Exception('رابط التشغيل الصوتي غير صالح');
    }

    try {
      await file.delete();
    } catch (_) {
      // تجاهل أي خطأ أثناء حذف الملف المؤقت.
    }

    return AudioMessageUploadResult(
      url: publicUrl,
      duration: _lastDuration,
    );
  }

  /// يلغي التسجيل الحالي ويزيل أي ملفات مؤقتة.
  Future<void> cancelRecording() async {
    if (!_isRecording) {
      return;
    }

    await _recorder.stop();
    _progressTimer?.cancel();
    _progressTimer = null;
    _isRecording = false;

    final path = _currentPath;
    _currentPath = null;

    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  /// يجب استدعاء هذه الدالة عند عدم الحاجة للمكوّن بعد الآن.
  Future<void> dispose() async {
    await cancelRecording();
    await _recorder.dispose();
    await _progressController.close();
  }
}
