const { uploadBuffer } = require('../config/cloudinary');
const User = require('../models/User');

class UserService {
  async searchUserByEmail(email) {
    return await User.findOne({ email }).select('-password');
  }

  async sendRequest(fromId, toEmail) {
    const fromUser = await User.findById(fromId);
    const targetUser = await User.findOne({ email: toEmail });

    if (!fromUser || !targetUser) {
      throw new Error('Khong tim thay nguoi dung');
    }
    if (fromUser._id.toString() === targetUser._id.toString()) {
      throw new Error('Khong the tu ket ban voi chinh minh');
    }
    if (
      fromUser.friends.some(
        (friendId) => friendId.toString() === targetUser._id.toString()
      )
    ) {
      throw new Error('Hai nguoi da la ban be');
    }
    if (
      fromUser.sentRequests.some(
        (userId) => userId.toString() === targetUser._id.toString()
      )
    ) {
      throw new Error('Ban da gui loi moi cho nguoi nay');
    }
    if (
      fromUser.friendRequests.some(
        (userId) => userId.toString() === targetUser._id.toString()
      )
    ) {
      throw new Error('Nguoi nay da gui loi moi cho ban');
    }

    await User.findByIdAndUpdate(targetUser._id, {
      $addToSet: { friendRequests: fromId },
    });
    await User.findByIdAndUpdate(fromId, {
      $addToSet: { sentRequests: targetUser._id },
    });
  }

  async acceptFriend(userId, friendId) {
    await User.findByIdAndUpdate(userId, {
      $addToSet: { friends: friendId },
      $pull: { friendRequests: friendId, sentRequests: friendId },
    });
    await User.findByIdAndUpdate(friendId, {
      $addToSet: { friends: userId },
      $pull: { sentRequests: userId, friendRequests: userId },
    });
    return { message: 'Da tro thanh ban be' };
  }

  async declineFriend(userId, friendId) {
    await User.findByIdAndUpdate(userId, {
      $pull: { friendRequests: friendId },
    });
    await User.findByIdAndUpdate(friendId, {
      $pull: { sentRequests: userId },
    });
    return { message: 'Da tu choi loi moi ket ban' };
  }

  async cancelFriendRequest(userId, friendId) {
    await User.findByIdAndUpdate(userId, {
      $pull: { sentRequests: friendId },
    });
    await User.findByIdAndUpdate(friendId, {
      $pull: { friendRequests: userId },
    });
    return { message: 'Da huy loi moi ket ban' };
  }

  async unfriend(userId, friendId) {
    await User.findByIdAndUpdate(userId, {
      $pull: { friends: friendId },
    });
    await User.findByIdAndUpdate(friendId, {
      $pull: { friends: userId },
    });
    return { message: 'Da huy ket ban' };
  }

  async updateProfile(userId, { username, avatarFile }) {
    const user = await User.findById(userId);
    if (!user) throw new Error('Khong tim thay nguoi dung');

    if (username && username.trim()) {
      user.username = username.trim();
    }

    if (avatarFile?.buffer) {
      const uploaded = await uploadBuffer(avatarFile.buffer, {
        folder: 'wipg/avatars',
        resource_type: 'image',
      });
      user.avatar = uploaded.secure_url;
    }

    await user.save();
    return await User.findById(userId).select('-password');
  }

  async getProfile(userId) {
    return await User.findById(userId)
      .populate('friendRequests', 'username email avatar')
      .populate('sentRequests', 'username email avatar')
      .populate('friends', 'username email avatar')
      .select('-password');
  }
}

module.exports = new UserService();
