#!/usr/bin/env bash
# V100 워커(calnode02)에 우열 analysis_jobs worker + Ollama 모델을 설치합니다.
# 처리 job: refresh_user_feed, refresh_user_profile
# 로컬(Mac)에서 실행:
#   bash scripts/v100/setup-training-worker.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REMOTE="${V100_SSH_HOST:-lab-worker}"
REMOTE_DIR="${V100_REMOTE_DIR:-~/v100/study-worker}"
OLLAMA_MODEL="${GPU_LLM_MODEL:-qwen2.5:7b}"

echo "==> Target: ${REMOTE}:${REMOTE_DIR}"

if [[ ! -f "${ROOT}/.env.local" ]]; then
  echo "ERROR: ${ROOT}/.env.local 없음 — MONGODB_URI 필요"
  exit 1
fi

# shellcheck disable=SC1091
source "${ROOT}/.env.local"
if [[ -z "${MONGODB_URI:-}" ]]; then
  echo "ERROR: .env.local 에 MONGODB_URI 가 없습니다."
  exit 1
fi

echo "==> Install nvm + Node 20 (worker)"
ssh "${REMOTE}" 'bash -s' <<'REMOTE_NVM'
set -euo pipefail
export NVM_DIR="$HOME/.nvm"
if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
# shellcheck disable=SC1090
source "$NVM_DIR/nvm.sh"
nvm install 20
nvm alias default 20
node --version
npm --version
REMOTE_NVM

echo "==> Sync project (worker files only)"
ssh "${REMOTE}" "mkdir -p ${REMOTE_DIR}"
rsync -az --delete \
  --exclude node_modules \
  --exclude .next \
  --exclude flutter_app \
  --exclude korea-guide-center \
  --exclude design-review \
  --exclude .git \
  "${ROOT}/" "${REMOTE}:${REMOTE_DIR}/"

echo "==> Write worker .env on V100"
ssh "${REMOTE}" "cat > ${REMOTE_DIR}/.env" <<EOF
MONGODB_URI=${MONGODB_URI}
MONGODB_DB_NAME=${MONGODB_DB_NAME:-math_lens_tutor}
GPU_LLM_BASE_URL=http://127.0.0.1:11434
GPU_LLM_MODEL=${OLLAMA_MODEL}
GPU_LLM_TIMEOUT_MS=120000
EOF

echo "==> npm ci on worker"
ssh "${REMOTE}" "bash -s" <<REMOTE_NPM
set -euo pipefail
export NVM_DIR="\$HOME/.nvm"
source "\$NVM_DIR/nvm.sh"
cd ${REMOTE_DIR}
npm ci
REMOTE_NPM

echo "==> Pull Ollama model: ${OLLAMA_MODEL} (HTTP API)"
ssh "${REMOTE}" "python3 -" <<PULL_PY
import json, sys, urllib.request
model = "${OLLAMA_MODEL}"
req = urllib.request.Request(
    "http://127.0.0.1:11434/api/pull",
    data=json.dumps({"name": model}).encode(),
    headers={"Content-Type": "application/json"},
)
with urllib.request.urlopen(req, timeout=3600) as resp:
    for raw in resp:
        line = raw.decode().strip()
        if not line:
            continue
        obj = json.loads(line)
        status = obj.get("status", "")
        if status:
            print(status, flush=True)
        if status == "success":
            print(f"OK: {model}", flush=True)
            break
PULL_PY

echo "==> Verify Ollama chat"
ssh "${REMOTE}" "curl -sS http://127.0.0.1:11434/api/tags | python3 -c \"import sys,json; print([m['name'] for m in json.load(sys.stdin).get('models',[])])\""

echo "==> Install systemd user service"
ssh "${REMOTE}" "bash -s" <<REMOTE_SERVICE
set -euo pipefail
export NVM_DIR="\$HOME/.nvm"
source "\$NVM_DIR/nvm.sh"
NODE="\$(command -v node)"
WORKDIR="\${HOME}/v100/study-worker"
mkdir -p "\$HOME/.config/systemd/user"
cat > "\$HOME/.config/systemd/user/wooyeol-training-feed.service" <<UNIT
[Unit]
Description=Wooyeol training feed worker (Atlas + Ollama)
After=network-online.target

[Service]
Type=simple
WorkingDirectory=\${WORKDIR}
EnvironmentFile=\${WORKDIR}/.env
ExecStart=\${NODE} --import tsx scripts/worker-process-jobs.ts -- --interval=60
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable wooyeol-training-feed.service
systemctl --user restart wooyeol-training-feed.service
sleep 2
systemctl --user status wooyeol-training-feed.service --no-pager || true
REMOTE_SERVICE

echo ""
echo "Done. Logs: ssh ${REMOTE} 'journalctl --user -u wooyeol-training-feed -f'"
