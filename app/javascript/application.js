// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Turbo cambia el <body> pero no toca los atributos de <html>, y ahí viven el idioma, el tema,
// la densidad y la letra del usuario: se copian del documento nuevo en cada render.
document.addEventListener("turbo:before-render", (e) => {
  const nuevo = e.detail.newBody?.ownerDocument?.documentElement
  if (!nuevo) return
  for (const a of ["lang", "data-theme", "data-densidad", "data-letra"]) {
    const v = nuevo.getAttribute(a)
    if (v !== null) document.documentElement.setAttribute(a, v)
  }
})
