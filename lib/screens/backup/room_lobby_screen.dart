import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../app_config.dart';
import '../../data/rooms_repository.dart';
import '../../data/profile_repository.dart';
import '../../models/room_models.dart';
import '../../models/match_models.dart';
import '../../services/room_notification_service.dart';
import '../../services/notification_service.dart';
import '../../services/audio_message_recorder.dart';
import '../new_match_screen_online.dart' as online;
import '../ongoing_matches_screen_online.dart';
import '../finished_matches_screen_online.dart';

class NotificationDraft {
  final String title;
  final String body;
  final String? imageUrl;

  const NotificationDraft(this.title, this.body, {this.imageUrl});
}

class RoomLobbyScreen extends StatefulWidget {
  final Room room;

  const RoomLobbyScreen({Key? key, required this.room}) : super(key: key);

  @override
  _RoomLobbyScreenState createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends State<RoomLobbyScreen> {
  static const Duration _maxRecordingDuration = Duration(seconds: 30);
  final _roomsRepository = RoomsRepository();
  final _profileRepository = ProfileRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final AudioMessageRecorder _audioRecorder = AudioMessageRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _recorderProgressSubscription;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration>? _audioDurationSubscription;
  StreamSubscription<PlayerState>? _audioStateSubscription;
  Timer? _recordingTimeoutTimer;
  Duration _recordedDuration = Duration.zero;
  Duration _currentAudioPosition = Duration.zero;
  Duration _currentAudioTotalDuration = Duration.zero;
  bool _isRecording = false;
  bool _isUploadingAudio = false;
  bool _isAudioPlaying = false;
  bool _isAudioLoading = false;

  late Room _room;
  bool _isLoading = true;
  bool _isReady = false;
  bool _isHost = false;
  bool _readyLoading = false;
  List<RoomMessage> _messages = [];
  StreamSubscription? _roomSubscription;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _presenceSubscription;
  Map<String, dynamic> _presence = {};
  String? _tempRecordingRoomId;
  String? _currentAudioMessageId;
  bool _maxDurationTriggered = false;

  // Get current user ID
  String? get _currentUserId => _roomsRepository.currentUserId;

  bool _myReady() {
    try {
      final me = _room.members.firstWhere((m) => m.userId == _currentUserId);
      return me.isReady;
    } catch (_) {
      return _isReady;
    }
  }

  Future<void> _startRecordingAudio() async {
    if (_isRecording || _isUploadingAudio) return;

    try {
      await _audioRecorder.startRecording();

      _recorderProgressSubscription?.cancel();
      _recorderProgressSubscription =
          _audioRecorder.progressStream.listen((duration) {
        if (!mounted) return;
        setState(() {
          _recordedDuration = duration;
        });
      });

      if (mounted) {
        setState(() {
          _recordedDuration = Duration.zero;
          _isRecording = true;
          _tempRecordingRoomId = _room.id;
          _maxDurationTriggered = false;
        });
      }

      _recordingTimeoutTimer?.cancel();
      _recordingTimeoutTimer = Timer(
        _maxRecordingDuration,
        () {
          if (!mounted) return;
          _handleRecordingMaxDurationReached();
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر بدء التسجيل الصوتي: $e')),
        );
        setState(() {
          _isRecording = false;
          _isUploadingAudio = false;
          _recordedDuration = Duration.zero;
          _tempRecordingRoomId = null;
          _maxDurationTriggered = false;
        });
      }
    }
  }

  Future<void> _cancelRecordingAudio() async {
    if (!_isRecording) return;
    await _audioRecorder.cancelRecording();
    _recorderProgressSubscription?.cancel();
    _recordingTimeoutTimer?.cancel();
    _recordingTimeoutTimer = null;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordedDuration = Duration.zero;
        _tempRecordingRoomId = null;
      });
    }
  }

  Future<void> _stopRecordingAndSendAudio() async {
    await _stopRecordingAndSendAudioInternal();
  }

  Future<void> _stopRecordingAndSendAudioInternal({bool dueToLimit = false}) async {
    if (!_isRecording || _isUploadingAudio) return;

    final roomId = _tempRecordingRoomId ?? _room.id;

    setState(() {
      _isUploadingAudio = true;
    });

    try {
      final result = await _audioRecorder.stopAndUpload(roomId: roomId);
      _recorderProgressSubscription?.cancel();
      _recordingTimeoutTimer?.cancel();
      _recordingTimeoutTimer = null;

      await _roomsRepository.sendAudioMessage(
        roomId: roomId,
        audioUrl: result.url,
        audioDurationMs: result.duration.inMilliseconds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dueToLimit
                  ? 'تم إيقاف التسجيل تلقائياً عند 30 ثانية وإرسال الرسالة.'
                  : 'تم إرسال الرسالة الصوتية بنجاح',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال الرسالة الصوتية: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isUploadingAudio = false;
          _recordedDuration = Duration.zero;
          _tempRecordingRoomId = null;
          _maxDurationTriggered = false;
        });
      }
    }
  }

  Future<void> _handleRecordingMaxDurationReached() async {
    if (_maxDurationTriggered || !_isRecording || _isUploadingAudio) {
      return;
    }
    _maxDurationTriggered = true;
    _recordingTimeoutTimer?.cancel();
    _recordingTimeoutTimer = null;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الوصول إلى الحد الأقصى للتسجيل (30 ثانية)')),
      );
    }

    await _stopRecordingAndSendAudioInternal(dueToLimit: true);
  }

  String _formatRecordingDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _toggleAudioPlayback(RoomMessage message) async {
    final audioUrl = message.audioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رابط الصوت غير متاح')),
      );
      return;
    }

    try {
      if (_currentAudioMessageId == message.id) {
        if (_isAudioPlaying) {
          await _audioPlayer.pause();
          setState(() {
            _isAudioPlaying = false;
          });
        } else {
          await _audioPlayer.resume();
          setState(() {
            _isAudioPlaying = true;
          });
        }
        return;
      }

      setState(() {
        _isAudioLoading = true;
        _currentAudioMessageId = message.id;
        _currentAudioPosition = Duration.zero;
        _currentAudioTotalDuration = message.audioDurationMs != null
            ? Duration(milliseconds: message.audioDurationMs!)
            : Duration.zero;
      });

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(audioUrl));

      if (!mounted) return;
      setState(() {
        _isAudioLoading = false;
        _isAudioPlaying = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAudioLoading = false;
        _isAudioPlaying = false;
        _currentAudioMessageId = null;
        _currentAudioPosition = Duration.zero;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تشغيل الصوت: $e')),
      );
    }
  }

  Widget _buildAudioPlayer(RoomMessage message, bool isCurrentUser) {
    final isActive = _currentAudioMessageId == message.id;
    final isPlaying = isActive && _isAudioPlaying;
    final isLoading = isActive && _isAudioLoading;
    final position = isActive ? _currentAudioPosition : Duration.zero;
    final total = isActive && _currentAudioTotalDuration > Duration.zero
        ? _currentAudioTotalDuration
        : (message.audioDurationMs != null && message.audioDurationMs! > 0
            ? Duration(milliseconds: message.audioDurationMs!)
            : null);
    final totalMs = total?.inMilliseconds ?? 0;
    final progressValue = totalMs > 0
        ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;

    final theme = Theme.of(context);
    final backgroundColor = isCurrentUser
        ? Colors.white.withOpacity(0.15)
        : theme.colorScheme.surfaceVariant;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (isLoading)
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(theme.primaryColor),
              ),
            )
          else
            InkWell(
              onTap: () => _toggleAudioPlayback(message),
              borderRadius: BorderRadius.circular(20),
              child: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                size: 34,
                color: theme.primaryColor,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalMs > 0 ? progressValue : null,
                    minHeight: 4,
                    backgroundColor: theme.dividerColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(theme.primaryColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  total != null
                      ? '${_formatRecordingDuration(position)} / ${_formatRecordingDuration(total)}'
                      : _formatRecordingDuration(position),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _isHost = _room.hostId == _currentUserId;
    NotificationService().setActiveChatRoom(_room.id);

    Future.microtask(() async {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    });

    _audioPositionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() {
        _currentAudioPosition = position;
        if (_currentAudioMessageId != null && position > Duration.zero) {
          _isAudioLoading = false;
        }
      });
    });

    _audioDurationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _currentAudioTotalDuration = duration;
      });
    });

    _audioStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isAudioPlaying = state == PlayerState.playing;
      });
    });

    // Initialize _isReady from current room members snapshot
    try {
      final me = _room.members.firstWhere(
        (m) => m.userId == _currentUserId,
        orElse: () => RoomMember(userId: _currentUserId ?? '', displayName: 'مستخدم'),
      );
      _isReady = me.isReady;
    } catch (_) {}

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _isHost = _room.hostId == _roomsRepository.currentUserId;

      // Enter room first (this will load messages)
      await _roomsRepository.enterRoom(_room);

      // Wait a bit for messages to be loaded
      await Future.delayed(Duration(milliseconds: 200));

      // Get messages directly from cache
      final cachedMessages = _roomsRepository.getRoomMessages(_room.id);

      // Update messages from cache
      _messages = cachedMessages ?? [];

      // Reset new messages indicator on initial load
      _hasNewMessages = false;

      // Scroll to bottom on initial load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(force: true);
      });

      // Now call setState to trigger rebuild
      setState(() {
        _isLoading = false; // Set loading to false
      });

      // Subscribe to room updates with detailed logging
      _roomSubscription = _roomsRepository.roomStream.listen((room) {
        if (!mounted) return;

        if (room == null) {
          return;
        }

        if (room.id != _room.id) {
          return;
        }

        try {
          setState(() {
            _room = room;
            _isHost = room.hostId == _currentUserId;
          });

          // Update messages if they've changed AND room has messages
          // DISABLED: Use only messagesStream to avoid conflicts
          // if (room.messages.isNotEmpty &&
          //     (room.messages.length != _messages.length ||
          //         room.messages.last.id != _messages.lastOrNull?.id)) {
          //   print('🔄 [RoomLobby] Updating messages from room stream: ${room.messages.length}');
          //   setState(() {
          //     _messages = List<RoomMessage>.from(room.messages);
          //     _scrollToBottom();
          //   });
          // } else {
          //   print('🔄 [RoomLobby] Keeping existing messages (${_messages.length}) - room has ${room.messages.length}');
          // }
        } catch (e, stackTrace) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('حدث خطأ في تحديث حالة الغرفة')),
            );
          }
        }
      });

      // Subscribe to messages
      _messagesSubscription = _roomsRepository.messagesStream.listen((messages) {
        if (mounted) {
          final previousCount = _messages.length;
          final newCount = messages.length;

          setState(() {
            // Always update with the latest messages from stream
            _messages = List<RoomMessage>.from(messages);
          });

          // Scroll to bottom if this is the current user's message or if we're at bottom
          if (newCount > previousCount) {
            _onNewMessage();
            // Also scroll immediately if we just sent a message
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 50), () {
                _scrollToBottom(force: true);
              });
            });
          }
        }
      });

      // Also trigger periodic sync to ensure we have all messages
      Timer.periodic(Duration(seconds: 5), (timer) {
        if (mounted && _currentUserId != null) {
          _roomsRepository.syncMessages(_room.id);
        }
      });

      // Subscribe to presence updates
      _presenceSubscription = _roomsRepository.presenceStream.listen((state) {
        if (mounted) {
          setState(() {
            _presence = state;
          });
        }
      });

      // Load initial messages
      // Messages are already loaded from cache above
      // _messages = []; // REMOVE THIS LINE
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل بيانات الغرفة: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    NotificationService().clearActiveChatRoom(_room.id);
    _roomSubscription?.cancel();
    _messagesSubscription?.cancel();
    _presenceSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _scrollEndTimer?.cancel(); // Clean up the timer
    _recorderProgressSubscription?.cancel();
    _audioPositionSubscription?.cancel();
    _audioDurationSubscription?.cancel();
    _audioStateSubscription?.cancel();
    _recordingTimeoutTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _currentUserId == null) return;

    String? tempId; // Declare tempId outside try block to use in catch
    
    try {
      // Generate a temporary ID for optimistic UI update
      tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      
      // Get user profile for display name
      final profile = await _profileRepository.getProfile(_currentUserId!);
      final firstName = (profile['first_name'] ?? '').toString().trim();
      final lastName = (profile['last_name'] ?? '').toString().trim();
      final displayName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim();
      
      final tempMessage = RoomMessage(
        id: tempId,
        roomId: _room.id,
        userId: _currentUserId!,
        displayName: displayName.isNotEmpty ? displayName : 'مستخدم',
        content: messageText,
        sentAt: DateTime.now(),
        isSystem: false,
      );

      // Optimistically update the UI
      setState(() {
        _messages = [..._messages, tempMessage];
        _messageController.clear();
      });

      // Scroll to bottom after UI update with a small delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToBottom(force: true);
        });
      });

      // Send the message through the repository
      await _roomsRepository.sendMessage(widget.room.id, messageText);
    } catch (error) {
      // If there's an error, remove the optimistic update
      if (mounted && tempId != null) {
        setState(() {
          _messages = _messages.where((m) => m.id != tempId).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إرسال الرسالة')),
        );
      }
    }
  }

  Future<void> _toggleReady() async {
    try {
      if (_readyLoading) return;
      final currentUserId = _currentUserId;
      if (currentUserId == null) return;

      setState(() => _readyLoading = true);

      final current = _myReady();
      final desired = !current;

      final previousMembers = List<RoomMember>.from(_room.members);

      setState(() {
        _room = _room.copyWith(
          members: _room.members
              .map((member) =>
                  member.userId == currentUserId ? member.copyWith(isReady: desired) : member)
              .toList(),
        );
        _isReady = desired;
      });

      try {
        await _roomsRepository.toggleReady(desired);
      } catch (e) {
        if (mounted) {
          setState(() {
            _room = _room.copyWith(members: previousMembers);
            _isReady = current;
          });
        }
        rethrow;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحديث الحالة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _readyLoading = false);
    }
  }

  Future<void> _startGame() async {
    if (!_isHost) return;

    try {
      final selected = await showDialog<MatchMode>(
        context: context,
        builder: (ctx) {
          MatchMode? choice;
          return AlertDialog(
            title: const Text('اختيار نوع المباراة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<MatchMode>(
                  title: const Text('1 ضد 1'),
                  value: MatchMode.oneVOne,
                  groupValue: choice,
                  onChanged: (v) {
                    choice = v;
                    Navigator.of(ctx).pop(v);
                  },
                ),
                RadioListTile<MatchMode>(
                  title: const Text('2 ضد 2'),
                  value: MatchMode.twoVTwo,
                  groupValue: choice,
                  onChanged: (v) {
                    choice = v;
                    Navigator.of(ctx).pop(v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إلغاء'),
              ),
            ],
          );
        },
      );

      if (selected == null) return;

      await _roomsRepository.startGame(mode: selected.toString().split('.').last);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل بدء اللعبة: $e')),
        );
      }
    }
  }

  Future<void> _closeRoom() async {
    if (!_isHost) return;

    final shouldClose = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('إغلاق الغرفة'),
            content: Text('هل أنت متأكد من رغبتك في إغلاق الغرفة؟ سيتم طرد جميع اللاعبين.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('تأكيد', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ?? false;
        
    if (shouldClose) {
      try {
        await _roomsRepository.closeRoom();
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل إغلاق الغرفة: $e')),
          );
        }
      }
    }
  }

  void _copyInviteCode() {
    if (!_isHost) return;
    Clipboard.setData(ClipboardData(text: _room.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ كود الدعوة')),
    );
  }

  Future<void> _leaveRoom() async {
    final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('مغادرة الغرفة'),
            content: const Text('هل أنت متأكد من رغبتك في مغادرة الغرفة؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('مغادرة'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldLeave) {
      try {
        await _roomsRepository.leaveRoom();
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل مغادرة الغرفة: $e')),
          );
        }
      }
    }
  }

  bool _isUserScrolling = false;
  bool _isAtBottom = true;
  bool _hasNewMessages = false;
  bool _isMembersListExpanded = false; // للتحكم في ظهور/إخفاء قائمة الأعضاء
  final ValueNotifier<bool> _membersListExpandedNotifier = ValueNotifier<bool>(false); // Notifier للتحكم في ظهور/إخفاء القائمة
  bool _showEmojiPicker = false;
  Timer? _scrollEndTimer;
  
  void _scrollToBottom({bool force = false}) {
    if (!force && !_isAtBottom) return; // Don't auto-scroll if not at bottom
    
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _isAtBottom = true;
      _hasNewMessages = false;
    }
  }
  
  void _onUserScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final isAtBottomNow = maxScroll - currentScroll < 50; // Within 50px of bottom
      
      if (_isAtBottom != isAtBottomNow) {
        setState(() {
          _isAtBottom = isAtBottomNow;
          // If user scrolled to bottom, hide new messages indicator
          if (_isAtBottom) {
            _hasNewMessages = false;
          }
        });
      }
    }
    
    _isUserScrolling = true;
    
    // Cancel previous timer
    _scrollEndTimer?.cancel();
    
    // Set a timer to detect when user stops scrolling
    _scrollEndTimer = Timer(const Duration(milliseconds: 500), () {
      _isUserScrolling = false;
    });
  }
  
  void _onNewMessage() {
    if (_isAtBottom) {
      _scrollToBottom(force: true);
    } else {
      setState(() {
        _hasNewMessages = true;
      });
    }
  }
  
  // List of popular emojis
  final List<String> _popularEmojis = [
    '😀', '😃', '😄', '😁', '😅', '😂', '🤣', '😊', '😇', '🙂', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛',
    '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥', '😔', '😪',
    '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧', '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎', '🤓', '🧐', '😕', '😟',
    '🙁', '☹️', '😮', '😯', '😲', '😳', '🥺', '😦', '😧', '😨', '😰', '😥', '😢', '😭', '😱', '😖', '😣', '😞', '😓', '😩',
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '👇', '☝️', '✋', '🤚', '🖐️', '🖖', '👋', '🤝', '🙏',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '💯', '💢', '💥', '💫', '💦', '💨', '🕳️', '💣', '💬', '👁️‍🗨️', '🗨️', '🗯️', '💭',
    '🎉', '🎊', '🎈', '🎁', '🎂', '🎄', '🎃', '🎆', '🎇', '🧨', '✨', '🎪', '🎭', '🎨', '🎬', '🎤', '🎧', '🎼', '🎵', '🎶',
    '🔥', '💡', '⚡', '🌟', '✨', '💫', '☄️', '☀️', '🌤️', '⛅', '🌥️', '☁️', '🌦️', '🌧️', '⛈️', '🌩️', '🌨️', '❄️', '☃️', '⛄',
    '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱', '🏓', '🏸', '🏒', '🏑', '🥍', '🏏', '🥅', '⛳', '🏹', '🎣',
    '🍕', '🍔', '🍟', '🌭', '🍿', '🥓', '🥚', '🧀', '🍳', '🥞', '🥓', '🥩', '🍗', '🍖', '🌮', '🌯', '🥙', '🥗', '🥘', '🥫'
  ];
  final List<String> _quickReactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🔥', '👏', '😡', '🙏', '🎉'];
  
  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji,
    );
    
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + emoji.length),
    );
    
    setState(() {
      _showEmojiPicker = false;
    });
  }
  
  RoomMember? _findMemberById(String userId) {
    try {
      return _room.members.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  String _getSenderDisplayName(String userId) {
    final member = _findMemberById(userId);
    final normalized = member?.displayName.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }

    final repoName = _roomsRepository.displayName.trim();
    if (repoName.isNotEmpty) {
      return repoName;
    }

    return 'أحد الأعضاء';
  }

  String? _resolveAvatarUrl(String? avatarPath) {
    if (avatarPath == null) return null;
    final trimmed = avatarPath.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http')) {
      return trimmed;
    }

    final baseUrl = AppConfig.supabaseUrl.replaceAll('\\\\', '');
    return '$baseUrl/storage/v1/object/public/avatars/$trimmed';
  }

  Future<void> _toggleReaction(RoomMessage message, String emoji) async {
    try {
      await _roomsRepository.toggleMessageReaction(message.id, emoji);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث التفاعل: $e')),
      );
    }
  }

  void _showReactionPicker(RoomMessage message) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'اختر تفاعل',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: _quickReactionEmojis
                      .map(
                        (emoji) => GestureDetector(
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _toggleReaction(message, emoji);
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _showAllReactionsPicker(message);
                    });
                  },
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  label: const Text('المزيد من الإيموجي'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAllReactionsPicker(RoomMessage message) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'كل الإيموجي',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      childAspectRatio: 1,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _popularEmojis.length,
                    itemBuilder: (context, index) {
                      final emoji = _popularEmojis[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _toggleReaction(message, emoji);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReactionsBar(RoomMessage message, {required bool alignRight}) {
    if (message.reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = message.reactions.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Padding(
      padding: EdgeInsets.only(
        top: 6,
        left: alignRight ? 0 : 4,
        right: alignRight ? 4 : 0,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: alignRight ? WrapAlignment.end : WrapAlignment.start,
        children: entries.map((entry) {
          final users = entry.value;
          final reacted = _currentUserId != null && users.contains(_currentUserId);
          final count = users.length;
          return GestureDetector(
            onTap: () => _toggleReaction(message, entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: reacted
                    ? Theme.of(context).primaryColor.withOpacity(0.15)
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: reacted
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).dividerColor.withOpacity(0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (count > 1) ...[
                    const SizedBox(width: 6),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: reacted
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _buildRoomDeepLink() => 'so7ba://rooms/${_room.id}';

  Future<NotificationDraft?> _showNotificationComposer({
    required String initialTitle,
    required String initialBody,
    required String initialImageUrl,
  }) async {
    final titleController = TextEditingController(text: initialTitle)
      ..selection = TextSelection(baseOffset: 0, extentOffset: initialTitle.length);
    final bodyController = TextEditingController(text: initialBody)
      ..selection = TextSelection(baseOffset: 0, extentOffset: initialBody.length);
    final imageController = TextEditingController(text: initialImageUrl)
      ..selection = TextSelection(baseOffset: 0, extentOffset: initialImageUrl.length);
    var titleCleared = false;
    var bodyCleared = false;
    var imageCleared = false;
    var isUploadingImage = false;

    final supabase = Supabase.instance.client;
    final picker = ImagePicker();
    final messenger = ScaffoldMessenger.of(context);

    final hintStyle = TextStyle(color: Colors.grey[500]);

    try {
      return await showDialog<NotificationDraft>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setStateDialog) {
              Future<void> pickAndUploadImage() async {
                try {
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (picked == null) {
                    return;
                  }

                  final file = File(picked.path);
                  final fileSize = await file.length();
                  const maxBytes = 500 * 1024;
                  if (fileSize > maxBytes) {
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('حجم الصورة يجب ألا يتجاوز 500 كيلوبايت'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  setStateDialog(() {
                    isUploadingImage = true;
                  });

                  final ext = p.extension(picked.path).toLowerCase().replaceAll('.', '');
                  final sanitizedExt = ext.isEmpty ? 'jpg' : ext;
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  final storagePath = 'room-assets/${_room.id}/notif_$timestamp.$sanitizedExt';

                  await supabase.storage
                      .from('room-assets')
                      .upload(storagePath, file, fileOptions: const FileOptions(upsert: true));

                  final publicUrl = supabase.storage
                      .from('room-assets')
                      .getPublicUrl(storagePath);

                  imageCleared = true;
                  imageController.text = publicUrl;
                  imageController.selection =
                      TextSelection.collapsed(offset: imageController.text.length);
                  setStateDialog(() {});
                } on StorageException catch (e) {
                  developer.log('Supabase storage error while uploading notification image',
                      name: 'RoomLobbyScreen', error: e.message);
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('فشل رفع الصورة: ${e.message}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e, stack) {
                  developer.log('Failed to upload notification image',
                      name: 'RoomLobbyScreen', error: e, stackTrace: stack);
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('فشل رفع الصورة: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  setStateDialog(() {
                    isUploadingImage = false;
                  });
                }
              }

              final isValid =
                  titleController.text.trim().isNotEmpty &&
                  bodyController.text.trim().isNotEmpty &&
                  !isUploadingImage;

              return AlertDialog(
                title: const Text('كتابة التنبيه'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'عنوان الإشعار',
                          hintText: 'اكتب عنوان التنبيه',
                          hintStyle: hintStyle,
                        ),
                        maxLength: 60,
                        style: TextStyle(
                          color: titleCleared ? Colors.black : Colors.grey[600],
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        onTap: () {
                          if (!titleCleared) {
                            titleCleared = true;
                            titleController.clear();
                            setStateDialog(() {});
                          }
                        },
                        onChanged: (_) => setStateDialog(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bodyController,
                        decoration: InputDecoration(
                          labelText: 'محتوى الإشعار',
                          hintText: 'اكتب محتوى قصير وواضح',
                          hintStyle: hintStyle,
                        ),
                        maxLength: 180,
                        minLines: 3,
                        maxLines: 4,
                        style: TextStyle(
                          color: bodyCleared ? Colors.black : Colors.grey[600],
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        onTap: () {
                          if (!bodyCleared) {
                            bodyCleared = true;
                            bodyController.clear();
                            setStateDialog(() {});
                          }
                        },
                        onChanged: (_) => setStateDialog(() {}),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: imageController,
                              decoration: InputDecoration(
                                labelText: 'رابط الصورة (اختياري)',
                                hintText: 'https://example.com/image.jpg',
                                hintStyle: hintStyle,
                              ),
                              style: TextStyle(
                                color: imageCleared ? Colors.black : Colors.grey[600],
                              ),
                              textDirection: TextDirection.ltr,
                              onTap: () {
                                if (!imageCleared) {
                                  imageCleared = true;
                                  imageController.clear();
                                  setStateDialog(() {});
                                }
                              },
                              onChanged: (_) => setStateDialog(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isUploadingImage)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              tooltip: 'رفع صورة من المعرض (حد أقصى 500KB)',
                              icon: const Icon(Icons.cloud_upload),
                              onPressed: pickAndUploadImage,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: isValid
                        ? () => Navigator.of(dialogContext).pop(
                              NotificationDraft(
                                titleController.text.trim(),
                                bodyController.text.trim(),
                                imageUrl: imageController.text.trim().isEmpty
                                    ? null
                                    : imageController.text.trim(),
                              ),
                            )
                        : null,
                    child: const Text('إرسال'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        titleController.dispose();
        bodyController.dispose();
        imageController.dispose();
      });
    }
  }
  
  // Check if message can be deleted (within 5 minutes)
  bool _canDeleteMessage(RoomMessage message) {
    if (message.userId != _currentUserId) return false;
    
    final now = DateTime.now();
    final difference = now.difference(message.sentAt);
    return difference.inMinutes <= 5;
  }
  
  // Delete message
  Future<void> _deleteMessage(RoomMessage message) async {
    if (!_canDeleteMessage(message)) return;
    
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الرسالة'),
        content: const Text('هل أنت متأكد من حذف هذه الرسالة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    ) ?? false;
    
    if (shouldDelete) {
      try {
        await _roomsRepository.deleteMessage(message.id);
        // Remove from local list immediately for optimistic UI
        setState(() {
          _messages = _messages.where((m) => m.id != message.id).toList();
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل حذف الرسالة: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: null, // إزالة AppBar الثابت
        body: CustomScrollView(
          slivers: [
            // شريط العنوان (بديل AppBar)
            SliverAppBar(
              pinned: true, // تثبيت شريط العنوان في الأعلى
              title: _isHost
                  ? GestureDetector(
                      onLongPress: _copyInviteCode,
                      child: Text(_room.name, style: const TextStyle(fontSize: 18)),
                    )
                  : Text(_room.name, style: const TextStyle(fontSize: 18)),
              floating: false,
              toolbarHeight: 56,
              actions: [
                // زر جاهز/لست جاهزاً
                IconButton(
                  onPressed: _readyLoading ? null : _toggleReady,
                  icon: _readyLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          _myReady() ? Icons.check_circle : Icons.circle_outlined,
                          color: _myReady() ? Colors.green : Colors.orange,
                          size: 24,
                        ),
                  tooltip: _myReady() ? 'جاهز' : 'لست جاهزاً',
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.logout, size: 20),
                  onPressed: _leaveRoom,
                  tooltip: 'مغادرة الغرفة',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
            
            if (_isHost)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: GestureDetector(
                    onTap: _copyInviteCode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0DDBF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE0D2BC)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.vpn_key_outlined, color: Color(0xFF5B4734), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'كود الغرفة: ${_room.code}',
                              style: const TextStyle(
                                color: Color(0xFF5B4734),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(Icons.copy, color: Color(0xFF5B4734), size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // شريط التبويبات
            SliverToBoxAdapter(
              child: Container(
                color: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TabBar(
                  labelPadding: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  indicatorWeight: 3,
                  indicatorColor: Colors.white,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.chat_bubble_outline, size: 24),
                      ),
                    ),
                    Tab(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.sports_esports, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // المحتوى الرئيسي
            SliverFillRemaining(
              child: TabBarView(
                children: [
                  // تبويب المحادثة
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            // زر وقائمة الأعضاء
                            ValueListenableBuilder<bool>(
                              valueListenable: _membersListExpandedNotifier,
                              builder: (context, isExpanded, _) {
                                return Column(
                                  children: [
                                    // زر التبديل
                                    GestureDetector(
                                      onTap: () {
                                        _membersListExpandedNotifier.value = !isExpanded;
                                        setState(() {
                                          _isMembersListExpanded = !isExpanded;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          border: Border(
                                            bottom: BorderSide(color: Colors.grey[300]!), // خط فاصل أنيق
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.people_alt_outlined, size: 20, color: Colors.blueGrey),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'الأعضاء (${_room.members.length})',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blueGrey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Icon(
                                              isExpanded 
                                                  ? Icons.keyboard_arrow_up_rounded 
                                                  : Icons.keyboard_arrow_down_rounded,
                                              size: 22,
                                              color: Colors.blueGrey,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // قائمة الأعضاء (تظهر/تختفي)
                                    if (isExpanded) ...[
                                      _buildPresenceList(),
                                      const Divider(height: 1),
                                    ],
                                  ],
                                );
                              },
                            ),
                            Expanded(
                              child: _buildChat(),
                            ),
                            _buildInputArea(),
                          ],
                        ),
                  // تبويب المباريات
                  _buildMatchesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresenceList() {
    // Always build from room.members (authoritative complete list)
    List<Map<String, dynamic>> entries = _room.members
        .where((m) => m.userId.isNotEmpty)
        .map((m) => {
              'user_id': m.userId,
              'display_name': m.displayName,
              'avatar_url': m.avatarUrl,
              'is_host': m.isHost,
              'is_ready': m.isReady,
            })
        .toList();
    // Optionally overlay presence fields (e.g., is_ready) if present
    if (_presence.isNotEmpty) {
      final presenceById = <String, Map<String, dynamic>>{};
      for (final e in _presence.values.whereType<Map>()) {
        final m = Map<String, dynamic>.from(e);
        final uid = m['user_id']?.toString();
        if (uid != null) presenceById[uid] = m;
      }
      for (final p in entries) {
        final uid = p['user_id']?.toString();
        final pres = uid != null ? presenceById[uid] : null;
        if (pres != null) {
          if (pres.containsKey('is_ready')) p['is_ready'] = pres['is_ready'] == true;
          if ((p['avatar_url'] == null || (p['avatar_url'] as String).isEmpty) && pres['avatar_url'] is String) {
            p['avatar_url'] = pres['avatar_url'];
          }
          if ((p['display_name'] == null || (p['display_name'] as String).isEmpty) && pres['display_name'] is String) {
            p['display_name'] = pres['display_name'];
          }
        }
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      height: 90,  // تقليل الارتفاع الإجمالي
      child: entries.isEmpty
          ? const Center(child: Text('مفيش لاعبين'))
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final p = entries[index];
                final displayName = (p['display_name'] ?? 'مستخدم').toString();
                final avatarUrl = p['avatar_url'] as String?;
                final isReady = p['is_ready'] == true;
                final isCurrentUser = p['user_id'] == _currentUserId;
                final isHost = p['is_host'] == true;
                
                // Ensure avatar URL is properly formatted
                String? finalAvatarUrl;
                try {
                  if (avatarUrl != null && avatarUrl.toString().isNotEmpty) {
                    final avatarStr = avatarUrl.toString();
                    if (avatarStr.startsWith('http')) {
                      finalAvatarUrl = avatarStr;
                    } else if (avatarStr.isNotEmpty) {
                      // If it's a relative path, prepend the base URL
                      final baseUrl = AppConfig.supabaseUrl.replaceAll('\\', ''); // Clean up any backslashes
                      finalAvatarUrl = '$baseUrl/storage/v1/object/public/avatars/$avatarStr';
                    }
                  }
                } catch (e) {
                  finalAvatarUrl = null;
                }
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          // Golden ring for host
                          if (isHost)
                            Positioned.fill(
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.amber,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.5),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isReady ? Colors.green[100] : Colors.grey[200],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isReady ? Colors.green : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: finalAvatarUrl != null && finalAvatarUrl.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      finalAvatarUrl,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Text(
                                            displayName.isNotEmpty 
                                                ? displayName[0].toUpperCase() 
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      displayName.isNotEmpty 
                                          ? displayName[0].toUpperCase() 
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 18, 
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                          ),
                          if (isReady)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 60,
                        child: Text(
                          displayName.split(' ').first,
                          style: TextStyle(
                            fontSize: 10,
                            color: isReady ? Colors.green : Colors.grey[800],
                            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildChat() {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              _onUserScroll();
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8.0),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return _buildMessageBubble(message);
            },
          ),
        ),
        
        // New messages indicator
        if (_hasNewMessages)
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () => _scrollToBottom(force: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[400]!],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'رسائل جديدة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.message,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBubble(RoomMessage message) {
    final isCurrentUser = message.userId == _currentUserId;
    final isSystem = message.isSystem;

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  message.content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                    fontSize: 12.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              radius: 16,
              backgroundImage: message.avatarUrl != null 
                  ? NetworkImage(message.avatarUrl!) 
                  : null,
              child: message.avatarUrl == null 
                  ? Icon(Icons.person, size: 18, color: Colors.grey[600])
                  : null,
            ),
            const SizedBox(width: 8.0),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: _canDeleteMessage(message) ? () => _deleteMessage(message) : null,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  color: _canDeleteMessage(message) 
                      ? (isCurrentUser 
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05))
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: isCurrentUser 
                      ? CrossAxisAlignment.end 
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isCurrentUser) ...[
                      Text(
                        message.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                          fontSize: 12.0,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10.0,
                        horizontal: 14.0,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrentUser
                            ? Theme.of(context).primaryColor.withOpacity(0.9)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16.0),
                          topRight: const Radius.circular(16.0),
                          bottomLeft: Radius.circular(isCurrentUser ? 16.0 : 4.0),
                          bottomRight: Radius.circular(isCurrentUser ? 4.0 : 16.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2.0,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        message.content,
                        style: TextStyle(
                          color: isCurrentUser ? Colors.white : Colors.black87,
                          fontSize: 14.0,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    if (message.audioUrl != null)
                      _buildAudioPlayer(message, isCurrentUser),
                    const SizedBox(height: 6.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: isCurrentUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        Text(
                          _formatTime(message.sentAt),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showReactionPicker(message),
                          child: Icon(
                            Icons.add_reaction_outlined,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    _buildReactionsBar(message, alignRight: isCurrentUser),
                  ],
                ),
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8.0),
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.9),
              radius: 16,
              backgroundImage: message.avatarUrl != null 
                  ? NetworkImage(message.avatarUrl!) 
                  : null,
              child: message.avatarUrl == null 
                  ? Icon(Icons.person, size: 18, color: Colors.white)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to format time
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildInputArea() {
    return Column(
      children: [
        // لوحة الإيموجي
        if (_showEmojiPicker)
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // رأس لوحة الإيموجي
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      bottom: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الإيموجي',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _showEmojiPicker = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                // شبكة الإيموجي
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _popularEmojis.length,
                    itemBuilder: (context, index) {
                      final emoji = _popularEmojis[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _insertEmoji(emoji),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        
        // منطقة إدخال الرسالة
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8.0,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // زر الإيموجي
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showEmojiPicker = !_showEmojiPicker;
                    });
                    // إخفاء لوحة المفاتيح عند عرض لوحة الإيموجي
                    if (_showEmojiPicker) {
                      FocusScope.of(context).unfocus();
                    }
                  },
                  icon: Icon(
                    _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                
                // حقل إدخال الرسالة
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            enabled: !_isRecording && !_isUploadingAudio,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            maxLines: 4,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: _isRecording
                                  ? 'جارٍ التسجيل...'
                                  : 'اكتب رسالة...',
                              hintStyle: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (_isUploadingAudio)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          )
                        else if (_isRecording)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'إيقاف وإرسال',
                                icon: const Icon(Icons.stop_circle, color: Colors.red),
                                onPressed: _stopRecordingAndSendAudio,
                              ),
                              IconButton(
                                tooltip: 'إلغاء التسجيل',
                                icon: Icon(Icons.close, color: Colors.grey[700]),
                                onPressed: _cancelRecordingAudio,
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'تسجيل رسالة صوتية',
                                icon: Icon(
                                  Icons.mic,
                                  color: Theme.of(context).primaryColor,
                                ),
                                onPressed: _startRecordingAudio,
                              ),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _messageController,
                                builder: (context, value, child) {
                                  final hasText = value.text.trim().isNotEmpty;
                                  return AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: hasText
                                        ? IconButton(
                                            icon: Icon(
                                              Icons.send_rounded,
                                              color: Theme.of(context).primaryColor,
                                              size: 24,
                                            ),
                                            onPressed: _sendMessage,
                                            padding: const EdgeInsets.all(8),
                                            constraints: const BoxConstraints(),
                                          )
                                        : const SizedBox(width: 8),
                                  );
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isRecording || _isUploadingAudio)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Icon(
                  _isUploadingAudio ? Icons.cloud_upload : Icons.mic,
                  size: 18,
                  color: _isUploadingAudio ? Colors.blue : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isUploadingAudio
                        ? 'جاري رفع الرسالة الصوتية...'
                        : 'جاري التسجيلٍ: ${_formatRecordingDuration(_recordedDuration)}',
                    style: TextStyle(
                      color: _isUploadingAudio ? Colors.blueGrey : Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMatchesTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF5F5F5),
            Color(0xFFE0E0E0),
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          _LobbyActionCard(
            title: 'مباراة جديدة',
            icon: Icons.add_circle,
            gradient: const [Color(0xFF6A11CB), Color(0xFF2575FC)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => online.NewMatchScreen(room: _room)),
            ),
          ),
          const SizedBox(height: 20),
          _LobbyActionCard(
            title: 'المباريات الجارية',
            icon: Icons.play_circle_fill,
            gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => OngoingMatchesScreen(room: _room)),
            ),
          ),
          const SizedBox(height: 20),
          _LobbyActionCard(
            title: 'المباريات المنتهية',
            icon: Icons.check_circle,
            gradient: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FinishedMatchesScreen(room: _room)),
            ),
          ),
          const SizedBox(height: 20),
          _LobbyActionCard(
            title: 'تنبيه الأعضاء',
            icon: Icons.notifications_active,
            gradient: const [Color(0xFFFF6B6B), Color(0xFF4ECDC4)],
            onTap: _sendRoomNotification,
          ),
        ],
      ),
    );
  }

  // دالة إرسال تنبيه لأعضاء الغرفة
  Future<void> _sendRoomNotification() async {
    bool progressShown = false;
    try {
      final currentUserId = _currentUserId;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب تسجيل الدخول لإرسال التنبيه')),
        );
        return;
      }

      final senderName = _getSenderDisplayName(currentUserId);

      final draft = await _showNotificationComposer(
        initialTitle: 'تنبيه من غرفة ${_room.name}',
        initialBody: '$senderName ينادي عليك في الغرفة!',
        initialImageUrl: '',
      );

      if (!mounted || draft == null) {
        return;
      }

      // عرض مؤشر تحميل أثناء الإرسال
      progressShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('جاري إرسال التنبيه...'),
            ],
          ),
        ),
      ).then((_) {
        progressShown = false;
      });

      late final Map<String, dynamic> result;

      try {
        result = await RoomNotificationService.sendRoomNotification(
          roomId: _room.id,
          senderId: currentUserId,
          title: draft.title,
          body: draft.body,
          senderName: senderName,
          imageUrl:
              (draft.imageUrl?.trim().isNotEmpty ?? false) ? draft.imageUrl!.trim() : null,
          link: _buildRoomDeepLink(),
        );
      } finally {
        if (mounted && progressShown) {
          Navigator.of(context, rootNavigator: true).pop();
          progressShown = false;
        }
      }

      if (!mounted) return;

      final recipientsCount = result['recipients_count'] as int? ?? 0;

      // عرض رسالة نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال التنبيه بنجاح إلى $recipientsCount عضو',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error, stackTrace) {
      developer.log('❌ sendRoomNotification failed',
          name: 'RoomLobbyScreen', error: error, stackTrace: stackTrace);
      // إغلاق مؤشر التحميل إذا كان لا يزال مفتوحًا
      if (mounted && progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
        progressShown = false;
      }

      // عرض رسالة خطأ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إرسال التنبيه: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _LobbyActionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _LobbyActionCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_LobbyActionCard> createState() => _LobbyActionCardState();
}

class _LobbyActionCardState extends State<_LobbyActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.first.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 30,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
