const userService = require('../services/userService');

class UserController {
  async searchUser(req, res) {
    try {
      const { email } = req.query;
      const user = await userService.searchUserByEmail(email);
      if (!user) {
        return res.status(404).json({ message: 'Khong tim thay nguoi dung' });
      }
      res.json(user);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async sendFriendRequest(req, res) {
    try {
      const { targetEmail } = req.body;
      await userService.sendRequest(req.user.id, targetEmail);
      res.json({ message: 'Da gui loi moi ket ban' });
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async acceptFriend(req, res) {
    try {
      const result = await userService.acceptFriend(req.user.id, req.body.friendId);
      res.json(result);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async declineFriend(req, res) {
    try {
      const result = await userService.declineFriend(req.user.id, req.body.friendId);
      res.json(result);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async cancelFriendRequest(req, res) {
    try {
      const result = await userService.cancelFriendRequest(
        req.user.id,
        req.body.friendId
      );
      res.json(result);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async unfriend(req, res) {
    try {
      const result = await userService.unfriend(req.user.id, req.body.friendId);
      res.json(result);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async getProfile(req, res) {
    try {
      const user = await userService.getProfile(req.user.id);
      res.json(user);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async updateProfile(req, res) {
    try {
      const user = await userService.updateProfile(req.user.id, {
        username: req.body.username,
        avatarFile: req.file,
      });
      res.json({ message: 'Cap nhat thanh cong', user });
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }
}

module.exports = new UserController();
