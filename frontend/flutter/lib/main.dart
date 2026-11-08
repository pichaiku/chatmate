import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'models/database_schema.dart';
import 'models/message.dart';
import 'utils/date_formatter.dart';
import 'welcome_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

Uri _serverUri(String scheme, String path) {
  final host = dotenv.env['HOST'];
  final port = int.tryParse(dotenv.env['PORT'] ?? '8000');

  if (host == null || host.isEmpty || port == null || port < 1 || port > 65535) {
    throw StateError('Set a valid HOST and PORT in the Flutter .env file.');
  }

  return Uri(scheme: scheme, host: host, port: port, path: path);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD63384),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: SplashOrMain(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final int customer_id;
  final String customerName;

  const ChatScreen({
    Key? key,
    required this.customer_id,
    required this.customerName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  late WebSocketChannel _channel;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  final Dio _dio = Dio();
  bool _isLoading = true;
  bool _isAttachmentMenuOpen = false;
  AnimationController? _fabAnimationController;
  AnimationController? _menuAnimationController;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeChat();
  }

  void _initializeAnimations() {
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _menuAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _initializeChat() async {
    await _loadChatHistoryFromAPI();
    _connectWebSocket();
  }

  Future<void> _loadChatHistoryFromAPI() async {
    try {
      setState(() => _isLoading = true);
      
      final response = await _dio.get(
        _serverUri('http', '/api/chat/history/${widget.customer_id}').toString(),
        options: Options(
          validateStatus: (status) => status == 200 || status == 404,
        ),
      );

      if (response.statusCode == 404 ||
          (response.data is List && (response.data as List).isEmpty)) {
        setState(() => _messages.clear());
        return;
      }

      if (response.statusCode == 200) {
        final List<dynamic> messages = response.data;
        
        final db = await DatabaseHelper.instance.database;
        await db.transaction((txn) async {
          for (var message in messages) {
            await txn.insert(
              'chat_messages',
              {
                'id': message['id'],
                'customer_id': widget.customer_id,
                'message_type': message['message_type'],
                'content': message['content'],
                'is_from_user': message['is_from_user'],
                'created_at': message['created_at'],
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });

        setState(() {
          _messages.clear();
          _messages.addAll(messages.map((m) => Message.fromJson(m)));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to load chat history'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        _serverUri('ws', '/ws/${widget.customer_id}'),
      );

      _channel.stream.listen(
        (message) async {
          try {
            final data = json.decode(message);
            final responseMessage = Message.fromJson(data);
            
            try {
              final db = await DatabaseHelper.instance.database;
              await db.insert(
                'chat_messages',
                {
                  'id': responseMessage.id,
                  'customer_id': widget.customer_id,
                  'message_type': responseMessage.message_type,
                  'content': responseMessage.content,
                  'is_from_user': 0,
                  'created_at': responseMessage.created_at.toIso8601String(),
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Failed to save response to database'),
                  backgroundColor: Colors.red.shade400,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }

            setState(() {
              _messages.add(responseMessage);
            });
            _scrollToBottom();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Error processing message'),
                backgroundColor: Colors.red.shade400,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Connection error. Trying to reconnect...'),
              backgroundColor: Colors.orange.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _connectWebSocket();
            }
          });
        },
        onDone: () {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _connectWebSocket();
            }
          });
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to connect. Retrying...'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          _connectWebSocket();
        }
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch,
      message_type: 'text',
      content: content,
      is_from_user: true,
    );

    setState(() {
      _messages.add(message);
    });

    _messageController.clear();

    try {
      await _channel.ready;
      final wsMessage = message.toJson();
      wsMessage['customer_id'] = widget.customer_id;
      _channel.sink.add(json.encode(wsMessage));
    } catch (e) {
      debugPrint('Failed to send WebSocket message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send message. Check the connection and try again.'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }

    final messageData = message.toJson();
    messageData['customer_id'] = widget.customer_id;
    try {
      await DatabaseHelper.instance.insertChatMessage(messageData);
    } catch (e) {
      debugPrint('Failed to save outgoing message locally: $e');
    }

    _scrollToBottom();
  }

  void _toggleAttachmentMenu() {
    if (_fabAnimationController == null || _menuAnimationController == null) return;
    
    setState(() {
      _isAttachmentMenuOpen = !_isAttachmentMenuOpen;
    });
    
    if (_isAttachmentMenuOpen) {
      _fabAnimationController!.forward();
      _menuAnimationController!.forward();
    } else {
      _fabAnimationController!.reverse();
      _menuAnimationController!.reverse();
    }
  }

  Future<void> _pickImage() async {
    _toggleAttachmentMenu();
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _sendMessage(image.path);
    }
  }

  Future<void> _captureImage() async {
    _toggleAttachmentMenu();
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
    if (image != null) {
      _sendMessage(image.path);
    }
  }

  Future<void> _captureVideo() async {
    _toggleAttachmentMenu();
    final XFile? video = await _imagePicker.pickVideo(source: ImageSource.camera);
    if (video != null) {
      _sendMessage(video.path);
    }
  }

  Future<void> _pickFile() async {
    _toggleAttachmentMenu();
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      _sendMessage(result.files.single.path!);
    }
  }

  Widget _buildMessageBubble(Message message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      child: Row(
        mainAxisAlignment: message.is_from_user 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.is_from_user) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: const AssetImage('assets/gemini.png'),
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: !message.is_from_user 
                    ? const Color(0xFFE5E5EA)
                    : const Color.fromARGB(255, 246, 162, 204),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.is_from_user ? 4 : 20),
                  bottomRight: Radius.circular(message.is_from_user ? 20 : 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: message.is_from_user
                  ? MarkdownBody(
                      data: message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          height: 1.3,
                        ),
                        code: TextStyle(
                          backgroundColor: Colors.grey.shade200,
                          color: Colors.grey.shade800,
                          fontSize: 14,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        blockquote: TextStyle(
                          color: Colors.grey.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Colors.grey.shade400,
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                      selectable: true,
                    )
                  : MarkdownBody(
                      data: message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          height: 1.3,
                        ),
                        
                        codeblockDecoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        blockquote: const TextStyle(
                          color: Colors.white,
                          fontStyle: FontStyle.italic,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Colors.white.withOpacity(0.5),
                              width: 4,
                            ),
                          ),
                        ),
                      ),
                      selectable: true,
                    ),
            ),
          ),
          if (message.is_from_user) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundImage: const AssetImage('assets/woman.png'),
              backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required int index,
  }) {
    if (_menuAnimationController == null) return const SizedBox.shrink();
    
    return AnimatedBuilder(
      animation: _menuAnimationController!,
      builder: (context, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _menuAnimationController!,
          curve: Interval(
            0.1 * index,
            0.7 + (0.1 * index),
            curve: Curves.elasticOut,
          ),
        ));

        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _menuAnimationController!,
          curve: Interval(
            0.1 * index,
            0.5 + (0.1 * index),
            curve: Curves.easeOut,
          ),
        ));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: color,
                    borderRadius: BorderRadius.circular(28),
                    elevation: 4,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color.fromARGB(255, 229, 69, 149),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: const AssetImage('assets/woman.png'),
              backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.customerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
            color: Colors.grey,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _buildMessageBubble(_messages[index]),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Material(
                          color: const Color.fromARGB(255, 229, 69, 149),
                          borderRadius: BorderRadius.circular(24),
                          child: InkWell(
                            onTap: () {
                              if (_messageController.text.isNotEmpty) {
                                _sendMessage(_messageController.text);
                              }
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      // floatingActionButton: Stack(
      //   alignment: Alignment.bottomRight,
      //   children: [
      //     if (_isAttachmentMenuOpen) ...[
      //       _buildAttachmentButton(
      //         icon: Icons.attach_file,
      //         label: 'File',
      //         onTap: _pickFile,
      //         color: Colors.blue.shade500,
      //         index: 3,
      //       ),
      //       _buildAttachmentButton(
      //         icon: Icons.videocam,
      //         label: 'Video',
      //         onTap: _captureVideo,
      //         color: Colors.red.shade500,
      //         index: 2,
      //       ),
      //       _buildAttachmentButton(
      //         icon: Icons.camera_alt,
      //         label: 'Camera',
      //         onTap: _captureImage,
      //         color: Colors.green.shade500,
      //         index: 1,
      //       ),
      //       _buildAttachmentButton(
      //         icon: Icons.image,
      //         label: 'Gallery',
      //         onTap: _pickImage,
      //         color: Colors.purple.shade500,
      //         index: 0,
      //       ),
      //     ],
      //     AnimatedBuilder(
      //       animation: _fabAnimationController ?? AnimationController(vsync: this, duration: Duration.zero),
      //       builder: (context, child) {
      //         final animationValue = _fabAnimationController?.value ?? 0.0;
      //         return Transform.rotate(
      //           angle: animationValue * 0.785398, // 45 degrees in radians
      //           child: FloatingActionButton(
      //             onPressed: _toggleAttachmentMenu,
      //             backgroundColor: _isAttachmentMenuOpen 
      //                 ? Colors.grey.shade600 
      //                 : Theme.of(context).colorScheme.primary,
      //             elevation: 8,
      //             child: Icon(
      //               _isAttachmentMenuOpen ? Icons.close : Icons.add_photo_alternate,
      //               color: Colors.white,
      //             ),
      //           ),
      //         );
      //       },
      //     ),
      //   ],
      // ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel.sink.close();
    _audioPlayer.dispose();
    _videoController?.dispose();
    _fabAnimationController?.dispose();
    _menuAnimationController?.dispose();
    super.dispose();
  }
}

class SplashOrMain extends StatefulWidget {
  @override
  State<SplashOrMain> createState() => _SplashOrMainState();
}

class _SplashOrMainState extends State<SplashOrMain> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    if (_started) {
      return const ChatScreen(
        customer_id: 1,
        customerName: 'ชลธิชา',
      );
    }
    return WelcomePage(
      onStart: () {
        setState(() {
          _started = true;
        });
      },
    );
  }
}