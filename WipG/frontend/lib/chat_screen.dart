import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_avatar.dart';
import 'auth_provider.dart';
import 'chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isCallMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<ChatProvider>(context, listen: false)
          .fetchRooms(auth.token ?? "");
    });
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

  Widget _buildUnreadDot(int unreadCount) {
    if (unreadCount <= 0) return const SizedBox.shrink();
    return Positioned(
      right: -2,
      top: -2,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  String? _findRoomMemberAvatar(
    Map? room,
    String senderId,
    String? ownUserId,
    String? ownAvatar,
  ) {
    if (senderId.isEmpty) return null;
    if (ownUserId != null && senderId == ownUserId) {
      return ownAvatar;
    }

    final members = room?['members'];
    if (members is List) {
      for (final member in members) {
        if (member['_id']?.toString() == senderId) {
          return member['avatar']?.toString();
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final myName = authProvider.username ?? "Khach";
    final currentRoom = chatProvider.rooms.cast<Map?>().firstWhere(
          (room) => room?['_id']?.toString() == chatProvider.currentRoomId,
          orElse: () => null,
        );
    final adminField = currentRoom?['admin'];
    final adminId = adminField is Map
        ? adminField['_id']?.toString()
        : adminField?.toString();
    final isAdmin = adminId != null && adminId == authProvider.userId;

    if (!isCallMode && chatProvider.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 70,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF202225)
                : const Color(0xFFE3E5E8),
            child: Column(
              children: [
                const SizedBox(height: 10),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 40),
                  onPressed: () => _showCreateRoomDialog(context),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: chatProvider.rooms.length,
                    itemBuilder: (context, index) {
                      final room = chatProvider.rooms[index];
                      final roomId = room['_id'].toString();
                      final unreadCount = chatProvider.unreadForRoom(roomId);
                      final isSelected = chatProvider.currentRoomId == roomId;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: InkWell(
                          onTap: () {
                            chatProvider.joinRoom(
                              roomId,
                              room['name'],
                              authProvider.token ?? "",
                            );
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor:
                                    isSelected ? Colors.indigo : Colors.grey[700],
                                child: Text(
                                  room['name'][0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              _buildUnreadDot(unreadCount),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    children: [
                      Icon(Icons.tag, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        chatProvider.currentRoomName ?? "Chon mot phong",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.person_add, color: Colors.indigo),
                        onPressed: () => _showInviteDialog(context, chatProvider),
                      ),
                      if (chatProvider.currentRoomId != null)
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'delete') {
                              await chatProvider.deleteRoom(
                                chatProvider.currentRoomId!,
                                authProvider.token ?? "",
                              );
                            }
                            if (value == 'leave') {
                              await chatProvider.leaveCurrentRoom(
                                authProvider.token ?? "",
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: isAdmin ? 'delete' : 'leave',
                              child: Text(isAdmin ? 'Xoa phong' : 'Roi phong'),
                            ),
                          ],
                        ),
                      _navButton(
                        Icons.chat,
                        "Chat",
                        !isCallMode,
                        () => setState(() => isCallMode = false),
                      ),
                      _navButton(
                        Icons.videocam,
                        "Goi",
                        isCallMode,
                        () => setState(() => isCallMode = true),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: isCallMode
                      ? _buildCallUI()
                      : _buildChatUI(
                          chatProvider,
                          authProvider.userId ?? "",
                          myName,
                          currentRoom,
                          authProvider.avatar,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatUI(
    ChatProvider chatProvider,
    String myUserId,
    String myName,
    Map? currentRoom,
    String? myAvatar,
  ) {
    if (chatProvider.currentRoomId == null) {
      return const Center(child: Text("Hay chon phong de chat"));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: chatProvider.messages.length,
            itemBuilder: (context, index) {
              final m = Map<String, dynamic>.from(chatProvider.messages[index]);
              final senderId = m['sender']?.toString() ?? '';
              final isMe = senderId == myUserId;
              final isRevoked = m['isRevoked'] == true;
              final senderName = m['senderName']?.toString() ?? "Unknown";
              final avatarUrl = _findRoomMemberAvatar(
                currentRoom,
                senderId,
                myUserId,
                myAvatar,
              );
              final isSystem = senderName == 'He thong';

              return Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAvatar(
                      imageUrl: avatarUrl,
                      fallbackText: senderName,
                      radius: 20,
                      backgroundColor: isSystem ? Colors.grey : Colors.indigo,
                      fallbackIcon: isSystem ? Icons.info_outline : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                senderName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(m['createdAt']),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              if (isMe && !isRevoked)
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'revoke') {
                                      chatProvider.revokeRoomMessage(
                                        m['_id'].toString(),
                                        chatProvider.currentRoomId!,
                                        myUserId,
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem<String>(
                                      value: 'revoke',
                                      child: Text('Thu hoi'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isRevoked ? "Tin nhan da duoc thu hoi" : (m['message'] ?? ""),
                            style: TextStyle(
                              fontStyle: isRevoked ? FontStyle.italic : FontStyle.normal,
                              color: isRevoked ? Colors.grey : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _buildMessageInput(chatProvider, myName),
      ],
    );
  }

  Widget _buildMessageInput(ChatProvider chatProvider, String myName) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: "Nhan tin tai #${chatProvider.currentRoomName ?? 'phong'}",
                border: InputBorder.none,
              ),
              onSubmitted: (val) => _sendMsg(chatProvider, myName),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.indigo),
            onPressed: () => _sendMsg(chatProvider, myName),
          ),
        ],
      ),
    );
  }

  void _sendMsg(ChatProvider chat, String name) {
    if (_msgController.text.isNotEmpty) {
      chat.sendMessage(_msgController.text, name);
      _msgController.clear();
    }
  }

  Widget _navButton(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: isActive ? Colors.indigo : Colors.grey),
      label: Text(
        label,
        style: TextStyle(color: isActive ? Colors.indigo : Colors.grey),
      ),
    );
  }

  Widget _buildCallUI() {
    return Container(
      color: const Color(0xFF2F3136),
      child: Center(
        child: Wrap(
          spacing: 40,
          children: [
            _voiceAvatar("Dang goi...", true),
            _voiceAvatar("Ban", false),
          ],
        ),
      ),
    );
  }

  Widget _voiceAvatar(String name, bool isSpeaking) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSpeaking ? Colors.green : Colors.transparent,
              width: 3,
            ),
          ),
          child: const CircleAvatar(
            radius: 40,
            child: Icon(Icons.person, size: 40),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showCreateRoomDialog(BuildContext context) {
    final nameController = TextEditingController();
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tao phong"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "Nhap ten phong..."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Huy"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                await Provider.of<ChatProvider>(context, listen: false)
                    .createRoom(nameController.text, auth.token ?? "");
                if (!mounted) return;
                navigator.pop();
              }
            },
            child: const Text("Tao ngay"),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, ChatProvider chatProvider) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    chatProvider.fetchMyFriends(auth.token ?? "");

    showDialog(
      context: context,
      builder: (context) => Consumer<ChatProvider>(
        builder: (context, chat, child) {
          final currentRoom = chat.rooms.cast<Map?>().firstWhere(
                (room) => room?['_id']?.toString() == chat.currentRoomId,
                orElse: () => null,
              );
          final memberIds = <String>{
            for (final member in (currentRoom?['members'] ?? []))
              member['_id'].toString(),
          };

          return AlertDialog(
            title: const Text("Moi ban be"),
            content: SizedBox(
              width: 400,
              height: 300,
              child: ListView.builder(
                itemCount: chat.myFriends.length,
                itemBuilder: (context, index) {
                  final friend = chat.myFriends[index];
                  final alreadyInvited =
                      memberIds.contains(friend['_id'].toString());

                  return ListTile(
                    leading: AppAvatar(
                      imageUrl: friend['avatar']?.toString(),
                      fallbackText: friend['username']?.toString() ?? '',
                      radius: 18,
                      backgroundColor: Colors.green,
                    ),
                    title: Text(friend['username']),
                    trailing: ElevatedButton(
                      onPressed: alreadyInvited
                          ? null
                          : () async {
                              await chat.inviteToRoom(
                                chat.currentRoomId!,
                                friend['_id'],
                                auth.token ?? "",
                              );
                              if (!mounted) return;
                              navigator.pop();
                            },
                      child: Text(alreadyInvited ? "Da moi" : "Moi"),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
