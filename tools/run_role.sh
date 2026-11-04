#!/usr/bin/env bash
# 사용: tools/run_role.sh <designer|developer|reviewer> <작업id>
# .harness/roles.conf 에 지정된 AI가 해당 역할을 수행하고 결과를 작업 파일 끝에 덧붙인다.
set -e
cd "$(dirname "$0")/.."
[ -f .harness/.env ] && { set -a; . .harness/.env; set +a; }
role=$1; id=$2
task=".harness/tasks/$id.md"
[ -f "$task" ] || { echo "없는 작업: $task" >&2; exit 1; }
ai=$(grep -E "^$role=" .harness/roles.conf | cut -d= -f2 | tr -d '[:space:]')
[ -n "$ai" ] || { echo "roles.conf에 $role 없음" >&2; exit 1; }
prompt="$(awk '/^---$/{n++; next} n>=2' ".claude/agents/$role.md")

AGENTS.md 규칙을 따르고, 아래 작업 파일($task)을 읽고 당신 역할의 결과를 작성하세요.

$(cat "$task")"
# 리뷰어는 읽기 전용(plan), 나머지 역할은 작업 파일·산출물을 써야 하므로 accept-edits
mode=accept-edits; [ "$role" = reviewer ] && mode=plan
case "$ai" in
  claude)   out=$(printf "%s" "$prompt" | claude -p --permission-mode acceptEdits --allowedTools "Bash(tools/*)" "Bash(python:*)" "Bash(node:*)" "Bash(git status:*)" "Bash(git diff:*)") ;;
  antigravity) AGY=${AGY:-$(command -v agy || echo "$LOCALAPPDATA/agy/bin/agy.exe")}
            [ -x "$AGY" ] || { echo "agy 미설치(Antigravity CLI)" >&2; exit 1; }
            out=$(printf "%s" "$prompt" | "$AGY" -p "stdin의 지시를 수행하세요. 셸 명령은 ;, &&, | 로 잇지 말고 하나씩 따로 실행하세요." --mode "$mode" --dangerously-skip-permissions) ;;
  gemini)   command -v gemini >/dev/null || { echo "gemini CLI 미설치: npm i -g @google/gemini-cli" >&2; exit 1; }
            out=$(printf "%s" "$prompt" | gemini -p "stdin의 지시를 수행하세요") ;;
  deepseek) [ -n "$DEEPSEEK_API_KEY" ] || { echo "DEEPSEEK_API_KEY 환경변수 필요" >&2; exit 1; }
            body=$(python -c 'import json,sys;print(json.dumps({"model":"deepseek-chat","messages":[{"role":"user","content":sys.argv[1]}]}))' "$prompt")
            out=$(curl -s https://api.deepseek.com/chat/completions -H "Authorization: Bearer $DEEPSEEK_API_KEY" -H "Content-Type: application/json" -d "$body" \
                  | python -c 'import json,sys;print(json.load(sys.stdin)["choices"][0]["message"]["content"])') ;;
  *) echo "지원하지 않는 AI: $ai" >&2; exit 1 ;;
esac
printf '\n\n## 결과: %s (%s)\n%s\n' "$role" "$ai" "$out" >> "$task"
echo "$role($ai) 완료 -> $task"
