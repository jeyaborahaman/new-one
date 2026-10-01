const db = require('../../db/knex');
const bus = require('../../realtime/bus');
const chat = require('../chat/service');

const RING_TIMEOUT_MS = 45_000; // clients stop ringing after this; the expiry job is the server-side backstop
const FINAL = ['ended', 'missed', 'declined'];

/**
 * Moves a call to a final state once and tells every member's devices (so all ringing screens stop).
 * An unanswered call (missed) also leaves a "missed call" notification for everyone who was rung.
 * Returns false when the call was already over (another device or the job got there first).
 */
async function finishCall(call, status, extra = {}) {
  const changed = await db('call_sessions').where({ id: call.id }).whereNotIn('status', FINAL).update({ status, ended_at: new Date() });
  if (!changed) return false;
  const members = await chat.memberIds(call.conversation_id);
  members.forEach((u) => bus.emitToUser(u, 'call:state', { call_id: call.id, status, ...extra }));
  if (status === 'missed') {
    const { notify } = require('../notify/service'); // lazy: notify -> bus
    const caller = await db('users').where({ id: call.initiator_id }).first('display_name');
    for (const uid of members.filter((u) => u !== call.initiator_id)) {
      await notify(uid, 'call', {
        title: caller?.display_name || '', body: `Missed ${call.kind} call`, t: { body: [`missed_call_${call.kind}`] },
        data: { call_id: call.id, conversation_id: call.conversation_id, kind: call.kind, missed: 1 },
      });
    }
  }
  return true;
}

/** Call-log rows for a user: direction, the other side (peer for direct chats, title for groups) and duration. */
async function history(userId, limit = 50) {
  const rows = await db('call_sessions as c').join('conversation_members as m', 'm.conversation_id', 'c.conversation_id').where('m.user_id', userId)
    .orderBy('c.created_at', 'desc').limit(limit)
    .select('c.id', 'c.conversation_id', 'c.initiator_id', 'c.kind', 'c.is_group', 'c.status', 'c.started_at', 'c.ended_at', 'c.created_at');
  if (!rows.length) return [];
  const convIds = [...new Set(rows.map((r) => r.conversation_id))];
  const [peers, convs] = await Promise.all([
    db('conversation_members as cm').join('users as u', 'u.id', 'cm.user_id').whereIn('cm.conversation_id', convIds).whereNot('cm.user_id', userId).select('cm.conversation_id', 'u.id', 'u.display_name'),
    db('conversations').whereIn('id', convIds).select('id', 'type', 'title'),
  ]);
  const P = {}; peers.forEach((p) => { P[p.conversation_id] ||= p; });
  const C = Object.fromEntries(convs.map((c) => [c.id, c]));
  return rows.map((r) => {
    const conv = C[r.conversation_id];
    const peer = conv?.type === 'direct' ? P[r.conversation_id] : null;
    const duration = r.started_at && r.ended_at ? Math.max(0, Math.round((new Date(r.ended_at) - new Date(r.started_at)) / 1000)) : 0;
    return {
      ...r, is_group: !!r.is_group, direction: r.initiator_id === userId ? 'outgoing' : 'incoming', duration_s: duration,
      peer: peer ? { id: peer.id, display_name: peer.display_name } : { id: null, display_name: conv?.title || '' },
    };
  });
}

module.exports = { RING_TIMEOUT_MS, FINAL, finishCall, history };
