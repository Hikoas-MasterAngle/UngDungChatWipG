const jwt = require('jsonwebtoken');

const authMiddleware = (req, res, next) => {
    const authHeader = req.header('Authorization');
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ error: "Truy cập bị từ chối, thiếu token" });
    }

    try {
        const token = authHeader.split(" ")[1];
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded; // Lưu thông tin user vào req
        next();
    } catch (e) {
        res.status(400).json({ error: "Token không hợp lệ" });
    }
};

module.exports = authMiddleware; // Xuất trực tiếp hàm