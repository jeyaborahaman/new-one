const { RtcTokenBuilder, RtcRole } = require('agora-token');
const env = require('../config/env');
const { HttpError } = require('../utils/errors');
module.exports = {
  buildToken(channel, uid, ttlSeconds = 3600) {
    if (!env.AGORA_APP_ID || !env.AGORA_CERT) throw new HttpError(503, 'CALLS_NOT_CONFIGURED', 'Calling is not configured');
    const expire = Math.floor(Date.now() / 1000) + ttlSeconds;
    return { appId: env.AGORA_APP_ID, token: RtcTokenBuilder.buildTokenWithUid(env.AGORA_APP_ID, env.AGORA_CERT, channel, Number(uid), RtcRole.PUBLISHER, expire, expire), uid: Number(uid), channel, expires_in: ttlSeconds };
  },
};
