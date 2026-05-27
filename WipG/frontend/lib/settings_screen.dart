import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';
import 'chat_provider.dart';
import 'main.dart';
import 'theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingAvatar = false;

  Future<void> _submitProfileUpdate({
    String? username,
    XFile? avatarFile,
    String? successMessage,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('http://localhost:5000/api/users/update-profile'),
      );
      request.headers['Authorization'] = 'Bearer ${auth.token ?? ""}';

      if (username != null && username.trim().isNotEmpty) {
        request.fields['username'] = username.trim();
      }

      if (avatarFile != null) {
        final bytes = await avatarFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'avatar',
            bytes,
            filename: avatarFile.name,
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final user = jsonDecode(response.body)['user'];
        await auth.updateProfile(
          username: user['username'],
          avatar: user['avatar'],
        );
        await chat.fetchRooms(auth.token ?? "");
        await chat.fetchMyFriends(auth.token ?? "");
        if (successMessage != null) {
          messenger.showSnackBar(
            SnackBar(content: Text(successMessage)),
          );
        }
        return;
      }

      final error = jsonDecode(response.body)['error'] ?? 'Co loi xay ra';
      messenger.showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Khong the cap nhat profile')),
      );
    }
  }

  Future<void> _updateName() async {
    await _submitProfileUpdate(
      username: _nameController.text,
      successMessage: 'Da doi ten thanh cong!',
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (file == null) return;

    setState(() {
      _isUploadingAvatar = true;
    });

    await _submitProfileUpdate(
      username: _nameController.text,
      avatarFile: file,
      successMessage: 'Da cap nhat avatar!',
    );

    if (!mounted) return;
    setState(() {
      _isUploadingAvatar = false;
    });
  }

  Widget _buildAvatar(String? avatarUrl) {
    return GestureDetector(
      onLongPress: _isUploadingAvatar ? null : _pickAndUploadAvatar,
      child: Column(
        children: [
          Container(
            width: 108,
            height: 108,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.indigo, width: 3),
              color: Colors.indigo.withAlpha(20),
            ),
            child: ClipOval(
              child: Container(
                color: Colors.grey[200],
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.person, size: 52, color: Colors.indigo),
                          );
                        },
                      )
                    : const Center(
                        child: Icon(Icons.person, size: 52, color: Colors.indigo),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isUploadingAvatar ? 'Dang tai avatar...' : 'Nhan giu avatar de doi anh',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    if (_nameController.text != (auth.username ?? "")) {
      _nameController.text = auth.username ?? "";
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildAvatar(auth.avatar),
          const SizedBox(height: 12),
          Text(
            auth.username ?? "Nguoi dung",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            auth.email ?? "",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: "Ten hien thi moi",
              suffixIcon: IconButton(
                icon: const Icon(Icons.save, color: Colors.indigo),
                onPressed: _updateName,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            title: const Text("Che do toi (Dark Mode)"),
            value: theme.isDarkMode,
            onChanged: (val) => theme.toggleTheme(),
            secondary: Icon(theme.isDarkMode ? Icons.dark_mode : Icons.light_mode),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await auth.logout();
                if (!mounted) return;
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text("DANG XUAT", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
