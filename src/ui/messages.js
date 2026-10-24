import { camera, canvas } from '../core/canvas.js';
import { player } from '../core/state.js';

const eventBubbles = document.getElementById('eventBubbles');

function updateEventBubbles() {
    if (!eventBubbles.children.length) return;
    const bounds = document.getElementById('gameArea').getBoundingClientRect();
    const scale = bounds.width / canvas.width;
    const viewport = window.visualViewport;
    const width = viewport?.width || window.innerWidth || canvas.width;
    const height = viewport?.height || window.innerHeight;
    const left = viewport?.offsetLeft || 0;
    const top = viewport?.offsetTop || 0;
    const bubbleWidth = Math.min(280, Math.max(0, width - 24));
    const x = bounds.left + (player.x + player.w / 2 - camera.x) * scale;
    const y = bounds.top + (player.y - camera.y - 26) * scale;
    eventBubbles.style.width = `${bubbleWidth}px`;
    eventBubbles.style.left = `${Math.max(left + bubbleWidth / 2 + 12, Math.min(left + width - bubbleWidth / 2 - 12, x))}px`;
    const bottom = top + Math.max(0, height - 24);
    const minimum = Math.min(top + 150, bottom);
    eventBubbles.style.top = `${Math.max(minimum, Math.min(bottom, y))}px`;
}

function addMessage(text, kind = '') {
    const bubble = document.createElement('div');
    bubble.className = `event-bubble ${kind}`;
    bubble.textContent = text;
    eventBubbles.appendChild(bubble);
    while (eventBubbles.children.length > 2) eventBubbles.firstChild.remove();
    updateEventBubbles();
    setTimeout(() => bubble.remove(), 2200);
}

export { eventBubbles, addMessage, updateEventBubbles };
