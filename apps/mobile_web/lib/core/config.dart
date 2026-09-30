/// Build with `--dart-define=API_URL=https://api.jeyabo.com`. The default targets a local backend.
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:4000');
const apiBase = '$apiUrl/v1';
