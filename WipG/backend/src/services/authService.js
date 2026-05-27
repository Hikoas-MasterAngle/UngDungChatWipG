const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const User = require('../models/User');

class AuthService {
  async register(username, email, password) {
    const existingUser = await User.findOne({ email });
    if (existingUser) throw new Error('Email da ton tai');

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({ username, email, password: hashedPassword });
    return await user.save();
  }

  async login(email, password) {
    const user = await User.findOne({ email });
    if (!user) throw new Error('Nguoi dung khong ton tai');

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) throw new Error('Sai mat khau');

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
      expiresIn: '7d',
    });

    return {
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        avatar: user.avatar,
      },
    };
  }

  async forgotPassword(email, newPassword) {
    if (!email || !newPassword) {
      throw new Error('Email va mat khau moi khong duoc de trong');
    }
    if (newPassword.length < 6) {
      throw new Error('Mat khau moi phai co it nhat 6 ky tu');
    }

    const user = await User.findOne({ email });
    if (!user) throw new Error('Nguoi dung khong ton tai');

    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();

    return 'Doi mat khau thanh cong';
  }
}

module.exports = new AuthService();
