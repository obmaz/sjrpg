{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: { forceSingleThreadedSkwasm: true },
  onEntrypointLoaded: async function(engineInitializer) {
    const runner = await engineInitializer.initializeEngine({hostElement: document.getElementById('flutter-host')});
    await runner.runApp();
  }
});
