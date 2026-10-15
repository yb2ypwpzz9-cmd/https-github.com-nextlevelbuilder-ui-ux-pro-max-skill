// Arranque de la app web.
//
// El motor gráfico (CanvasKit) se sirve desde la propia web y no desde
// gstatic.com: con red móvil floja o un dominio filtrado, esa descarga externa
// deja la app en blanco sin ningún mensaje. Mismo criterio que Spado Soccer.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: { canvasKitBaseUrl: 'canvaskit/' },
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    document.getElementById('splash')?.remove();
  },
});
