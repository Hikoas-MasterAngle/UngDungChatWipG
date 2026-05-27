const cors = require('cors');
const express = require('express');
const http = require('http');
const mongoose = require('mongoose');
const { Server } = require('socket.io');

const chatService = require('./src/services/chatService');
require('dotenv').config();

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

app.use(cors());
app.use(express.json());

const MONGO_URI =
  process.env.MONGO_URI ||
  'mongodb://admin:<db_password>@ac-7bjqcwb-shard-00-00.yowh2rg.mongodb.net:27017,ac-7bjqcwb-shard-00-01.yowh2rg.mongodb.net:27017,ac-7bjqcwb-shard-00-02.yowh2rg.mongodb.net:27017/?ssl=true&replicaSet=atlas-26g5vz-shard-0&authSource=admin&appName=Cluster0';
const userSocketMap = {};

mongoose
  .connect(MONGO_URI)
  .then(() => console.log('MongoDB Atlas connected successfully'))
  .catch((err) => console.error('MongoDB connection error:', err));

app.use('/api/auth', require('./src/routes/authRoutes'));
app.use('/api/users', require('./src/routes/userRoutes'));
app.use('/api/chat', require('./src/routes/chatRoutes'));
app.set('io', io);

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('register_user', (userId) => {
    if (!userId) return;
    userSocketMap[userId] = socket.id;
    socket.data.userId = userId;
    console.log(`Registered ${userId} -> ${socket.id}`);
  });

  socket.on('join_room', (roomId) => {
    socket.join(roomId);
    console.log(`Socket ${socket.id} joined room ${roomId}`);
  });

  socket.on('leave_room', (roomId) => {
    socket.leave(roomId);
    console.log(`Socket ${socket.id} left room ${roomId}`);
  });

  socket.on('send_message', async (data) => {
    try {
      const savedMsg = await chatService.saveMessage(
        data.roomId,
        data.senderId,
        data.senderName,
        data.message
      );
      io.to(data.roomId).emit('receive_message', savedMsg);
    } catch (e) {
      console.error('Group chat error:', e);
    }
  });

  socket.on('send_private_message', async (data) => {
    try {
      const savedMsg = await chatService.savePrivateMessage(
        data.senderId,
        data.receiverId,
        data.message
      );
      const payload = {
        ...savedMsg.toObject(),
        senderName: data.senderName,
      };

      const senderSocketId = userSocketMap[data.senderId];
      const targetSocketId = userSocketMap[data.receiverId];

      if (senderSocketId) {
        io.to(senderSocketId).emit('receive_private_message', payload);
      }
      if (targetSocketId && targetSocketId !== senderSocketId) {
        io.to(targetSocketId).emit('receive_private_message', payload);
      }
    } catch (e) {
      console.error('Private chat error:', e);
    }
  });

  socket.on('revoke_room_message', async (data) => {
    try {
      const revokedMessage = await chatService.revokeRoomMessage(
        data.messageId,
        data.userId
      );
      io.to(revokedMessage.roomId).emit('room_message_revoked', {
        messageId: revokedMessage._id.toString(),
        roomId: revokedMessage.roomId,
        isRevoked: true,
        revokedAt: revokedMessage.revokedAt,
      });
    } catch (e) {
      console.error('Room revoke error:', e);
    }
  });

  socket.on('revoke_private_message', async (data) => {
    try {
      const revokedMessage = await chatService.revokePrivateMessage(
        data.messageId,
        data.userId
      );
      const payload = {
        messageId: revokedMessage._id.toString(),
        senderId: revokedMessage.sender.toString(),
        receiverId: revokedMessage.receiver.toString(),
        isRevoked: true,
        revokedAt: revokedMessage.revokedAt,
      };

      const senderSocketId = userSocketMap[payload.senderId];
      const receiverSocketId = userSocketMap[payload.receiverId];

      if (senderSocketId) {
        io.to(senderSocketId).emit('private_message_revoked', payload);
      }
      if (receiverSocketId && receiverSocketId !== senderSocketId) {
        io.to(receiverSocketId).emit('private_message_revoked', payload);
      }
    } catch (e) {
      console.error('Private revoke error:', e);
    }
  });

  socket.on('disconnect', () => {
    const userId = socket.data.userId;
    if (userId && userSocketMap[userId] === socket.id) {
      delete userSocketMap[userId];
    }
    console.log('User disconnected:', socket.id);
  });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});
