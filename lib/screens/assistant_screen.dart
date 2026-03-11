import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  
  ChatMessage({required this.text, required this.isUser});
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Karşılama mesajı
    _messages.add(ChatMessage(
      text: "Merhaba! Ben AKSA Sağlık Asistanı. Size temel konularda sağlık ve yaşam tavsiyeleri verebilirim. (Tanı ve tedavi sağlayamam).\n\nNasıl hissediyorsunuz?",
      isUser: false,
    ));
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    final res = await ApiService.sendAssistantMessage(text);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res != null) {
          _messages.insert(0, ChatMessage(text: res.reply, isUser: false));
        } else {
          _messages.insert(0, ChatMessage(
            text: "Bağlantı hatası oluştu. Lütfen tekrar deneyin.", 
            isUser: false
          ));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Sağlık Asistanı'),
        backgroundColor: AppColors.secondary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/app/dashboard'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // En yeni mesaj altta
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == 0) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.secondary),
                    ),
                  );
                }
                
                final msg = _messages[_isLoading ? index - 1 : index];
                return _buildChatBubble(msg, context);
              },
            ),
          ),
          
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 8,
              top: 8,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Şikayetinizi yazın (örn: başım ağrıyor)...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.secondary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage msg, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: msg.isUser ? AppColors.secondary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(4) : const Radius.circular(20),
            bottomLeft: !msg.isUser ? const Radius.circular(4) : const Radius.circular(20),
          ),
        ),
        child: MarkdownBody(
          data: msg.text,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              color: msg.isUser ? Colors.white : cs.onSurface,
              fontSize: 15,
              height: 1.4,
            ),
            strong: TextStyle(
              color: msg.isUser ? Colors.white : cs.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            listBullet: TextStyle(
              color: msg.isUser ? Colors.white : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
