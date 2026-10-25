import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'package:web/web.dart' as web;
import 'audio_bridge.dart';
import 'audio_profile.dart';

AudioBridge createBridge() => _BrowserAudio();

class _BrowserAudio implements AudioBridge {
  _BrowserAudio() {
    _gesture = ((web.Event _) => _unlock()).toJS;
    _visibility = ((web.Event _) {
      if (!visible) {
        stop();
        final context = _context;
        if (context != null) _settle(context.suspend());
      }
    }).toJS;
    web.window.addEventListener(
      'pointerdown',
      _gesture,
      web.AddEventListenerOptions(capture: true),
    );
    web.window.addEventListener(
      'keydown',
      _gesture,
      web.AddEventListenerOptions(capture: true),
    );
    web.document.addEventListener('visibilitychange', _visibility);
  }
  late final JSFunction _gesture, _visibility;
  web.AudioContext? _context;
  web.GainNode? _master;
  web.AudioBuffer? _noise;
  final _sources = <web.AudioScheduledSourceNode>{};
  bool _enabled = true, _disposed = false;
  @override
  bool get supported => web.window.hasProperty('AudioContext'.toJS).toDart;
  @override
  bool get visible => !web.document.hidden;
  @override
  String? readPreference(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  @override
  void writePreference(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }

  void _settle(JSPromise<JSAny?> future) {
    future.toDart.then<void>((_) {}, onError: (Object _, StackTrace _) {});
  }

  void _unlock() {
    if (!_enabled || _disposed || !supported || !visible) return;
    try {
      var context = _context;
      if (context == null) {
        context = web.AudioContext();
        _context = context;
        final master = context.createGain();
        master.gain.value = .45;
        master.connect(context.destination);
        _master = master;
        final buffer = context.createBuffer(
          1,
          (context.sampleRate * .5).toInt(),
          context.sampleRate,
        );
        final data = buffer.getChannelData(0).toDart;
        final random = math.Random(1789);
        for (var i = 0; i < data.length; i++) {
          data[i] = random.nextDouble() * 2 - 1;
        }
        _noise = buffer;
      }
      if (context.state == 'suspended') _settle(context.resume());
    } catch (_) {
      /* Unsupported or blocked audio remains silent. */
    }
  }

  @override
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) stop();
  }

  @override
  void play(EffectSound sound) {
    final context = _context, master = _master;
    // Do not queue locked sounds for playback after a later gesture.
    if (!_enabled ||
        _disposed ||
        !visible ||
        context == null ||
        master == null ||
        context.state != 'running') {
      return;
    }
    if (sound == EffectSound.hurt) stop();
    final p = SoundProfile.forSound(sound), now = context.currentTime;
    if (_sources.length + (p.noiseGain > 0 ? 2 : 1) > 12) return;
    final tone = context.createOscillator(), gain = context.createGain();
    tone.type = p.wave;
    tone.frequency.setValueAtTime(p.pitch, now);
    tone.frequency.exponentialRampToValueAtTime(p.endPitch, now + p.duration);
    _envelope(gain.gain, p.toneGain, now, p.duration);
    tone.connect(gain);
    gain.connect(master);
    _start(tone, [tone, gain], now, p.duration);
    if (p.noiseGain > 0 && _noise != null) {
      final noise = context.createBufferSource(),
          filter = context.createBiquadFilter(),
          noiseGain = context.createGain();
      noise.buffer = _noise;
      filter.type = 'bandpass';
      filter.Q.value = .7;
      filter.frequency.setValueAtTime(p.noiseFrequency, now);
      filter.frequency.exponentialRampToValueAtTime(
        math.max(80, p.noiseFrequency * .35),
        now + p.duration,
      );
      _envelope(noiseGain.gain, p.noiseGain, now, p.duration);
      noise.connect(filter);
      filter.connect(noiseGain);
      noiseGain.connect(master);
      _start(noise, [noise, filter, noiseGain], now, p.duration);
    }
  }

  void _envelope(
    web.AudioParam gain,
    double peak,
    double now,
    double duration,
  ) {
    gain.setValueAtTime(.0001, now);
    gain.linearRampToValueAtTime(peak, now + .004);
    gain.exponentialRampToValueAtTime(.0001, now + duration);
  }

  void _start(
    web.AudioScheduledSourceNode source,
    List<web.AudioNode> nodes,
    double now,
    double duration,
  ) {
    _sources.add(source);
    source.addEventListener(
      'ended',
      ((web.Event _) {
        _sources.remove(source);
        for (final node in nodes) {
          node.disconnect();
        }
      }).toJS,
      web.AddEventListenerOptions(once: true),
    );
    source.start(now);
    source.stop(now + duration + .01);
  }

  @override
  void stop() {
    for (final source in _sources.toList()) {
      try {
        source.stop();
      } catch (_) {}
    }
    _sources.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    web.window.removeEventListener(
      'pointerdown',
      _gesture,
      web.EventListenerOptions(capture: true),
    );
    web.window.removeEventListener(
      'keydown',
      _gesture,
      web.EventListenerOptions(capture: true),
    );
    web.document.removeEventListener('visibilitychange', _visibility);
    final context = _context;
    if (context != null) _settle(context.close());
  }
}
