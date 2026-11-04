# 하네스 (감독자 · 디자이너 · 개발자 · 리뷰어)

감독자 = 메인 Claude 세션. 나머지는 `.claude/agents/`의 서브에이전트.
작업은 `.harness/tasks/<id>.md` 한 파일에 모두 기록하며, 어떤 AI든 이 파일을 읽고 써서 참여한다.

흐름: requested → designed → implemented → approved(또는 changes-requested → implemented 반복) → done

외부 AI(Gemini 등): 역할별 담당 AI는 `.harness/roles.conf`에서 정한다(claude/antigravity/gemini/deepseek). `tools/run_role.sh <역할> <작업id>` 한 줄로 담당 AI가 작업 파일을 읽고 결과를 덧붙인다.
작업 시작: `tools/new_task.sh "제목"`
