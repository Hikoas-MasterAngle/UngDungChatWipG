import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'app_avatar.dart';
import 'auth_provider.dart';
import 'chat_provider.dart';
import 'private_chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? searchResult;
  List friendRequests = [];
  List friends = [];
  List sentRequests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chat = Provider.of<ChatProvider>(context, listen: false);
      chat.socket.on('new_friend_request', (data) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? "Co loi moi ket ban moi"),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      });
    });
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse('http://localhost:5000/api/users/profile'),
        headers: {"Authorization": "Bearer ${auth.token}"},
      );

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          friendRequests = data['friendRequests'] ?? [];
          sentRequests = data['sentRequests'] ?? [];
          friends = data['friends'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  Future<void> _postAction(String url, Map<String, dynamic> body, String success) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final res = await http.post(
      Uri.parse(url),
      headers: {
        "Authorization": "Bearer ${auth.token}",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (!mounted) return;

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
      await _loadData();
      if (searchResult != null) {
        await searchUser(_searchController.text);
      }
      return;
    }

    final error = jsonDecode(res.body)['error'] ?? "Co loi xay ra";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }

  Future<void> sendRequest(String targetEmail, String token) async {
    final res = await http.post(
      Uri.parse('http://localhost:5000/api/users/request'),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"targetEmail": targetEmail}),
    );

    if (!mounted) return;

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Da gui loi moi ket ban!")),
      );
      await _loadData();
      await searchUser(targetEmail);
    } else {
      final error = jsonDecode(res.body)['error'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> acceptFriend(String friendId) async {
    await _postAction(
      'http://localhost:5000/api/users/accept',
      {"friendId": friendId},
      "Da tro thanh ban be!",
    );
  }

  Future<void> declineFriend(String friendId) async {
    await _postAction(
      'http://localhost:5000/api/users/decline',
      {"friendId": friendId},
      "Da tu choi loi moi ket ban!",
    );
  }

  Future<void> cancelFriendRequest(String friendId) async {
    await _postAction(
      'http://localhost:5000/api/users/cancel-request',
      {"friendId": friendId},
      "Da huy loi moi ket ban!",
    );
  }

  Future<void> unfriend(String friendId) async {
    await _postAction(
      'http://localhost:5000/api/users/unfriend',
      {"friendId": friendId},
      "Da huy ket ban!",
    );
  }

  Future<void> searchUser(String email) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.get(
        Uri.parse('http://localhost:5000/api/users/search?email=$email'),
        headers: {"Authorization": "Bearer ${auth.token}"},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() => searchResult = jsonDecode(res.body));
      } else {
        setState(() => searchResult = null);
      }
    } catch (e) {
      debugPrint("Error searching user: $e");
    }
  }

  bool _containsUser(List list, String userId) {
    return list.any((item) => item['_id'].toString() == userId);
  }

  String _searchStatus(AuthProvider auth) {
    if (searchResult == null) return '';
    final userId = searchResult!['_id'].toString();
    if (userId == (auth.userId ?? '')) return 'self';
    if (_containsUser(friends, userId)) return 'friend';
    if (_containsUser(sentRequests, userId)) return 'sent';
    if (_containsUser(friendRequests, userId)) return 'received';
    return 'new';
  }

  Widget _buildUnreadDot(int unreadCount) {
    if (unreadCount <= 0) return const SizedBox.shrink();
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchArea(auth),
          const SizedBox(height: 30),
          _buildReceivedRequests(),
          const SizedBox(height: 30),
          _buildSentRequests(),
          const SizedBox(height: 30),
          _buildFriendsList(),
        ],
      ),
    );
  }

  Widget _buildSearchArea(AuthProvider auth) {
    final status = _searchStatus(auth);
    final disabled = status == 'self' || status == 'friend' || status == 'sent';

    String buttonText = "Ket ban";
    if (status == 'self') buttonText = "Chinh ban";
    if (status == 'friend') buttonText = "Da ket ban";
    if (status == 'sent') buttonText = "Da moi";
    if (status == 'received') buttonText = "Da gui cho ban";

    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Nhap email tim ban moi...",
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => searchUser(_searchController.text),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        if (searchResult != null)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.indigo.withAlpha(25),
            child: ListTile(
              title: Text(
                searchResult!['username'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(searchResult!['email']),
              trailing: ElevatedButton(
                onPressed: disabled
                    ? null
                    : () => sendRequest(searchResult!['email'], auth.token ?? ""),
                child: Text(buttonText),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReceivedRequests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "LOI MOI KET BAN (${friendRequests.length})",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: friendRequests.length,
          itemBuilder: (context, index) {
            final req = friendRequests[index];
            return ListTile(
              leading: AppAvatar(
                imageUrl: req['avatar']?.toString(),
                fallbackText: req['username']?.toString() ?? '',
                radius: 20,
                backgroundColor: Colors.indigo,
              ),
              title: Text(req['username'] ?? "Nguoi dung"),
              subtitle: const Text("Muon ket ban voi ban"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => acceptFriend(req['_id']),
                    child: const Text("Chap nhan"),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => declineFriend(req['_id']),
                    child: const Text("Tu choi"),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSentRequests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "LOI MOI DA GUI (${sentRequests.length})",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sentRequests.length,
          itemBuilder: (context, index) {
            final req = sentRequests[index];
            return ListTile(
              leading: AppAvatar(
                imageUrl: req['avatar']?.toString(),
                fallbackText: req['username']?.toString() ?? '',
                radius: 20,
                backgroundColor: Colors.indigo,
              ),
              title: Text(req['username'] ?? "Nguoi dung"),
              subtitle: const Text("Dang cho phan hoi..."),
              trailing: TextButton(
                onPressed: () => cancelFriendRequest(req['_id']),
                child: const Text("Huy", style: TextStyle(color: Colors.red)),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFriendsList() {
    final chat = Provider.of<ChatProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "BAN BE (${friends.length})",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            final friendId = friend['_id'].toString();
            final unreadCount = chat.unreadForPrivateUser(friendId);

            return ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                    imageUrl: friend['avatar']?.toString(),
                    fallbackText: friend['username']?.toString() ?? '',
                    radius: 20,
                    backgroundColor: Colors.green,
                  ),
                  Positioned(
                    right: -1,
                    top: -1,
                    child: _buildUnreadDot(unreadCount),
                  ),
                ],
              ),
              title: Text(friend['username'] ?? "Ban be"),
              subtitle: Text(friend['email'] ?? "Nhan de nhan tin"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unreadCount > 0)
                    Text(
                      "$unreadCount",
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chat_bubble_outline, color: Colors.indigo),
                ],
              ),
              onTap: () {
                chat.markPrivateChatAsRead(friendId);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrivateChatScreen(friend: friend),
                  ),
                );
              },
              onLongPress: () => _showFriendActions(friend),
            );
          },
        ),
      ],
    );
  }

  void _showFriendActions(Map friend) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: const Text('Huy ket ban'),
              onTap: () async {
                Navigator.pop(context);
                await unfriend(friend['_id'].toString());
              },
            ),
          ],
        ),
      ),
    );
  }
}
