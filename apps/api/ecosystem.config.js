module.exports = {
  apps: [
    // HTTP + Socket.IO. Cluster mode is safe because rate limits, sockets and jobs go through Redis.
    { name: 'jeyabo-api', script: 'src/server.js', instances: 'max', exec_mode: 'cluster', max_memory_restart: '1G', env: { NODE_ENV: 'production' } },
  ],
};
