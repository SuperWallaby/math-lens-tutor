#!/usr/bin/env bash
# V100 training worker 상태 확인
set -euo pipefail
REMOTE="${V100_SSH_HOST:-lab-worker}"

ssh "${REMOTE}" 'bash -s' <<'EOF'
set -euo pipefail
echo "=== Ollama ==="
curl -sS http://127.0.0.1:11434/api/tags | python3 -c "import sys,json; print('\n'.join(m['name'] for m in json.load(sys.stdin).get('models',[])))"
echo ""
echo "=== systemd ==="
systemctl --user is-active wooyeol-training-feed.service 2>/dev/null || echo inactive
journalctl --user -u wooyeol-training-feed -n 15 --no-pager 2>/dev/null || true
EOF
