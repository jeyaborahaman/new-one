// Decouples HTTP routes from the Socket.IO instance (set once at boot; no-op in tests without sockets).
const { memberIds } = require('../modules/chat/service');
let io = null;
module.exports = {
  setIo: (i) => { io = i; },
  async publishMessage(message) {
    if (!io) return;
    io.to(`c:${message.conversation_id}`).emit('message:new', message);
  },
  emitToUser(userId, event, payload) { io?.to(`u:${userId}`).emit(event, payload); },
  memberIds,
};
