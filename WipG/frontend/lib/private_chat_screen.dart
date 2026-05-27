import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';
import 'chat_provider.dart';

class PrivateChatScreen extends StatefulWidget {
  final Map friend;

  const PrivateChatScreen({super.key, required this.friend});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chat = Provider.of<ChatProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final friendId = widget.friend['_id'].toString();
      chat.setActivePrivateChat(friendId);
      chat.fetchPrivateHistory(friendId, auth.token ?? "");
    });
  }

  @override
  void dispose() {
    Provider.of<ChatProvider>(context, listen: false).setActivePrivateChat(null);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    final date = DateTime.tryParse(raw.toString())?.toLocal();
    if (date == null) return '';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$hour:$minute $day/$month';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    if (chat.privateMessages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.friend['username'] ?? "Chat")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: chat.privateMessages.length,
              itemBuilder: (ctx, i) {
                final Map<String, dynamic> m =
                    Map<String, dynamic>.from(chat.privateMessages[i]);

                String senderId = "";
                if (m['sender'] is Map) {
                  senderId = m['sender']['_id'].toString();
                } else {
                  senderId = m['sender'].toString();
                }

                final isMe = senderId == auth.userId;
                final isRevoked = m['isRevoked'] == true;

                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.indigo : Colors.grey[300],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isMe ? "Ban" : (widget.friend['username'] ?? "Ban be"),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isMe ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(m['createdAt']),
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            if (isMe && !isRevoked) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => chat.revokePrivateMessage(
                                  m['_id'].toString(),
                                  auth.userId ?? "",
                                ),
                                child: Text(
                                  "Thu hoi",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isMe ? Colors.white70 : Colors.black54,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isRevoked ? "Tin nhan da duoc thu hoi" : (m['message'] ?? ""),
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                            fontStyle:
                                isRevoked ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Nhap tin nhan...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.indigo),
                  onPressed: () {
                    if (_controller.text.isNotEmpty) {
                      chat.sendPrivateMessage(
                        senderId: auth.userId ?? "",
                        receiverId: widget.friend['_id'].toString(),
                        senderName: auth.username ?? "Me",
                        text: _controller.text,
                      );
                      _controller.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
