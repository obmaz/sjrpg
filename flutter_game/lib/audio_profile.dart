enum EffectSound {
  slash,
  fire,
  ice,
  lightning,
  impact,
  hurt,
  dodge,
  warcry,
  loot,
}

class SoundProfile {
  const SoundProfile(
    this.pitch,
    this.endPitch,
    this.duration,
    this.noiseFrequency,
    this.noiseGain,
    this.toneGain, {
    this.wave = 'triangle',
  });
  final double pitch, endPitch, duration, noiseFrequency, noiseGain, toneGain;
  final String wave;
  static SoundProfile forSound(EffectSound sound) => switch (sound) {
    EffectSound.slash => const SoundProfile(290, 85, .13, 2600, .14, .035),
    EffectSound.fire => const SoundProfile(
      180,
      55,
      .25,
      650,
      .15,
      .055,
      wave: 'sine',
    ),
    EffectSound.ice => const SoundProfile(1500, 610, .19, 5200, .07, .025),
    EffectSound.lightning => const SoundProfile(
      840,
      190,
      .15,
      3400,
      .12,
      .025,
      wave: 'sawtooth',
    ),
    EffectSound.impact => const SoundProfile(
      180,
      48,
      .11,
      1200,
      .13,
      .07,
      wave: 'sine',
    ),
    EffectSound.hurt => const SoundProfile(
      95,
      38,
      .19,
      700,
      .11,
      .07,
      wave: 'sine',
    ),
    EffectSound.dodge => const SoundProfile(
      190,
      100,
      .12,
      3800,
      .08,
      .01,
      wave: 'sine',
    ),
    EffectSound.warcry => const SoundProfile(
      135,
      58,
      .36,
      320,
      .1,
      .06,
      wave: 'sine',
    ),
    EffectSound.loot => const SoundProfile(
      880,
      1320,
      .18,
      0,
      0,
      .025,
      wave: 'sine',
    ),
  };
}
