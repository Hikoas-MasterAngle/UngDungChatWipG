import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatProvider extends ChangeNotifier {
  late io.Socket socket;
  List messages = [];
  List rooms = [];
  List myFriends = [];
  List privateMessages = [];
  List<Map<String, dynamic>> notifications = [];

  final Map<String, int> _privateUnreadCounts = {};
  final Map<String, int> _roomUnreadCounts = {};

  String? currentRoomId;
  String? currentRoomName;
  String? _activePrivateChatUserId;
  String? _currentUserId;
  String? _joinedSocketRoomId;
  int _activeMainTab = 0;

  final String baseUrl = "http://localhost:5000";

  ChatProvider() {
    initSocket();
  }

  int get totalPrivateUnreadCount =>
      _privateUnreadCounts.values.fold(0, (sum, count) => sum + count);

  int get totalRoomUnreadCount =>
      _roomUnreadCounts.values.fold(0, (sum, count) => sum + count);

  int unreadForPrivateUser(String userId) => _privateUnreadCounts[userId] ?? 0;

  int unreadForRoom(String roomId) => _roomUnreadCounts[roomId] ?? 0;

  void initSocket() {
    socket = io.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();

    socket.on('receive_message', (data) {
      _handleIncomingRoomMessage(Map<String, dynamic>.from(data));
    });

    socket.on('receive_private_message', (data) {
      receivePrivateMessage(Map<String, dynamic>.from(data));
    });

    socket.on('room_message_revoked', (data) {
      _applyRoomRevocation(Map<String, dynamic>.from(data));
    });

    socket.on('private_message_revoked', (data) {
      _applyPrivateRevocation(Map<String, dynamic>.from(data));
    });

    socket.on('room_deleted', (data) {
      _handleRoomDeleted(Map<String, dynamic>.from(data));
    });
  }

  void registerUser(String? userId) {
    if (userId == null || userId.isEmpty) return;
    _currentUserId = userId;
    socket.emit('register_user', userId);
    debugPrint("Da dang ky socket cho user: $userId");
  }

  void setActiveMainTab(int index) {
    _activeMainTab = index;
    notifyListeners();
  }

  void setActivePrivateChat(String? friendId) {
    _activePrivateChatUserId = friendId;
    if (friendId != null && friendId.isNotEmpty) {
      _privateUnreadCounts.remove(friendId);
    }
    notifyListeners();
  }

  String roomNameForId(String roomId) {
    for (final room in rooms) {
      if (room is Map && room['_id']?.toString() == roomId) {
        return room['name']?.toString() ?? 'Phong chat';
      }
    }
    return 'Phong chat';
  }

  void markRoomAsRead(String roomId) {
    _roomUnreadCounts.remove(roomId);
    notifyListeners();
  }

  void markPrivateChatAsRead(String friendId) {
    _privateUnreadCounts.remove(friendId);
    notifyListeners();
  }

  void dismissNotification(Map<String, dynamic> notification) {
    notifications.remove(notification);
    notifyListeners();
  }

  String _extractUserId(dynamic rawUser) {
    if (rawUser is Map) {
      return rawUser['_id']?.toString() ?? '';
    }
    return rawUser?.toString() ?? '';
  }

  Map<String, dynamic> _markRevoked(Map<String, dynamic> message, DateTime? revokedAt) {
    return {
      ...message,
      'isRevoked': true,
      'revokedAt': revokedAt?.toIso8601String(),
    };
  }

  void _applyRoomRevocation(Map<String, dynamic> data) {
    final messageId = data['messageId']?.toString();
    if (messageId == null) return;

    messages = messages.map((message) {
      final current = Map<String, dynamic>.from(message);
      if (current['_id']?.toString() != messageId) return current;
      return _markRevoked(
        current,
        data['revokedAt'] != null ? DateTime.tryParse(data['revokedAt'].toString()) : null,
      );
    }).toList();
    notifyListeners();
  }

  void _applyPrivateRevocation(Map<String, dynamic> data) {
    final messageId = data['messageId']?.toString();
    if (messageId == null) return;

    privateMessages = privateMessages.map((message) {
      final current = Map<String, dynamic>.from(message);
      if (current['_id']?.toString() != messageId) return current;
      return _markRevoked(
        current,
        data['revokedAt'] != null ? DateTime.tryParse(data['revokedAt'].toString()) : null,
      );
    }).toList();
    notifyListeners();
  }

  void _handleRoomDeleted(Map<String, dynamic> data) {
    final roomId = data['roomId']?.toString();
    if (roomId == null) return;

    rooms = rooms.where((room) => room['_id'].toString() != roomId).toList();
    _roomUnreadCounts.remove(roomId);

    if (currentRoomId == roomId) {
      currentRoomId = null;
      currentRoomName = null;
      messages = [];
      if (_joinedSocketRoomId == roomId) {
        _joinedSocketRoomId = null;
      }
    }
    notifyListeners();
  }

  void _addNotification(Map<String, dynamic> notification) {
    notifications.insert(0, notification);
    if (notifications.length > 3) {
      notifications.removeLast();
    }

    Future.delayed(const Duration(seconds: 5), () {
      if (notifications.contains(notification)) {
        notifications.remove(notification);
        notifyListeners();
      }
    });
  }

  void _handleIncomingRoomMessage(Map<String, dynamic> data) {
    final roomId = data['roomId']?.toString();
    if (roomId == null || roomId.isEmpty) return;

    final senderId = _extractUserId(data['sender']);
    final isOwnMessage = _currentUserId != null && senderId == _currentUserId;
    final isViewingThisRoom = _activeMainTab == 0 && currentRoomId == roomId;

    if (isViewingThisRoom) {
      messages.add(data);
      notifyListeners();
      return;
    }

    if (isOwnMessage) return;

    _roomUnreadCounts[roomId] = (_roomUnreadCounts[roomId] ?? 0) + 1;
    _addNotification({
      'type': 'room',
      'roomId': roomId,
      'roomName': roomNameForId(roomId),
      'senderName': data['senderName'] ?? 'Nguoi dung',
      'message': data['message'] ?? '',
    });
    notifyListeners();
  }

  Future<void> joinRoom(String roomId, String roomName, String token) async {
    if (_joinedSocketRoomId != null && _joinedSocketRoomId != roomId) {
      socket.emit('leave_room', _joinedSocketRoomId);
    }
    currentRoomId = roomId;
    currentRoomName = roomName;
    messages = [];
    _roomUnreadCounts.remove(roomId);
    notifyListeners();

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/chat/history/$roomId'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        messages = jsonDecode(res.body);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Loi load lich su phong: $e");
    }

    socket.emit('join_room', roomId);
    _joinedSocketRoomId = roomId;
  }

  Future<void> fetchPrivateHistory(String friendId, String token) async {
    _activePrivateChatUserId = friendId;
    privateMessages = [];
    _privateUnreadCounts.remove(friendId);
    notifyListeners();

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/chat/private/history/$friendId'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        privateMessages = jsonDecode(res.body);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Loi load lich su chat 1-1: $e");
    }
  }

  void sendPrivateMessage({
    required String senderId,
    required String receiverId,
    required String senderName,
    required String text,
  }) {
    if (text.trim().isEmpty) return;

    socket.emit('send_private_message', {
      'senderId': senderId,
      'receiverId': receiverId,
      'senderName': senderName,
      'message': text,
    });
  }

  void receivePrivateMessage(Map<String, dynamic> data) {
    final senderId = _extractUserId(data['sender']);
    final isOwnMessage = _currentUserId != null && senderId == _currentUserId;
    final relevantUserId =
        isOwnMessage ? _extractUserId(data['receiver']) : senderId;
    final isViewingThisChat =
        _activeMainTab == 1 && _activePrivateChatUserId == relevantUserId;

    if (isViewingThisChat) {
      privateMessages.add(data);
      notifyListeners();
      return;
    }

    if (isOwnMessage) return;

    _privateUnreadCounts[relevantUserId] =
        (_privateUnreadCounts[relevantUserId] ?? 0) + 1;
    _addNotification({
      'type': 'private',
      'friendId': relevantUserId,
      'friendName': data['senderName'] ?? 'Nguoi dung',
      'senderName': data['senderName'] ?? 'Nguoi dung',
      'message': data['message'] ?? '',
    });
    notifyListeners();
  }

  void revokeRoomMessage(String messageId, String roomId, String userId) {
    socket.emit('revoke_room_message', {
      'messageId': messageId,
      'roomId': roomId,
      'userId': userId,
    });
  }

  void revokePrivateMessage(String messageId, String userId) {
    socket.emit('revoke_private_message', {
      'messageId': messageId,
      'userId': userId,
    });
  }

  Future<void> fetchRooms(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/chat/my-rooms'),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode == 200) {
      rooms = jsonDecode(res.body);
      notifyListeners();
    }
  }

  Future<void> fetchMyFriends(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/users/profile'),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode == 200) {
      myFriends = jsonDecode(res.body)['friends'] ?? [];
      notifyListeners();
    }
  }

  void sendMessage(String text, String senderName) {
    if (currentRoomId == null || text.trim().isEmpty) return;
    socket.emit('send_message', {
      'roomId': currentRoomId,
      'senderId': _currentUserId,
      'senderName': senderName,
      'message': text,
    });
  }

  Future<void> createRoom(String name, String token) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/chat/create'),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"name": name}),
    );
    if (res.statusCode == 201) {
      await fetchRooms(token);
    }
  }

  Future<void> inviteToRoom(String roomId, String userId, String token) async {
    await http.post(
      Uri.parse('$baseUrl/api/chat/invite'),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"roomId": roomId, "userId": userId}),
    );
    await fetchRooms(token);
  }

  Future<void> leaveCurrentRoom(String token) async {
    if (currentRoomId == null) return;
    final roomId = currentRoomId!;
    await http.post(
      Uri.parse('$baseUrl/api/chat/leave'),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"roomId": roomId}),
    );
    socket.emit('leave_room', roomId);
    if (_joinedSocketRoomId == roomId) {
      _joinedSocketRoomId = null;
    }
    currentRoomId = null;
    currentRoomName = null;
    messages = [];
    _roomUnreadCounts.remove(roomId);
    await fetchRooms(token);
    notifyListeners();
  }

  Future<void> deleteRoom(String roomId, String token) async {
    await http.delete(
      Uri.parse('$baseUrl/api/chat/$roomId'),
      headers: {"Authorization": "Bearer $token"},
    );
    socket.emit('leave_room', roomId);
    if (_joinedSocketRoomId == roomId) {
      _joinedSocketRoomId = null;
    }
    rooms = rooms.where((room) => room['_id'].toString() != roomId).toList();
    if (currentRoomId == roomId) {
      currentRoomId = null;
      currentRoomName = null;
      messages = [];
    }
    _roomUnreadCounts.remove(roomId);
    notifyListeners();
  }
}
