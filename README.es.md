[🇬🇧 English](README.md)

<div align="center">
  <br/>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/logo/kobayashi-logo-w.png">
  <img src="docs/logo/kobayashi-logo-b.png" width="140" alt="Kobayashi">
</picture>

# Kobayashi

**帳 · Punto de venta, etiquetador y administración para negocios pequeños, por módulos: un abarrote, una recaudería que pesa y etiqueta, una distribuidora con rutas de reparto o una planta que surte a sus tiendas. Ruby on Rails.**

<br/>

![Rails 8.1](https://img.shields.io/badge/rails-8.1-cc0000?style=for-the-badge&logo=rubyonrails&logoColor=white)
![Ruby 3.4](https://img.shields.io/badge/ruby-3.4-cc342d?style=for-the-badge&logo=ruby&logoColor=white)
![SQLite](https://img.shields.io/badge/sqlite-un%20servidor-003b57?style=for-the-badge&logo=sqlite&logoColor=white)
![Licencia Apache 2.0](https://img.shields.io/badge/licencia-Apache_2.0-1b150d?style=for-the-badge)

<br/>

*Barcodes de identidad · kardex de solo inserción · dinero en centavos enteros · una transacción por operación · nada sale sin escanear*

</div>

---

> [!NOTE]
> Kobayashi es el sucesor de [ToyPOS](https://github.com/Chidaruma696/ToyPOS): nació para una planta de carne, se construyó **caja primero** en vez de dominio primero, y ahora va por módulos. Corre en un servidor para la matriz y sus sucursales. Está en desarrollo y todavía no ha corrido un día real de ventas.

<br/>

## 🏪 Qué es

Un solo sistema, una sola base, y **módulos que se encienden o apagan por negocio**. Caja, inventario, ajustes y administración van siempre; el resto depende de a qué se dedica el negocio y se cambia cuando quieras en Ajustes. La primera vez, con la base vacía, pide el nombre del negocio, su giro y el primer administrador, y ya.

| Giro | Módulos que arrancan encendidos |
|---|---|
| **Abarrotes / tienda** | caja, inventario, administración. Productos por pieza con el código del proveedor. |
| **Recaudería / frutería** | lo anterior más **etiquetas y producción**: pesar en la báscula, imprimir etiquetas de identidad, producción con merma. |
| **Distribuidora** | pedidos, salidas entre sucursales, **rutas de reparto** (chofer, cobranza, crédito, canastillas, convenios) y conteos, sin etiquetadora. |
| **Planta con tiendas y reparto** | todo. |

Donde hay etiquetas, cada paquete, caja y tarima lleva un **EAN-13 de identidad**: el código nombra la fila en la base; el peso vive en la base, nunca dentro del código. Un módulo apagado desaparece de la cinta, de los roles y de sus pantallas; sus datos se quedan, y no se apaga mientras tenga trabajo abierto.

| Módulo | Qué hace | Regla que impone |
|---|---|---|
| **Pedidos** | Una tienda o un cliente de ruta pide; la matriz surte renglón por renglón. | Lo surtido es siempre la suma de las etiquetas ligadas al renglón, nunca un contador guardado. |
| **Producción** | Entra producto en bruto, salen cortes etiquetados, la diferencia es merma. | No sale más de lo que entró. La producción no tiene nada que ver con los pedidos: es una entrada y sus salidas. |
| **Etiquetas** | Paquete, caja y tarima con barcode de identidad, impresas a 55×45 mm. | Nada de etiquetar suelto: toda etiqueta nace de un renglón, una producción o una autorización registrada. |
| **Salidas** | Escanear para surtir, otra persona escanea para verificar la carga, sellar, enviar. | Quien surte no verifica su carga. Una etiqueta solo va en una salida activa. |
| **Recepción** | La tienda escanea paquete por paquete (o la tarima entera); lo roto o perdido se reporta por barcode. | Lo que no se escanea no entra al stock. Las cajas no se aceptan enteras. |
| **Caja** | Escanear o teclear, báscula para kilos sueltos, pagos mixtos, ticket de 80 mm con su propio barcode, corte con fondo, retiros y cierre. | No se vende sin stock, sin caja abierta ni con la gaveta pasada del límite. Un producto sin precio en esa sucursal no se vende. Bajar precio cae en la bandeja de revisión y nunca baja del piso (50 % del catálogo por defecto). |
| **Rutas** | Un viaje por ruta y día: los repartos sellados suben en orden de parada, sale el camión y el chofer trabaja desde el celular: escanea lo que baja, rechaza lo que el cliente no quiso, cobra de contado y toma el pedido de la próxima visita. Al volver, la oficina liquida: lo cobrado menos gastos es lo que el chofer entrega; lo que falte se le carga. | El dinero cobrado en ruta no está en la gaveta hasta liquidar. Lo rechazado vuelve al inventario en el momento. Entregar sin escanear se puede, pero cae en la bandeja de revisión. |
| **Zonas y orden de reparto** | Una ruta tiene zonas en orden; cada cliente está en una zona con su número. Al armar un viaje se genera el orden de reparto con eso (zona y luego número), la oficina puede mover paradas a mano antes de salir, y el orden impreso se va con el chofer. | El orden vive en el viaje, no en la cabeza de nadie. |
| **Canastillas** | Activo prestado, por tipo (marca/color). Se cargan al salir, se entregan en la parada, vuelven cuando el cliente las devuelve (en la parada o en bodega) y se descargan al liquidar. Saldo por cliente y por chofer, con ajustes. | Cada movimiento lleva su motivo y su usuario. |
| **Convenios de precio** | Un cliente puede tener precio fijo por kilo en ciertas líneas hasta un tope semanal de cajas, acumulado entre todas sus notas de la semana; el excedente va a lista. | Se aplica al cerrar la nota al salir; una nota rechazada devuelve el tope. |
| **Crédito de ruta** | Cada cliente tiene su tipo de crédito como lo maneja el negocio: contado, nota por nota, límite, semanal (paga al corte), contado abonando (7 días), especial (día de corte propio). En la parada el chofer puede dejar la nota a cuenta si la regla lo permite; el cliente también puede abonar a lo que debía. Pantalla de cobranza con saldos, antigüedad, estados de cuenta, abonos en oficina y bloqueo manual que manda sobre la regla. | El bloqueo se calcula en vivo sobre la cuenta: si el cliente paga, se abre solo. El punto de venta sigue siendo de contado. |
| **Mandar sin escanear** | Un renglón sin etiqueta cabe en cualquier salida con motivo, y una salida se puede sellar sin el segundo escaneo con motivo. | Las dos cosas caen en la bandeja de revisión a nombre de quien lo hizo. El doble escaneo (surtir, verificar) es la norma, no un muro. |
| **Reparto** | La salida a un cliente cierra una nota por cobrar; el chofer vuelve y la entrega se cobra en la caja abierta. | Lo rechazado vuelve como devolución con el ticket. Todo de contado. |
| **Conteos** | El supervisor escanea todo; el conteo manda. | Se ajusta el stock, las etiquetas no vistas mueren y el faltante se carga al cajero. |
| **Precios** | Precio de lista, precio por sucursal, promociones (especial, porcentaje, por cantidad). | La caja aplica sola la regla más barata vigente; una promoción nunca sube el precio. |
| **Autorización diferida** | Lo que necesitaría a un supervisor (etiquetar sin pedido, un renglón sin etiqueta, un ajuste de inventario, un retiro de efectivo, bajar un precio) se hace igual con su motivo cuando no hay nadie, y cae en una bandeja de revisión. | El flujo nunca se frena; el supervisor aprueba u observa cada una al final del día, y lo observado se le puede cargar a quien lo hizo. Quien tiene el permiso lo hace a su nombre y no pasa por la bandeja. No hay PIN. |
| **Inicio (tablero) y admin** | Ventas, tickets, formas de pago, cortes, mermas, conteos, inventario valorizado, CSV por producto; productos, usuarios, roles, sucursales, clientes, rutas. | Permisos por clave; las pestañas de la cinta aparecen solo para lo que el usuario puede hacer. |

<br/>

## 📸 Capturas

<img src="docs/capturas/inicio.png" alt="" width="100%">

*Inicio: el tablero del día de la sucursal (ventas, efectivo, lo más vendido, lo que espera revisión).*

<img src="docs/capturas/etiquetadora.png" alt="" width="100%">

*Etiquetar contra un pedido: el banner lleva el color del destino y cada caja entra sola a la salida.*

<img src="docs/capturas/pedidos.png" alt="" width="100%">

*Cola de pedidos: lo pendiente y lo que salió completo o parcial.*

<img src="docs/capturas/salida.png" alt="" width="100%">

*Una salida: se surte escaneando, otra persona verifica, se sella y se envía.*

<img src="docs/capturas/viaje.png" alt="" width="100%">

*Un viaje de reparto: paradas en orden, lo cobrado y lo que el chofer debe entregar.*

<img src="docs/capturas/inicio-movil.png" alt="" width="320">

*También cabe en un teléfono.*

## 🧭 Diseño

- **El kardex es la verdad.** `Movimiento` solo se inserta; `Existencia` es una proyección que se actualiza en la misma transacción, con `CHECK (cantidad >= 0)` en la base.
- **Modelos y tablas en español**, porque el negocio ya habla así: pesada, caja, traspaso, corte, folio.
- **Una transacción por operación**, un solo camino por operación. Sin fallbacks.
- **Kilos a tres decimales, dinero en centavos enteros**, un solo reloj (Ciudad de México), fecha de negocio distinta de la hora de captura.
- **Báscula en el navegador** por Web Serial con [Kana](https://github.com/Chidaruma696/Kana) (solo Chrome o Edge).
- **Cinta tipo Office**: pestañas por módulo, botones grandes por acción, filtrados por permiso.
- **Tres idiomas**: inglés por defecto, español y alemán; cada usuario elige el suyo en Ajustes, junto con tema, densidad y tamaño de letra.

<br/>

## 🚀 Correrlo

```
bin/setup        # bundle, base de datos, semillas
bin/dev          # http://localhost:3000
```

La primera vez, con la base vacía, la aplicación pide el nombre del negocio, la matriz y el primer administrador (nombre, usuario, contraseña, idioma) y entra con él; desde ahí se dan de alta productos, sucursales y usuarios en Administración. Las semillas solo crean los roles base. Tests: `bin/rails test`.

<br/>

## 📚 Créditos y nombres

Kobayashi, Kana y Tohru toman su nombre de *Kobayashi-san Chi no Maid Dragon*, de Coolkyousinnjya; nada de esto tiene relación con la autora ni con las editoriales. Protocolo de báscula vía [Kana](https://github.com/Chidaruma696/Kana) (MIT). Hecho con Rails, Hotwire y Tailwind.

## 📄 Licencia

Apache 2.0. Ver [LICENSE](LICENSE) y [NOTICE](NOTICE).

Úsalo, cámbialo, véndelo; lo único que pido es que conserves el aviso y des el crédito a la vista: *basado en Kobayashi, de Chidaruma696*.
