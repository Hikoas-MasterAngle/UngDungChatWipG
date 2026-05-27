import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';
import 'chat_provider.dart';
import 'chat_screen.dart';
import 'friends_screen.dart';
import 'private_chat_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const ChatScreen(),
    const FriendsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final chat = Provider.of<ChatProvider>(context, listen: false);
      chat.registerUser(auth.userId);
      chat.setActiveMainTab(_currentIndex);
    });
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);

    chat.dismissNotification(notification);

    if (notification['type'] == 'room') {
      setState(() {
        _currentIndex = 0;
      });
      chat.setActiveMainTab(0);
      await chat.joinRoom(
        notification['roomId'].toString(),
        notification['roomName']?.toString() ?? 'Phong chat',
        auth.token ?? '',
      );
      return;
    }

    final friend = {
      '_id': notification['friendId'],
      'username': notification['friendName'] ?? notification['senderName'],
    };

    setState(() {
      _currentIndex = 1;
    });
    chat.setActiveMainTab(1);
    chat.markPrivateChatAsRead(notification['friendId'].toString());

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PrivateChatScreen(friend: friend)),
    );
  }

  Widget _buildTabIcon({
    required IconData icon,
    required int unreadCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          _pages[_currentIndex],
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: chat.notifications
                      .map((msg) => _buildNotifyBox(msg))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          chat.setActiveMainTab(index);
        },
        items: [
          BottomNavigationBarItem(
            icon: _buildTabIcon(
              icon: Icons.chat,
              unreadCount: chat.totalRoomUnreadCount,
            ),
            label: "Chat",
          ),
          BottomNavigationBarItem(
            icon: _buildTabIcon(
              icon: Icons.people,
              unreadCount: chat.totalPrivateUnreadCount,
            ),
            label: "Ban be",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Cai dat",
          ),
        ],
      ),
    );
  }

  Widget _buildNotifyBox(Map<String, dynamic> msg) {
    final isRoom = msg['type'] == 'room';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openNotification(msg),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ListTile(
              leading: const Icon(Icons.message, color: Colors.white),
              title: Text(
                isRoom
                    ? "${msg['senderName']} trong ${msg['roomName']}"
                    : msg['friendName']?.toString() ?? 'Nguoi dung',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                msg['message']?.toString() ?? '',
                style: const TextStyle(color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
