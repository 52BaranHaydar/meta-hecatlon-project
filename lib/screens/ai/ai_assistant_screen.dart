import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/emergency_112_button.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String? source;
  final bool isEmergencyFallback;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.source,
    this.isEmergencyFallback = false,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Merhaba! Ben Meta Llama 3 tabanlı Afet ve İlk Yardım Asistanıyım. AFAD, Kızılay ve resmi acil durum kılavuzlarıyla eğitildim. Deprem anı, tahliye, güvenli toplanma alanları ve ilk yardım hakkında bana dilediğiniz soruyu sorabilirsiniz.',
      isUser: false,
      source: 'AFAD Afet ve Acil Durum Yönetim Başkanlığı Bilgi Tabanı',
    ),
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String query) {
    if (query.trim().isEmpty) return;

    final userMsg = ChatMessage(text: query.trim(), isUser: true);
    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _textController.clear();
    _scrollToBottom();

    // Simulate Meta Llama RAG inference
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;

      final lower = query.toLowerCase();
      ChatMessage botReply;

      if (lower.contains('nefes') || lower.contains('kalp') || lower.contains('öl') || lower.contains('bilinç')) {
        botReply = ChatMessage(
          text: '🚨 ACİL DURUM TESPİT EDİLDİ! Solunum durması veya bilinç kaybı şüphesinde zaman kaybetmeden hemen 112 Acil Çağrı Merkezini arayınız veya üstteki kırmızı 112 butonuna basınız. Hastayı düz ve sert bir zemine yatırıp baş-çene pozisyonu ile hava yolunu açık tutunuz.',
          isUser: false,
          isEmergencyFallback: true,
          source: 'T.C. Sağlık Bakanlığı Acil Sağlık Hizmetleri Protokolü',
        );
      } else if (lower.contains('enkaz') || lower.contains('altında') || lower.contains('sıkış')) {
        botReply = ChatMessage(
          text: 'Enkaz altındaysanız:\n1. Enerjinizi koruyun, panik yapmayın ve tozdan korunmak için ağzınızı kumaşla örtün.\n2. Bağırmak yerine yakınınızdaki boru veya sert nesnelere periyodik olarak vurun (tık tık sesi dinleme cihazlarına daha net iletilir).\n3. Kibrit veya çakmak ASLA yakmayın (gaz sızıntısı riski).\n4. Dışarıdan arama kurtarma sesleri duyduğunuzda varlığınızı belli edin.',
          isUser: false,
          source: 'AFAD Enkaz Altında Hayatta Kalma Kılavuzu',
        );
      } else if (lower.contains('su') || lower.contains('içme') || lower.contains('gıda')) {
        botReply = ChatMessage(
          text: 'Şebeke suları afet sonrasında kirlenmiş olabilir. Sadece kapalı şişe sularını içiniz. Şişe su yoksa, suyu en az 1 dakika kaynatıp soğutarak tüketiniz. Açıkta kalmış bozulabilir gıdaları tüketmeyiniz.',
          isUser: false,
          source: 'Dünya Sağlık Örgütü (WHO) Afet Hijyen Rehberi',
        );
      } else if (lower.contains('kan') || lower.contains('yara') || lower.contains('turnike')) {
        botReply = ChatMessage(
          text: 'Ciddi kanamalarda yara üzerine temiz bir bez veya giysi parçasıyla doğrudan ve kuvvetli basınç uygulayınız. Kanama durmazsa basıncı gevşetmeden bezin üzerine ek bez sarınız. Turnikeyi yalnızca uzuv kopması veya kontrol edilemeyen şiddetli fışkıran atardamar kanamalarında uygulayınız ve saatini not ediniz.',
          isUser: false,
          source: 'Türk Kızılayı Temel İlk Yardım El Kitabı',
        );
      } else {
        botReply = ChatMessage(
          text: 'Deprem sonrasında binanızı terk ederken elektrik şalterini ve doğalgaz ana vanasını kapatınız. Asansör kesinlikle kullanmayınız. Merdivenlerden dikkatle inerek size en yakın toplanma alanına (harita sekmesinde görebilirsiniz) intikal ediniz.',
          isUser: false,
          source: 'AFAD Afet Farkındalık Kılavuzu 2024',
        );
      }

      setState(() {
        _messages.add(botReply);
        _isTyping = false;
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: const [
            Icon(Icons.auto_awesome, color: AppColors.primaryBlue, size: 22),
            SizedBox(width: 8),
            Text(
              'Meta Llama 3 Asistanı',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        actions: const [
          Emergency112Button(compact: true),
        ],
      ),
      body: Column(
        children: [
          // Quick Scenario Bar (Spacious)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _quickPromptChip('🩹 Kanamaya İlk Yardım'),
                  _quickPromptChip('🏚️ Enkaz Altında Ne Yapmalı?'),
                  _quickPromptChip('💧 Güvenli İçme Suyu'),
                  _quickPromptChip('🚪 Deprem Anı Tahliye'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Meta Llama 3 yanıt hazırlıyor (RAG)...',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          // Input Bar (Generous padding, breathable)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _textController,
                        onSubmitted: _sendMessage,
                        decoration: const InputDecoration(
                          hintText: 'Bir acil durum sorusu sorun...',
                          hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton.small(
                    heroTag: 'chat_send_btn',
                    onPressed: () => _sendMessage(_textController.text),
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    child: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickPromptChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: AppColors.border),
        onPressed: () => _sendMessage(label),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(18).copyWith(bottomRight: const Radius.circular(4)),
            boxShadow: [
              BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    // Bot Response Bubble
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 36),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: msg.isEmergencyFallback ? const Color(0xFFFEF2F2) : Colors.white,
          borderRadius: BorderRadius.circular(20).copyWith(topLeft: const Radius.circular(4)),
          border: Border.all(
            color: msg.isEmergencyFallback ? AppColors.emergencyRed : AppColors.border,
            width: msg.isEmergencyFallback ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  msg.isEmergencyFallback ? Icons.emergency_rounded : Icons.auto_awesome,
                  size: 16,
                  color: msg.isEmergencyFallback ? AppColors.emergencyRed : AppColors.primaryBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  msg.isEmergencyFallback ? '112 Acil Yönlendirmesi' : 'Meta Llama 3',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: msg.isEmergencyFallback ? AppColors.emergencyRed : AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: msg.isEmergencyFallback ? const Color(0xFF991B1B) : AppColors.textPrimary,
                fontWeight: msg.isEmergencyFallback ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (msg.source != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 12, color: AppColors.success),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        msg.source!,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
