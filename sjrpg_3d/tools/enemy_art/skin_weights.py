"""원본 클립의 정점 궤적을 보존하며 오프라인에서 최대 8개 스킨 가중치를 피팅한다."""

import numpy as np


def _positive_fit(matrix, target):
    """작은 활성 집합의 비음수 최소제곱. 런타임과 외부 최적화 패키지를 사용하지 않는다."""
    active = list(range(matrix.shape[1]))
    result = np.zeros(matrix.shape[1])
    while active:
        values = np.linalg.lstsq(matrix[:, active], target, rcond=None)[0]
        negative = np.argmin(values)
        if values[negative] >= 0:
            result[active] = values
            return result / max(result.sum(), 1e-12)
        active.pop(int(negative))
    result[0] = 1
    return result


def fit_influences(point, groups, transforms, limit=8):
    """groups의 뼈만 선택하며 전 클립 샘플에서 원본 LBS 위치를 목표로 삼는다."""
    indices = [index for index, _ in groups]
    weights = np.asarray([weight for _, weight in groups], dtype=np.float64)
    weights /= weights.sum()
    trajectory = np.einsum(
        "tbij,j->tbi", transforms[:, indices], np.asarray([*point, 1])
    )[:, :, :3]
    target = np.einsum("tbj,b->tj", trajectory, weights)
    # 정지 위치를 제거해 작은 실제 동작이 절대 좌표의 수치 오차에 묻히지 않게 한다.
    matrix = (
        (trajectory - np.asarray(point)).transpose(0, 2, 1).reshape(-1, len(groups))
    )
    rhs = (target - np.asarray(point)).reshape(-1)
    matrix = np.vstack([matrix, np.ones((1, len(groups))) * 10])
    rhs = np.append(rhs, 10)
    chosen = []
    best_weights = None
    for _ in range(min(limit, len(groups))):
        best = None
        for candidate in range(len(groups)):
            if candidate in chosen:
                continue
            columns = chosen + [candidate]
            values = _positive_fit(matrix[:, columns], rhs)
            residual = matrix[:, columns] @ values - rhs
            score = float(residual @ residual)
            if best is None or score < best[0]:
                best = (score, candidate, values)
        chosen.append(best[1])
        best_weights = best[2]
    fitted = [(indices[i], float(w)) for i, w in zip(chosen, best_weights) if w > 1e-8]
    result = sum(trajectory[:, i] * w for i, w in zip(chosen, best_weights))
    error = float(np.linalg.norm(result - target, axis=1).max())
    return fitted, error
