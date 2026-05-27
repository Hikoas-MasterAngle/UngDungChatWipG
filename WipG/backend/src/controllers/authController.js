const authService = require('../services/authService');

class AuthController {
    async register(req, res) {
        try {
            const { username, email, password } = req.body;
            const user = await authService.register(username, email, password);
            res.status(201).json({ message: "Đăng ký thành công", user });
        } catch (error) {
            res.status(400).json({ error: error.message });
        }
    }

    async login(req, res) {
        try {
            const { email, password } = req.body;
            const data = await authService.login(email, password);
            res.status(200).json(data);
        } catch (error) {
            res.status(400).json({ error: error.message });
        }
    }

    async forgotPassword(req, res) {
        try {
            const { email, newPassword } = req.body;
            const msg = await authService.forgotPassword(email, newPassword);
            res.status(200).json({ message: msg });
        } catch (error) {
            res.status(400).json({ error: error.message });
        }
    }
}

module.exports = new AuthController();
