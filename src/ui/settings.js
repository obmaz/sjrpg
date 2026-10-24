import { canAct, isGameActive } from '../core/helpers.js';
import { preferences, setPreference } from '../core/preferences.js';
import { player, session } from '../core/state.js';
import { startBgMusic, stopBgMusic } from '../systems/audio.js';
import { resizeCanvas, updateCamera } from '../core/canvas.js';

let initialized = false;
let fullscreenPending = false;

function refreshSettings() {
    for (const [id, name] of [
        ['vibrationToggle', 'vibration'],
        ['musicToggle', 'music'],
        ['effectsToggle', 'soundEffects'],
    ]) {
        const button = document.getElementById(id);
        const supported =
            name !== 'vibration' ||
            (typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function');
        button.disabled = !supported;
        button.setAttribute('aria-checked', String(supported && preferences[name]));
        document.getElementById(`${id}State`).textContent = !supported
            ? '미지원'
            : preferences[name]
              ? '켜짐'
              : '꺼짐';
    }
    const fullscreen = !!(document.fullscreenElement || document.webkitFullscreenElement);
    document.getElementById('settingsFullscreen').disabled = fullscreenPending;
    document.getElementById('settingsFullscreen').textContent = fullscreen
        ? '전체화면 나가기'
        : '전체화면으로 전환';
}

function toggleSettings() {
    if (!isGameActive()) return;
    if (session.settingsOpen) {
        closeSettings();
        return;
    }
    if (!canAct()) return;
    session.settingsOpen = true;
    session.gamePaused = true;
    document.getElementById('settingsPanel').classList.remove('hidden');
    refreshSettings();
}

function closeSettings() {
    if (!session.settingsOpen) return;
    session.settingsOpen = false;
    session.gamePaused = false;
    document.getElementById('settingsPanel').classList.add('hidden');
}

async function toggleFullscreen() {
    if (fullscreenPending) return;
    fullscreenPending = true;
    refreshSettings();
    const status = document.getElementById('settingsStatus');
    try {
        const exit = document.exitFullscreen || document.webkitExitFullscreen;
        const enter =
            document.documentElement.requestFullscreen ||
            document.documentElement.webkitRequestFullscreen;
        if ((document.fullscreenElement || document.webkitFullscreenElement) && exit)
            await exit.call(document);
        else if (enter) await enter.call(document.documentElement);
        else {
            status.textContent =
                '이 브라우저는 전체화면을 지원하지 않습니다. 브라우저 메뉴의 홈 화면에 추가를 이용해 주세요.';
            if (canAct()) toggleSettings();
            return;
        }
        status.textContent = '';
    } catch {
        status.textContent =
            '전체화면으로 전환하지 못했습니다. 브라우저에서 전체화면을 허용해 주세요.';
        if (canAct()) toggleSettings();
    } finally {
        fullscreenPending = false;
        refreshSettings();
    }
}

function initializeSettings() {
    if (initialized) return;
    initialized = true;
    document.getElementById('closeSettings').addEventListener('click', closeSettings);
    document.getElementById('resumeGame').addEventListener('click', closeSettings);
    document.getElementById('desktopSettings').addEventListener('click', toggleSettings);
    document.getElementById('settingsFullscreen').addEventListener('click', toggleFullscreen);
    for (const [id, name] of [
        ['vibrationToggle', 'vibration'],
        ['musicToggle', 'music'],
        ['effectsToggle', 'soundEffects'],
    ]) {
        document.getElementById(id).addEventListener('click', () => {
            if (document.getElementById(id).disabled) return;
            setPreference(name, !preferences[name]);
            if (name === 'music') {
                if (preferences.music) startBgMusic();
                else stopBgMusic();
            }
            refreshSettings();
        });
    }
    const onFullscreenChange = () => {
        refreshSettings();
        resizeCanvas();
        updateCamera(player.x + player.w / 2, player.y + player.h / 2);
    };
    document.addEventListener('fullscreenchange', onFullscreenChange);
    document.addEventListener('webkitfullscreenchange', onFullscreenChange);
    refreshSettings();
}

export { initializeSettings, toggleSettings, closeSettings, toggleFullscreen };
