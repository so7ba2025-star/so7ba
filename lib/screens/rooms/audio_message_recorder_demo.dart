import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/audio_message_recorder.dart';

/// صفحة تجريبية لتجربة تسجيل ورفع الرسائل الصوتية قبل دمجها في الواجهة الرئيسة.
class AudioMessageRecorderDemo extends StatefulWidget {
  const AudioMessageRecorderDemo({super.key});

  @override
  State<AudioMessageRecorderDemo> createState() => _AudioMessageRecorderDemoState();
}

class _AudioMessageRecorderDemoState extends State<AudioMessageRecorderDemo> {
  final _recorder = AudioMessageRecorder();
  final _roomIdController = TextEditingController();
  StreamSubscription<Duration>? _progressSubscription;

  Duration _currentDuration = Duration.zero;
  bool _isRecording = false;
  bool _isUploading = false;
  String? _lastUploadUrl;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _progressSubscription = _recorder.progressStream.listen((duration) {
      setState(() {
        _currentDuration = duration;
      });
    });
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _roomIdController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _handleStart() async {
    if (_isRecording || _isUploading) return;
    setState(() {
      _lastError = null;
    });
    try {
      await _recorder.startRecording();
      setState(() {
        _isRecording = true;
        _currentDuration = Duration.zero;
      });
    } catch (e) {
      setState(() {
        _lastError = e.toString();
      });
    }
  }

  Future<void> _handleStop() async {
    if (!_isRecording || _isUploading) return;

    final roomId = _roomIdController.text.trim();
    if (roomId.isEmpty) {
      setState(() {
        _lastError = 'فضلاً أدخل رقم/معرّف الغرفة قبل الإيقاف.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _lastError = null;
    });

    try {
      final result = await _recorder.stopAndUpload(roomId: roomId);
      setState(() {
        _isRecording = false;
        _isUploading = false;
        _lastUploadUrl = result.url;
        _currentDuration = result.duration;
      });
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isUploading = false;
        _lastError = e.toString();
      });
    }
  }

  Future<void> _handleCancel() async {
    if (!_isRecording) return;
    await _recorder.cancelRecording();
    setState(() {
      _isRecording = false;
      _currentDuration = Duration.zero;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تجربة التسجيل الصوتي'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'أدخل معرف الغرفة (roomId) ثم اضغط ابدأ لتسجيل صوت، وبعدها أوقف لإرساله ورفعه على Supabase.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _roomIdController,
                style: const TextStyle(color: Colors.black87),
                decoration: const InputDecoration(
                  labelText: 'roomId',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRecording || _isUploading ? null : _handleStart,
                    icon: const Icon(Icons.mic),
                    label: const Text('ابدأ التسجيل'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: _isRecording && !_isUploading ? _handleStop : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('أوقف وأرسل'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700),
                    onPressed: _isRecording && !_isUploading ? _handleCancel : null,
                    icon: const Icon(Icons.cancel),
                    label: const Text('إلغاء'),
                  ),
                ),
              ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الحالة: ${_isRecording ? 'جاري التسجيلٍ' : _isUploading ? 'جاري الرفع...' : 'جاهز'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('المدة الحالية: ${_formatDuration(_currentDuration)}'),
                      if (_lastUploadUrl != null) ...[
                        const SizedBox(height: 12),
                        const Text('آخر رابط تم رفعه:'),
                        SelectableText(_lastUploadUrl!),
                      ],
                      if (_lastError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'خطأ: $_lastError',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
