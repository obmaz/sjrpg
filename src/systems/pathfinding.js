// A* is independent of game state. Callers supply body-aware walkability,
// edge clearance, goal and heuristic functions.
export function findGridPath(start, { width, height, isWalkable, canStep, isGoal, heuristic }) {
    const size = width * height;
    const costs = new Float64Array(size).fill(Infinity);
    const parents = new Int32Array(size).fill(-1);
    const closed = new Uint8Array(size);
    const heap = [];
    const index = (x, y) => y * width + x;
    function push(node) {
        heap.push(node);
        let child = heap.length - 1;
        while (child > 0) {
            const parent = (child - 1) >> 1;
            if (heap[parent].score <= node.score) break;
            heap[child] = heap[parent];
            child = parent;
        }
        heap[child] = node;
    }
    function pop() {
        const first = heap[0];
        const last = heap.pop();
        if (heap.length) {
            let parent = 0;
            while (parent * 2 + 1 < heap.length) {
                let child = parent * 2 + 1;
                if (child + 1 < heap.length && heap[child + 1].score < heap[child].score) child++;
                if (last.score <= heap[child].score) break;
                heap[parent] = heap[child];
                parent = child;
            }
            heap[parent] = last;
        }
        return first;
    }
    if (
        start.x < 0 ||
        start.y < 0 ||
        start.x >= width ||
        start.y >= height ||
        !isWalkable(start.x, start.y)
    )
        return null;
    costs[index(start.x, start.y)] = 0;
    push({ ...start, score: heuristic(start.x, start.y) });
    while (heap.length) {
        const current = pop();
        const key = index(current.x, current.y);
        if (closed[key]) continue;
        closed[key] = 1;
        if (isGoal(current.x, current.y)) {
            const result = [];
            for (let cursor = key; parents[cursor] !== -1; cursor = parents[cursor])
                result.push({ x: cursor % width, y: Math.floor(cursor / width) });
            return result.reverse();
        }
        for (const [dx, dy] of [
            [0, -1],
            [1, 0],
            [0, 1],
            [-1, 0],
        ]) {
            const x = current.x + dx,
                y = current.y + dy;
            if (
                x < 0 ||
                y < 0 ||
                x >= width ||
                y >= height ||
                !isWalkable(x, y) ||
                !canStep(current.x, current.y, x, y)
            )
                continue;
            const next = index(x, y);
            const cost = costs[key] + 1;
            if (cost >= costs[next]) continue;
            costs[next] = cost;
            parents[next] = key;
            push({ x, y, score: cost + heuristic(x, y) });
        }
    }
    return null;
}
