{{flutter_js}}
{{flutter_build_config}}

// Flutter's service worker calls skipWaiting() on install and unregisters
// itself on activate. Listen for the controller change so the page reloads
// immediately when a new SW takes over, ensuring users always get the latest
// build without having to manually refresh.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    window.location.reload();
  });
}

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
