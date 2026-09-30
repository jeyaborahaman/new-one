const { Server } = require('socket.io');
const { createAdapter } = require('@socket.io/redis-adapter');
const redis = require('../config/redis');
const db = require('../db/knex');
const env = require('../config/env');
const { verifyAccess } = require('../middleware/auth');
const chat = require('../modules/chat/service');
const bus = require('./bus');
const { messageBody } = require('../modules/chat/routes');

function attach(httpServer) {
  const io = new Server(httpServer, { cors: { origin: env.CORS_ORIGINS.split(',').filter(Boolean) }, maxHttpBufferSize: 1e5 });
  bus.setIo(io);
  if (redis) io.adapter(createAdapter(redis, redis.duplicate())); // fan-out across nodes

  io.use(async (socket, next) => {
    try {
      const claims = verifyAccess(socket.handshake.auth?.token || '');
      const user = await db('users').where({ id: claims.sub, status: 'active' }).first('id');
      if (!user) throw new Error('unavailable');
      socket.userId = user.id;
      next();
    } catch { next(new Error('unauthorized')); }
  });

  io.on('connection', async (socket) => {
    socket.join(`u:${socket.userId}`);
    const rooms = await db('conversation_members').where({ user_id: socket.userId }).select('conversation_id');
    rooms.forEach((r) => socket.join(`c:${r.conversation_id}`));

    // Ack callback returns { ok, message | error } so clients can dedupe by client_id.
    socket.on('message:send', async (payload, ack = () => {}) => {
      try {
        const p = messageBody.parse(payload?.message ?? payload);
        const conversationId = Number(payload.conversation_id);
        const { message, created } = await chat.sendMessage({ conversationId, senderId: socket.userId, clientId: p.client_id, type: p.type, body: p.body, mediaId: p.media_id });
        if (created) await bus.publishMessage(message);
        ack({ ok: true, message });
      } catch (e) { ack({ ok: false, error: e.message }); }
    });

    socket.on('message:read', async ({ conversation_id, up_to_id } = {}) => {
      try {
        await chat.markRead(Number(conversation_id), socket.userId, Number(up_to_id));
        socket.to(`c:${conversation_id}`).emit('message:receipt', { conversation_id, user_id: socket.userId, up_to_id });
      } catch { /* ignore invalid receipt */ }
    });

    socket.on('typing', async ({ conversation_id } = {}) => {
      try { await chat.assertMember(Number(conversation_id), socket.userId); socket.to(`c:${conversation_id}`).emit('typing', { conversation_id, user_id: socket.userId }); } catch { /* not a member */ }
    });
  });
  return io;
}
module.exports = { attach };
