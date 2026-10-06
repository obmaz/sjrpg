const messageLog = document.getElementById('messageLog');
function addMessage(text, cls = '') {
    const div = document.createElement('div');
    div.className = 'msg ' + cls;
    div.textContent = text;
    messageLog.appendChild(div);
    setTimeout(() => div.remove(), 2600);
    // Keep max 5 messages
    while (messageLog.children.length > 5) {
        messageLog.firstChild.remove();
    }
}

export { messageLog, addMessage };
