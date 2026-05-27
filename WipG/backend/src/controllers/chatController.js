const chatService = require('../services/chatService');

class ChatController {
  async createRoom(req, res) {
    try {
      const { name } = req.body;
      const adminId = req.user.id;
      const room = await chatService.createRoom(name, adminId);
      res.status(201).json(room);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async getRooms(req, res) {
    try {
      const rooms = await chatService.getRooms(req.user.id);
      res.status(200).json(rooms);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async getMessages(req, res) {
    try {
      const { roomId } = req.params;
      const messages = await chatService.getMessageHistory(roomId);
      res.status(200).json(messages);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async inviteMember(req, res) {
    try {
      const { roomId, userId } = req.body;
      const result = await chatService.addMemberToRoom(roomId, userId);
      res.json({ message: 'Da them ban vao phong thanh cong', room: result });
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async leaveRoom(req, res) {
    try {
      const { roomId } = req.body;
      const result = await chatService.leaveRoom(roomId, req.user.id);
      const io = req.app.get('io');
      io.to(roomId).emit('receive_message', result.systemMessage);
      res.json({ message: 'Da roi phong', room: result.room });
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async deleteRoom(req, res) {
    try {
      const { roomId } = req.params;
      await chatService.deleteRoom(roomId, req.user.id);
      const io = req.app.get('io');
      io.to(roomId).emit('room_deleted', { roomId });
      res.json({ message: 'Da xoa phong', roomId });
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }
}

module.exports = new ChatController();
