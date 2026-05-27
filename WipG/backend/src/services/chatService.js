const Message = require('../models/Message');
const PrivateMessage = require('../models/PrivateMessage');
const Room = require('../models/Room');
const User = require('../models/User');

class ChatService {
  async createRoom(name, adminId) {
    if (!name) throw new Error('Ten phong khong duoc de trong');
    const room = new Room({
      name,
      admin: adminId,
      members: [adminId],
    });
    return await room.save();
  }

  async getRooms(userId) {
    return await Room.find({ members: userId })
      .populate('admin', 'username email')
      .populate('members', 'username email avatar');
  }

  async saveMessage(roomId, senderId, senderName, message) {
    const msg = new Message({
      roomId,
      sender: senderId || undefined,
      senderName,
      message,
    });
    return await msg.save();
  }

  async createSystemMessage(roomId, message) {
    return await Message.create({
      roomId,
      senderName: 'He thong',
      message,
    });
  }

  async getMessageHistory(roomId) {
    return await Message.find({ roomId }).sort({ createdAt: 1 }).limit(50);
  }

  async addMemberToRoom(roomId, userId) {
    const room = await Room.findById(roomId);
    if (!room) throw new Error('Khong tim thay phong');

    const alreadyMember = room.members.some(
      (memberId) => memberId.toString() === userId.toString()
    );
    if (alreadyMember) {
      return await Room.findById(roomId)
        .populate('admin', 'username email')
        .populate('members', 'username email avatar');
    }

    return await Room.findByIdAndUpdate(
      roomId,
      { $addToSet: { members: userId } },
      { new: true }
    )
      .populate('admin', 'username email')
      .populate('members', 'username email avatar');
  }

  async leaveRoom(roomId, userId) {
    const room = await Room.findById(roomId);
    if (!room) throw new Error('Khong tim thay phong');

    const isMember = room.members.some(
      (memberId) => memberId.toString() === userId.toString()
    );
    if (!isMember) throw new Error('Ban khong o trong phong nay');

    room.members = room.members.filter(
      (memberId) => memberId.toString() !== userId.toString()
    );
    await room.save();

    const user = await User.findById(userId).select('username');
    const systemMessage = await this.createSystemMessage(
      roomId,
      `${user?.username ?? 'Mot thanh vien'} da roi phong`
    );

    return {
      room: await Room.findById(roomId)
        .populate('admin', 'username email')
        .populate('members', 'username email avatar'),
      systemMessage,
    };
  }

  async deleteRoom(roomId, userId) {
    const room = await Room.findById(roomId);
    if (!room) throw new Error('Khong tim thay phong');
    if (room.admin.toString() !== userId.toString()) {
      throw new Error('Chi chu phong moi co the xoa phong');
    }

    await Message.deleteMany({ roomId });
    await Room.findByIdAndDelete(roomId);
    return { roomId };
  }

  async getPrivateHistory(userId, friendId) {
    return await PrivateMessage.find({
      $or: [
        { sender: userId, receiver: friendId },
        { sender: friendId, receiver: userId },
      ],
    }).sort({ createdAt: 1 });
  }

  async savePrivateMessage(senderId, receiverId, message) {
    const newMsg = new PrivateMessage({
      sender: senderId,
      receiver: receiverId,
      message,
    });
    return await newMsg.save();
  }

  async revokeRoomMessage(messageId, userId) {
    const message = await Message.findOne({
      _id: messageId,
      sender: userId,
    });
    if (!message) throw new Error('Khong tim thay tin nhan de thu hoi');
    if (message.isRevoked) return message;

    message.isRevoked = true;
    message.revokedAt = new Date();
    await message.save();
    return message;
  }

  async revokePrivateMessage(messageId, userId) {
    const message = await PrivateMessage.findOne({
      _id: messageId,
      sender: userId,
    });
    if (!message) throw new Error('Khong tim thay tin nhan de thu hoi');
    if (message.isRevoked) return message;

    message.isRevoked = true;
    message.revokedAt = new Date();
    await message.save();
    return message;
  }
}

module.exports = new ChatService();
