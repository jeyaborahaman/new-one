// Decouples HTTP routes and services from the Socket.IO instance (set once at boot; no-ops without it, e.g. in unit tests).
const { memberIds } = require('../modules/chat/service');
let io = null;

const bus = {
  setIo: (i) => { io = i; },
  onlineCount: () => io?.engine?.clientsCount ?? 0,
  async isOnline(userId) { return io ? (await io.in(`u:${userId}`).fetchSockets()).length > 0 : false; },
  emitToUser(userId, event, payload) { io?.to(`u:${userId}`).emit(event, payload); },
  /** Drop every live socket of a user (ban, suspension, account deletion): sockets are only authenticated at connect. */
  disconnectUser(userId) { io?.in(`u:${userId}`).disconnectSockets(true); },
  /** Put every live socket of these users into the conversation room (new DMs/groups/members). */
  joinConversation(userIds, conversationId) { userIds.forEach((u) => io?.in(`u:${u}`).socketsJoin(`c:${conversationId}`)); },
  leaveConversation(userId, conversationId) { io?.in(`u:${userId}`).socketsLeave(`c:${conversationId}`); },
  /** Emit to the room, then push to members who have no live socket. */
  async publishMessage(message) {
    io?.to(`c:${message.conversation_id}`).emit('message:new', message);
    const { push } = require('../modules/notify/service'); // lazy: notify -> bus
    const sender = await require('../db/knex')('users').where({ id: message.sender_id }).first('display_name');
    for (const uid of await memberIds(message.conversation_id)) {
      if (uid === message.sender_id || (await bus.isOnline(uid))) continue;
      const text = message.type === 'text';
      await push(uid, 'message', { title: sender?.display_name || 'New message', body: text ? String(message.body).slice(0, 120) : `Sent a ${message.type}`, t: { title: sender ? undefined : ['new_message'], body: text ? undefined : [`sent_${message.type}`] }, data: { conversation_id: message.conversation_id } });
    }
  },
};
module.exports = bus;
