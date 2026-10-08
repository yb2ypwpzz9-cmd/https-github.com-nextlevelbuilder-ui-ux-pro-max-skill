# Guía de edición · Landing SPATECH Travel Team

Cómo cambiar textos, precios, fechas o teléfonos de la landing **sin programar**, y que la web se actualice sola.

- **Archivo que se edita:** `spatech-travel-team/index.html`
- **Rama de GitHub que publica la web:** `claude/funny-ramanujan-kcqcjf`
- **Tiempo de un cambio:** unos 2 minutos, más 1–2 minutos hasta que Netlify publica.

---

## Parte 1 · Conectar Netlify con GitHub (una sola vez)

Así, cada vez que guardes un cambio en GitHub, Netlify publica la web sola. Ya no hay que arrastrar carpetas ni ZIPs.

> Netlify cambia de vez en cuando los nombres de sus menús. Si algún botón no se llama exactamente así, busca el más parecido.

### Si la web todavía NO está en Netlify
1. Entra en [app.netlify.com](https://app.netlify.com) → **Add new project** (o *Add new site*) → **Import an existing project**.
2. Elige **GitHub** y autoriza el acceso si te lo pide.
3. Selecciona el repositorio **`https-github.com-nextlevelbuilder-ui-ux-pro-max-skill`**.
4. Rellena la configuración:

   | Campo | Valor |
   |---|---|
   | Branch to deploy | `claude/funny-ramanujan-kcqcjf` |
   | Base directory | `spatech-travel-team` |
   | Build command | *(dejar vacío)* |
   | Publish directory | *(dejar vacío o `spatech-travel-team`; lo decide el archivo `netlify.toml`)* |

5. Pulsa **Deploy**.

### Si la web YA está en Netlify (subida arrastrando la carpeta)
1. Abre el proyecto en Netlify → **Project configuration** (o *Site configuration*) → **Build & deploy** → **Link repository**.
2. Usa los mismos valores de la tabla de arriba.

### Imprescindible para el formulario
1. En Netlify: **Forms** → **Enable form detection**.
2. Vuelve a publicar: **Deploys** → **Trigger deploy** → **Deploy site**.
3. Para recibir avisos: **Forms** → **Form notifications** → **Add notification** → **Email notification** → pon el email donde queréis recibir las preinscripciones.

### Comprobar que funciona
Haz un cambio pequeño siguiendo la Parte 2. En Netlify → **Deploys** debe aparecer uno nuevo en estado *Building* y luego *Published*.

---

## Parte 2 · Cambiar un texto

1. Entra en el repositorio en GitHub.
2. Arriba a la izquierda, en el selector de rama (suele poner el nombre de una rama), elige **`claude/funny-ramanujan-kcqcjf`**. **Importante:** si editas en otra rama, la web no cambia.
3. Abre la carpeta `spatech-travel-team` y luego el archivo `index.html`.
4. Pulsa el **lápiz ✎** (*Edit this file*), arriba a la derecha del archivo.
5. Pulsa **Ctrl + F** (en Mac, **Cmd + F**) y busca **`✏️`** o la palabra que quieras cambiar (por ejemplo `2650`).
6. Cambia **solo el texto**.
7. Pulsa **Commit changes…**. En el mensaje, describe el cambio (por ejemplo *"Cambio precio jugador"*), deja marcado **Commit directly to the `claude/funny-ramanujan-kcqcjf` branch** y confirma.
8. Espera 1–2 minutos y recarga la web.

### La regla de oro
Cambia **solo lo que está entre `>` y `<`**.

```html
<li>... <span>Billetes de avión.</span></li>
                ^^^^^^^^^^^^^^^^^
                esto SÍ se puede cambiar
```

**NO borres ni cambies:**
- los símbolos `<` `>` `"` `/`
- nada que empiece por `class=`, `id=`, `href=`, `src=`, `style=`, `aria-`
- las líneas que empiezan por `<!-- ✏️ EDITABLE` (son las marcas que te guían; no se ven en la web)

---

## Parte 3 · Cambios frecuentes

### Precio
Busca `2650` (jugador) o `2500` (acompañante) y cambia solo el número:
```html
<div class="amount"><b>2650</b><span>US$</span></div>
```

### Fechas del viaje
Las fechas aparecen en varios sitios. Si cambian, **revisa todos**. Búscalas con `enero` y, para las pestañas abreviadas, con `ene</small>`:

| Dónde | Qué buscar |
|---|---|
| Título para Google y WhatsApp (arriba del archivo) | `del 2 al 9 de enero` |
| Portada | `Del 2 al 9 de enero 2027` |
| Tarjeta "Fechas" | `del 2 al 9 de enero de 2027` |
| Pestañas del itinerario | `Sáb 2 ene`, `Dom 3 ene`… |
| Título de cada día | `Día 1 · Sábado 2 de enero`… |
| Mensaje automático de WhatsApp (al final) | `2 al 9 de enero` |

### Fechas de pago
Busca `octubre`, `noviembre` y `diciembre`. Aparecen en el aviso de la portada y en la sección "Formas de pago".

### Teléfono
Busca los últimos dígitos (por ejemplo `6474457`). Cada número aparece **varias veces**, y hay que cambiarlos **todos**:
- en el enlace, sin espacios ni símbolos: `https://wa.me/18296474457` o `tel:+18296474457`
- en el texto visible: `+1 829 647 4457`

Aparecen en los botones de la portada, en la sección de contacto, en el botón flotante de WhatsApp y en el mensaje de confirmación del formulario (al final del archivo).

### Una actividad del itinerario
Cada actividad es una línea así:
```html
<li><time>9:00 AM</time><p>Recogida del grupo en el aeropuerto de Madrid.</p></li>
```
- **Cambiar la hora o el texto:** edita lo que hay entre `<time>…</time>` y entre `<p>…</p>`.
- **Añadir una actividad:** copia una línea `<li>…</li>` completa, pégala debajo y cambia la hora y el texto.
- **Quitar una actividad:** borra la línea `<li>…</li>` completa, de `<li>` a `</li>`.
- **Etiquetas de color** (opcionales, dentro del `<p>`):
  - `<span class="tag tag-in">Incluido</span>`: verde
  - `<span class="tag tag-out">No incluido</span>`: rojo
  - `<span class="tag tag-opt">Opcional</span>`: azul
- **Punto rojo** (entrenamientos y partidos): la línea empieza por `<li class="key">` en vez de `<li>`.

### Un punto de "Incluido" / "No incluido" / precios / condiciones
Cada punto es un `<li>…</li>`. Para añadir uno, copia uno existente completo y cambia el texto final. Para quitarlo, borra el `<li>…</li>` completo.

### Mensaje automático de WhatsApp
Al final del archivo, busca `WA_TEXT`. Cambia solo lo que está entre las comillas simples `'…'`. **No escribas comillas simples (`'`) dentro del mensaje.**

---

## Parte 4 · Cambiar una foto o el logo

1. Prepara la imagen nueva con **el mismo nombre de archivo** que la que sustituye. Las fotos están en formato `.webp`; los logos y escudos, en `.png`.
   - Para convertir una foto a WebP puedes usar [squoosh.app](https://squoosh.app) (gratis y en el navegador). Con 1400 px de ancho y calidad 75 basta.
2. En GitHub, entra en `spatech-travel-team/assets/` → **Add file** → **Upload files** → arrastra la imagen → **Commit changes**.
3. Al tener el mismo nombre, reemplaza a la anterior y la web la usa automáticamente.

| Archivo | Dónde sale |
|---|---|
| `logo-spatech.png` | Logo en cabecera, portada y pie |
| `hero.webp` | Fondo de la portada |
| `jugadores-benfica.webp` / `familias-atletico.webp` | Tarjetas de precios |
| `rm.png`, `atm.png`, `scp.png`, `slb.png` | Escudos de los clubes |

---

## Parte 5 · Si algo sale mal

**Para deshacerlo rápido, desde Netlify (recomendado):**
1. Netlify → **Deploys**.
2. Pulsa la publicación anterior a tu cambio (la que funcionaba).
3. **Publish deploy**. La web vuelve a esa versión al instante.
4. Después corrige el archivo en GitHub con calma. Ojo: la próxima vez que guardes en GitHub se publicará lo que haya en el archivo, así que corrígelo antes de seguir.

**Para ver qué cambiaste:** en GitHub, abre `index.html` → **History**. Ahí ves cada cambio y lo que se modificó.

---

## Qué conviene pedirle a Claude en vez de hacerlo tú

- Añadir o quitar **secciones** completas, o un **día** entero del itinerario.
- Cambios de **diseño**: colores, tamaños, orden de secciones.
- La **versión en inglés**.
- Analítica (Meta Pixel, Google Analytics).
- Cualquier cosa en la que, tras editar, algo se vea descuadrado.

Al pedirlo, indica que la landing está en la rama `claude/funny-ramanujan-kcqcjf`, carpeta `spatech-travel-team`, para que el cambio se haga sobre la versión publicada.
