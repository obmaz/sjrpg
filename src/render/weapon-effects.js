import { getActorAngle } from '../core/facing.js';
// Weapon silhouettes use simulation attack time; drawing never rolls gameplay randomness.
const WEAPON_EFFECTS = Object.freeze({
    fist: 'impact',
    dagger: 'thrust',
    iron: 'silver-cut',
    axe: 'cleave',
    staff: 'rune',
    firesword: 'flame',
    ice_sword: 'frost',
    legend: 'radiance',
    fan: 'gust',
    hammer: 'quake',
    whip: 'lash',
    crossbow: 'bowstring',
    scimitar: 'crescent',
    sandstorm: 'sand-vortex',
    ankh: 'ankh',
    scorpion: 'venom',
});

function line(ctx, points, color, width = 2) {
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    ctx.beginPath();
    points.forEach(([x, y], index) => (index ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
    ctx.stroke();
}
function ring(ctx, x, y, radius, color, width = 2, from = 0, to = Math.PI * 2) {
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    ctx.beginPath();
    ctx.arc(x, y, radius, from, to);
    ctx.stroke();
}
function star(ctx, x, y, size, color) {
    line(
        ctx,
        [
            [x - size, y],
            [x + size, y],
        ],
        color,
        2,
    );
    line(
        ctx,
        [
            [x, y - size],
            [x, y + size],
        ],
        color,
        2,
    );
    line(
        ctx,
        [
            [x - size * 0.5, y - size * 0.5],
            [x + size * 0.5, y + size * 0.5],
        ],
        color,
        1,
    );
}

function drawWeaponAttack(ctx, actor, x, y) {
    const weapon = actor.attackVisual || actor.weapon;
    const cooldown = actor.lastAttackCooldown || weapon.cooldown || actor.attackCooldown;
    const elapsed = cooldown - actor.attackTimer;
    const duration = Math.min(0.26, cooldown);
    if (!actor.attackSerial || actor.attackTimer <= 0 || elapsed < 0 || elapsed >= duration) return;
    const t = elapsed / duration;
    const effect = WEAPON_EFFECTS[weapon.id] || 'silver-cut';
    const reach = Math.min(96, weapon.range || 40);
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(actor.attackAngle ?? getActorAngle(actor));
    ctx.globalAlpha *= Math.min(1, (1 - t) * 2.2);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    const tip = 18 + Math.sin(t * Math.PI) * reach * 0.7;
    switch (effect) {
        case 'impact':
            ring(ctx, 24 + t * 12, 0, 5 + t * 10, '#ffe6b6', 3);
            for (let i = 0; i < 5; i++) {
                const a = (i - 2) * 0.48;
                line(
                    ctx,
                    [
                        [30 + Math.cos(a) * 9, Math.sin(a) * 9],
                        [30 + Math.cos(a) * (15 + t * 9), Math.sin(a) * (15 + t * 9)],
                    ],
                    '#fff2d2',
                    2,
                );
            }
            break;
        case 'thrust':
            line(
                ctx,
                [
                    [12, -3],
                    [tip + 13, 0],
                    [12, 3],
                ],
                '#e3f5ff',
                3,
            );
            line(
                ctx,
                [
                    [8, -7],
                    [tip - 4, -7],
                ],
                '#8abedf',
                1,
            );
            star(ctx, tip + 13, 0, 4, '#fff');
            break;
        case 'silver-cut':
            ring(ctx, 0, 0, 24 + t * reach * 0.55, '#bed7e5', 6, -0.85 + t * 0.5, 0.3 + t * 0.9);
            ring(ctx, 0, 0, 27 + t * reach * 0.55, '#ffffff', 2, -0.8 + t * 0.5, 0.3 + t * 0.9);
            break;
        case 'cleave':
            ring(ctx, 5, 0, 20 + t * reach * 0.7, '#bd713e', 10, -1.1 + t * 0.6, 0.65 + t * 0.6);
            line(
                ctx,
                [
                    [28, -8],
                    [42 + t * 12, 4],
                    [35, 17],
                ],
                '#ffe0a5',
                4,
            );
            break;
        case 'rune':
            ring(ctx, 24, 0, 10 + t * 8, '#b18aff', 2);
            for (let i = 0; i < 4; i++) {
                const a = (i * Math.PI) / 2 + t;
                star(ctx, 24 + Math.cos(a) * 18, Math.sin(a) * 18, 3, '#e7dbff');
            }
            break;
        case 'flame':
            for (let i = 0; i < 7; i++) {
                const a = -0.8 + i * 0.25,
                    r = 24 + t * 24;
                line(
                    ctx,
                    [
                        [Math.cos(a) * r, Math.sin(a) * r],
                        [Math.cos(a + 0.06) * (r + 14), Math.sin(a + 0.06) * (r + 14)],
                        [Math.cos(a + 0.13) * (r + 6), Math.sin(a + 0.13) * (r + 6)],
                    ],
                    i % 2 ? '#ffe994' : '#ff7138',
                    4,
                );
            }
            ring(ctx, 0, 0, 25 + t * 25, '#ffc35a', 3, -0.75, 1);
            break;
        case 'frost':
            ring(ctx, 0, 0, 22 + t * 28, '#a8efff', 4, -0.95, 0.95);
            for (let i = 0; i < 5; i++) {
                const a = (i - 2) * 0.36,
                    r = 28 + t * 26;
                line(
                    ctx,
                    [
                        [Math.cos(a) * r, Math.sin(a) * r],
                        [Math.cos(a) * (r + 12), Math.sin(a) * (r + 12)],
                    ],
                    '#e4fcff',
                    3,
                );
                star(ctx, Math.cos(a) * (r + 9), Math.sin(a) * (r + 9), 4, '#89d7ff');
            }
            break;
        case 'radiance':
            ring(ctx, 0, 0, 24 + t * 35, '#ffdb79', 4, -1.5, 1.5);
            for (let i = 0; i < 7; i++) {
                const a = (i - 3) * 0.45,
                    r = 28 + t * 32;
                star(ctx, Math.cos(a) * r, Math.sin(a) * r, 5 + (i % 2) * 3, '#fff8d0');
            }
            line(
                ctx,
                [
                    [20, -14],
                    [50, 14],
                ],
                '#fff',
                3,
            );
            line(
                ctx,
                [
                    [20, 14],
                    [50, -14],
                ],
                '#fff',
                3,
            );
            break;
        case 'gust':
            for (let i = 0; i < 3; i++)
                ring(
                    ctx,
                    -8,
                    0,
                    24 + t * 48 + i * 12,
                    '#b9f5ea',
                    3 - i * 0.6,
                    -0.55 + i * 0.06,
                    0.55 - i * 0.06,
                );
            break;
        case 'quake':
            ctx.scale(1, 0.65);
            ring(ctx, 0, 0, 12 + t * 66, '#e6c68e', 4);
            for (let i = 0; i < 8; i++) {
                const a = (i * Math.PI) / 4;
                line(
                    ctx,
                    [
                        [Math.cos(a) * 13, Math.sin(a) * 13],
                        [Math.cos(a + 0.12) * (24 + t * 20), Math.sin(a + 0.12) * (24 + t * 20)],
                        [Math.cos(a) * (35 + t * 25), Math.sin(a) * (35 + t * 25)],
                    ],
                    '#ad8255',
                    3,
                );
            }
            break;
        case 'lash':
            ctx.strokeStyle = '#e2ba82';
            ctx.lineWidth = 3;
            ctx.beginPath();
            ctx.moveTo(10, 0);
            ctx.bezierCurveTo(
                25,
                -35 * Math.sin(t * Math.PI),
                reach * 0.8,
                35 * Math.cos(t * Math.PI),
                reach + 10,
                -18 + t * 36,
            );
            ctx.stroke();
            star(ctx, reach + 10, -18 + t * 36, 5, '#ffe4b5');
            break;
        case 'bowstring':
            line(
                ctx,
                [
                    [16, -14],
                    [26, 0],
                    [16, 14],
                ],
                '#c6a16c',
                3,
            );
            line(
                ctx,
                [
                    [16, -14],
                    [12 + t * 10, 0],
                    [16, 14],
                ],
                '#fff2d4',
                1,
            );
            line(
                ctx,
                [
                    [24, -4],
                    [38 + t * 15, -4],
                ],
                '#eee5bf',
                2,
            );
            break;
        case 'crescent':
            ring(ctx, 6, 0, 25 + t * 30, '#ffc95c', 8, -1.3 + t * 0.5, 1.2 + t * 0.5);
            ring(ctx, 9, -2, 26 + t * 30, '#fff2b5', 2, -1.2 + t * 0.5, 1.1 + t * 0.5);
            break;
        case 'sand-vortex':
            for (let i = 0; i < 14; i++) {
                const a = i * 0.65 + t * 4,
                    r = 4 + i * 1.2;
                line(
                    ctx,
                    [
                        [25 + Math.cos(a) * r, Math.sin(a) * r],
                        [25 + Math.cos(a + 0.3) * (r + 2), Math.sin(a + 0.3) * (r + 2)],
                    ],
                    '#edd39b',
                    2,
                );
            }
            break;
        case 'ankh':
            ring(ctx, 32, -10, 7 + t * 5, '#ffe9a1', 3);
            line(
                ctx,
                [
                    [32, 0],
                    [32, 23],
                ],
                '#ffcf54',
                4,
            );
            line(
                ctx,
                [
                    [21, 7],
                    [43, 7],
                ],
                '#fff2bf',
                4,
            );
            ring(ctx, 32, 6, 16 + t * 25, '#c9a45d', 1);
            break;
        case 'venom':
            ring(ctx, 0, 0, 16 + t * 48, '#84d45d', 3);
            for (let i = 0; i < 6; i++) {
                const a = (i * Math.PI) / 3;
                ring(
                    ctx,
                    Math.cos(a) * (18 + t * 35),
                    Math.sin(a) * (18 + t * 35),
                    3 + (i % 2) * 2,
                    '#ccf67c',
                    2,
                );
            }
            line(
                ctx,
                [
                    [14, -3],
                    [tip + 7, 0],
                    [14, 3],
                ],
                '#b2ec75',
                3,
            );
            break;
    }
    ctx.restore();
}

function drawWeaponProjectile(ctx, projectile, x, y) {
    if (!['crossbow', 'staff', 'sandstorm', 'legend'].includes(projectile.weaponId)) return false;
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(Math.atan2(projectile.vy, projectile.vx));
    if (projectile.weaponId === 'crossbow') {
        line(
            ctx,
            [
                [-14, 0],
                [10, 0],
            ],
            '#eed7a1',
            2,
        );
        line(
            ctx,
            [
                [5, -4],
                [12, 0],
                [5, 4],
            ],
            '#ecf8ff',
            2,
        );
        line(
            ctx,
            [
                [-10, -4],
                [-6, 0],
                [-10, 4],
            ],
            '#bd8e55',
            2,
        );
    } else if (projectile.weaponId === 'staff') {
        line(
            ctx,
            [
                [-21, 0],
                [-7, 0],
            ],
            '#9d7ce9',
            5,
        );
        line(
            ctx,
            [
                [9, 0],
                [0, -6],
                [-7, 0],
                [0, 6],
                [9, 0],
            ],
            '#eee2ff',
            3,
        );
    } else if (projectile.weaponId === 'legend') {
        line(
            ctx,
            [
                [-22, 0],
                [0, 0],
            ],
            '#e9c962',
            4,
        );
        star(ctx, 0, 0, 9, '#fff3ba');
        ring(ctx, 0, 0, 5, '#fff', 2);
    } else {
        for (let i = 0; i < 9; i++) {
            const a = i * 0.8,
                r = 3 + i * 1.3;
            line(
                ctx,
                [
                    [Math.cos(a) * r, Math.sin(a) * r],
                    [Math.cos(a + 0.5) * (r + 2), Math.sin(a + 0.5) * (r + 2)],
                ],
                '#ebcd8d',
                2,
            );
        }
        line(
            ctx,
            [
                [-24, -7],
                [-14, -4],
            ],
            '#ba965a',
            2,
        );
        line(
            ctx,
            [
                [-26, 8],
                [-13, 5],
            ],
            '#dfc58d',
            2,
        );
    }
    ctx.restore();
    return true;
}
export { WEAPON_EFFECTS, drawWeaponAttack, drawWeaponProjectile };
