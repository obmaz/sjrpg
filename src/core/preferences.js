const PREFERENCES_KEY = 'guardian-of-nature.settings';
const preferences = { vibration: true, music: true, soundEffects: true };
try {
    const saved = JSON.parse(window.localStorage?.getItem(PREFERENCES_KEY) || '{}');
    for (const name of Object.keys(preferences)) {
        if (typeof saved?.[name] === 'boolean') preferences[name] = saved[name];
    }
} catch {
    /* Storage may be unavailable in private browsing. */
}

function stopVibration() {
    try {
        if (typeof navigator !== 'undefined') navigator.vibrate?.(0);
    } catch {
        /* Unsupported device. */
    }
}

function setPreference(name, value) {
    if (!Object.hasOwn(preferences, name) || typeof value !== 'boolean') return;
    preferences[name] = value;
    if (name === 'vibration' && !value) stopVibration();
    try {
        window.localStorage?.setItem(PREFERENCES_KEY, JSON.stringify(preferences));
    } catch {
        /* Keep the session preference. */
    }
}

export { preferences, setPreference, stopVibration };
