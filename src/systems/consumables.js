'use strict';

function useConsumable(index) {
    if (!canAct() || !Number.isInteger(index) || index < 0 || index >= player.items.length) return;
    const item = player.items[index];
    if (!item) return;

    switch (item.use) {
        case 'heal':
            healPlayer(item.healAmount);
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#66ff66', 20);
            addMessage(`🧪 ${item.name} 사용! +${item.healAmount} HP`, 'heal');
            break;
        case 'bomb':
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ff4400', 35);
            spawnFireZone(
                player.x + player.w / 2,
                player.y + player.h / 2,
                0.5,
                item.bombDmg,
                item.bombRange,
            );
            for (const enemy of getEnemiesInRadius(
                player.x + player.w / 2,
                player.y + player.h / 2,
                item.bombRange,
            )) {
                damageEnemy(enemy, item.bombDmg);
                spawnParticles(enemy.x + enemy.w / 2, enemy.y + enemy.h / 2, '#ff4400', 15);
            }
            addMessage(`💣 ${item.name} 폭발!`, 'damage');
            break;
        case 'antidote':
            player.poisonTimer = 0;
            player.poisonTick = 0;
            player.poisonDamage = 1;
            player.visionReduction = 0;
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#aaddff', 20);
            addMessage(`🧴 ${item.name} 사용! 모든 이상상태 해제`, 'heal');
            break;
        case 'speed':
            player.speedBoost = 10;
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#ffff44', 25);
            addMessage(`⚡ ${item.name} 사용! 10초간 이동속도 1.5배!`, 'loot');
            break;
        case 'return':
            movePlayerTo(FOUNTAIN_CENTER_X, FOUNTAIN_CENTER_Y);
            spawnParticles(player.x + player.w / 2, player.y + player.h / 2, '#aaccff', 30);
            addMessage(`💠 ${item.name} 사용! 분수로 귀환!`, 'loot');
            break;
    }
    player.items.splice(index, 1);
    updateHud();
}
