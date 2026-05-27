const express = require('express');

const chatController = require('../controllers/chatController');
const authMiddleware = require('../middlewares/authMiddleware');

const router = express.Router();

router.post('/create', authMiddleware, chatController.createRoom);
router.get('/my-rooms', authMiddleware, chatController.getRooms);
router.get('/history/:roomId', authMiddleware, chatController.getMessages);
router.post('/invite', authMiddleware, (req, res) =>
  chatController.inviteMember(req, res)
);
router.post('/leave', authMiddleware, (req, res) =>
  chatController.leaveRoom(req, res)
);
router.delete('/:roomId', authMiddleware, (req, res) =>
  chatController.deleteRoom(req, res)
);
router.get('/private/history/:friendId', authMiddleware, async (req, res) => {
  try {
    const userId = req.user.id;
    const friendId = req.params.friendId;
    const PrivateMessage = require('../models/PrivateMessage');

    const messages = await PrivateMessage.find({
      $or: [
        { sender: userId, receiver: friendId },
        { sender: friendId, receiver: userId },
      ],
    }).sort({ createdAt: 1 });

    res.json(messages);
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

module.exports = router;
