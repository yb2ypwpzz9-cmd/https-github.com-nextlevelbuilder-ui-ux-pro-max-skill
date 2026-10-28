// Ajustes para el iPhone (PWA instalada). Cada uno está pensado para no tocar
// el scroll ni los gestos de Flutter.
(function () {
  // Sin zoom por pellizco: la app no lo necesita y desalinea lo que se ve de lo
  // que se toca.
  document.addEventListener('gesturestart', function (e) { e.preventDefault(); },
    { passive: false });

  // iOS 26 a veces deja el visor desplazado tras cerrar el teclado, y los
  // toques caen donde no es. Se recoloca cuando no se está escribiendo.
  var vv = window.visualViewport;
  function recolocar() {
    var a = document.activeElement;
    var escribiendo = a && /^(INPUT|TEXTAREA)$/.test(a.tagName);
    if (vv && !escribiendo && (vv.offsetTop !== 0 || vv.offsetLeft !== 0)) {
      window.scrollTo(0, 0);
    }
  }
  if (vv) {
    vv.addEventListener('resize', recolocar);
    vv.addEventListener('scroll', recolocar);
  }
  window.addEventListener('focusout', function () { setTimeout(recolocar, 300); });
})();
