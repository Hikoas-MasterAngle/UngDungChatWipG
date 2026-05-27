const express = require('express');

const authMiddleware = require('../middlewares/authMiddleware');
const upload = require('../middlewares/uploadMiddleware');
const userController = require('../controllers/userController');

const router = express.Router();

router.get('/search', authMiddleware, (req, res) =>
  userController.searchUser(req, res)
);
router.post('/request', authMiddleware, (req, res) =>
  userController.sendFriendRequest(req, res)
);
router.post('/accept', authMiddleware, (req, res) =>
  userController.acceptFriend(req, res)
);
router.post('/decline', authMiddleware, (req, res) =>
  userController.declineFriend(req, res)
);
router.post('/cancel-request', authMiddleware, (req, res) =>
  userController.cancelFriendRequest(req, res)
);
router.post('/unfriend', authMiddleware, (req, res) =>
  userController.unfriend(req, res)
);
router.get('/profile', authMiddleware, (req, res) =>
  userController.getProfile(req, res)
);
router.put(
  '/update-profile',
  authMiddleware,
  upload.single('avatar'),
  (req, res) => userController.updateProfile(req, res)
);

module.exports = router;
