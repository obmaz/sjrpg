#!/usr/bin/env bash
# 사용: tools/new_task.sh "제목"  -> .harness/tasks/NNN.md 생성
set -e
cd "$(dirname "$0")/.."
n=$(printf "%03d" $(( $(ls .harness/tasks 2>/dev/null | wc -l) + 1 )))
f=".harness/tasks/$n.md"
sed "s/<id>/$n/;s/<제목>/$1/" .harness/TEMPLATE.md > "$f"
echo "$f"
