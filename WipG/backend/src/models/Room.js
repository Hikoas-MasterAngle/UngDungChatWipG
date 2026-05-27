const mongoose = require('mongoose');

const roomSchema = new mongoose.Schema({
    name: { type: String, required: true },
    admin: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    members: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    icon: { type: String, default: "https://via.placeholder.com/100" }
}, { timestamps: true });

module.exports = mongoose.model('Room', roomSchema);