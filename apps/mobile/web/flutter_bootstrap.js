{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const runner = await engineInitializer.initializeEngine({
      // Suppress Noto Color Emoji font downloads from fonts.gstatic.com.
      // Color emoji are not used in this app and the requests fail in
      // restricted/emulator network environments.
      useColorEmoji: false,
    });
    await runner.runApp();
  }
});
