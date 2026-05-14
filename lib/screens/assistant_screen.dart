import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, required this.timestamp});
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
  bool _hasUserMessages = false;

  static const _quickQuestions = [
    'Bugün ne yemeliyim?',
    'Uykumu nasıl düzeltebilirim?',
    'Stresimi nasıl azaltırım?',
    'Günlük su ihtiyacım ne kadar?',
    'Kilo vermek için öneriler',
    'Tansiyonum yüksek, ne yapmalıyım?',
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    setState(() => _isLoading = true);
    final history = await ApiService.fetchChatHistory(limit: 50);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (history.isNotEmpty) {
          // Geçmiş mesajları yükle (eskiden yeniye → ters çevir)
          for (final item in history.reversed) {
            _messages.insert(
              0,
              ChatMessage(
                text: item.content, 
                isUser: item.role == 'user',
                timestamp: DateTime.tryParse(item.createdAt)?.toLocal() ?? DateTime.now(),
              ),
            );
          }
        } else {
          // İlk kez açılıyor — karşılama mesajı
          _messages.add(
            ChatMessage(
              text:
                  "Merhaba! Ben AKSA Sağlık Asistanı. Size temel konularda sağlık ve yaşam tavsiyeleri verebilirim. (Tanı ve tedavi sağlayamam).\n\nNasıl hissediyorsunuz?",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isLoading = true;
      _hasUserMessages = true;
    });

    final res = await ApiService.sendAssistantMessage(text);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res != null) {
          _messages.insert(0, ChatMessage(text: res.reply, isUser: false, timestamp: DateTime.now()));
        } else {
          _messages.insert(
            0,
            ChatMessage(
              text: "Bağlantı hatası oluştu. Lütfen tekrar deneyin.",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header (navy gradient, tüm ekranlarla tutarlı) ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/app/dashboard'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sağlık Asistanı',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Yapay zeka destekli sağlık danışmanınız',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Sohbeti Temizle'),
                            content: const Text('Tüm mesajlar silinecek. Devam etmek istiyor musunuz?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  
                                  // ScaffoldMessenger'ı async gap öncesi yakala
                                  final messenger = ScaffoldMessenger.of(context);
                                  
                                  // Backend'den geçmişi sil
                                  final success = await ApiService.clearChatHistory();
                                  
                                  if (mounted) {
                                    if (success) {
                                      setState(() {
                                        _messages.clear();
                                        _hasUserMessages = false;
                                        _messages.add(ChatMessage(
                                          text: "Merhaba! Ben AKSA Sağlık Asistanı. Size temel konularda sağlık ve yaşam tavsiyeleri verebilirim. (Tanı ve tedavi sağlayamam).\n\nNasıl hissediyorsunuz?",
                                          isUser: false,
                                          timestamp: DateTime.now(),
                                        ));
                                      });
                                    } else {
                                      messenger.showSnackBar(
                                        const SnackBar(content: Text('Sohbet geçmişi silinirken bir hata oluştu.')),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
                                child: const Text('Temizle'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Mesajlar ──
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == 0) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20).copyWith(
                          bottomLeft: const Radius.circular(4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('Düşünüyor...', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[_isLoading ? index - 1 : index];
                return _buildChatBubble(msg, context);
              },
            ),
          ),

          // ── Hızlı Soru Önerileri ──
          if (!_hasUserMessages && !_isLoading)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Hızlı Sorular',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickQuestions.map((q) => GestureDetector(
                      onTap: () {
                        _controller.text = q;
                        _sendMessage();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          q,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),

          // ── Tıbbi Uyarı ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.accent.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Bu bilgiler tıbbi tavsiye niteliği taşımaz. Sağlık sorunlarınız için doktorunuza danışın.',
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),

          // ── Input Alanı ──
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 8,
              top: 8,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
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
                      hintText: 'Bir soru sorun...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.mic, color: AppColors.primary, size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesli giriş yakında eklenecek')));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.secondary, AppColors.secondaryDark],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
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
            bottomRight: msg.isUser
                ? const Radius.circular(4)
                : const Radius.circular(20),
            bottomLeft: !msg.isUser
                ? const Radius.circular(4)
                : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            MarkdownBody(
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
            const SizedBox(height: 6),
            Text(
              '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: msg.isUser ? Colors.white.withValues(alpha: 0.7) : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
