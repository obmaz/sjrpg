import { MAP_HEIGHT, MAP_WIDTH } from '../core/constants.js';
import { isWaterTile } from './world.js';

// A boat needs a real lake and a connected area wide enough for its full body.
function getBoatWaters() {
    const count = MAP_WIDTH * MAP_HEIGHT;
    const waterAreas = new Int16Array(count).fill(-1);
    const waterSizes = [];
    const neighbours = (index) => {
        const x = index % MAP_WIDTH,
            y = Math.floor(index / MAP_WIDTH);
        return [
            x > 0 ? index - 1 : -1,
            x + 1 < MAP_WIDTH ? index + 1 : -1,
            y > 0 ? index - MAP_WIDTH : -1,
            y + 1 < MAP_HEIGHT ? index + MAP_WIDTH : -1,
        ];
    };
    for (let index = 0; index < count; index++) {
        if (
            waterAreas[index] >= 0 ||
            !isWaterTile(index % MAP_WIDTH, Math.floor(index / MAP_WIDTH))
        )
            continue;
        const id = waterSizes.length,
            queue = [index];
        waterAreas[index] = id;
        for (let head = 0; head < queue.length; head++)
            for (const next of neighbours(queue[head])) {
                if (
                    next < 0 ||
                    waterAreas[next] >= 0 ||
                    !isWaterTile(next % MAP_WIDTH, Math.floor(next / MAP_WIDTH))
                )
                    continue;
                waterAreas[next] = id;
                queue.push(next);
            }
        waterSizes.push(queue.length);
    }
    const fits = new Uint8Array(count),
        visited = new Uint8Array(count),
        eligible = new Uint8Array(count);
    for (let y = 0; y < MAP_HEIGHT - 1; y++)
        for (let x = 0; x < MAP_WIDTH - 1; x++) {
            const index = y * MAP_WIDTH + x;
            fits[index] = Number(
                waterSizes[waterAreas[index]] >= 48 &&
                    isWaterTile(x, y) &&
                    isWaterTile(x + 1, y) &&
                    isWaterTile(x, y + 1) &&
                    isWaterTile(x + 1, y + 1),
            );
        }
    for (let index = 0; index < count; index++) {
        if (!fits[index] || visited[index]) continue;
        const queue = [index];
        let minX = MAP_WIDTH,
            maxX = 0,
            minY = MAP_HEIGHT,
            maxY = 0;
        visited[index] = 1;
        for (let head = 0; head < queue.length; head++) {
            const current = queue[head],
                x = current % MAP_WIDTH,
                y = Math.floor(current / MAP_WIDTH);
            minX = Math.min(minX, x);
            maxX = Math.max(maxX, x);
            minY = Math.min(minY, y);
            maxY = Math.max(maxY, y);
            for (const next of neighbours(current)) {
                if (next < 0 || visited[next] || !fits[next]) continue;
                visited[next] = 1;
                queue.push(next);
            }
        }
        if (queue.length >= 24 && maxX - minX >= 4 && maxY - minY >= 4)
            for (const tile of queue) eligible[tile] = 1;
    }
    return eligible;
}

export { getBoatWaters };
