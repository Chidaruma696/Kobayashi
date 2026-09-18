# Decisiones

Por qué Kobayashi es como es. Lo apunto para no volver a discutirlo conmigo mismo.

## Rails y no otra cosa (sept 2026)
Ya tenía el dominio hecho en Rust (ToyPOS) y murió sin interfaz. Un POS que no cobra el primer día no sirve. Rails con Hotwire me da pantallas rápido y el negocio no necesita más.

## SQLite (sept 2026)
Una tienda, una caja. SQLite en modo IMMEDIATE aguanta eso de sobra. PostgreSQL entra cuando haya varias tiendas pegando a la vez, no antes.

## Etiqueta de identidad, no peso embebido (sept 2026)
El EAN-13 de la etiqueta identifica el paquete (08/07/06 + PLU + secuencia) y el peso vive en la base. Si el código llevara el peso, cualquiera reimprime una etiqueta con otro peso. Así el código solo abre la ficha.

## Nada de etiquetar suelto
Se etiqueta contra un pedido o una producción. Si no hay ni uno ni otro, hace falta motivo. Antes con PIN de alguien con permiso; ahora ver abajo.

## Autorización diferida en vez de PIN que bloquea (18 sept 2026)
El PIN frenaba el flujo: si no había admin y urgía el pedido, nadie podía hacer nada. Lo que hacía el sistema anterior (pedir aprobación y esperar) también bloquea, solo que de otra forma. Ahora la operación se hace con motivo y queda a nombre de quien la hizo en una bandeja; el supervisor la aprueba u observa al final del día, y lo observado se puede cargar. Bajar precio en caja sigue con PIN porque ahí el hueco es dinero directo.

## Doble escaneo sí, doble pesada no
Surtir escaneando y que otra persona verifique escaneando antes de cargar. La doble pesada a ciegas del sistema anterior (romaneo + aduana) la descarté: es lenta y el problema real era la falta de trazabilidad, no el peso. Pero mandar sin escanear tiene que poder pasar: renglón sin etiqueta o sellar sin verificar, con motivo, y cae a revisión.

## Contado en el punto de venta, crédito en ruta
En mostrador todo es de contado, punto. En la ruta el cliente sí tiene crédito y de varios tipos (nota por nota, límite, semanal, contado abonando, especial), porque así funciona el negocio. Me confundí una vez y lo hice todo de contado; corregido.

## La báscula desde el navegador
Web Serial con Kana (mi librería). Vendorizada dentro del repo para no depender de npm en la planta.

## Canastillas en un rechazo parcial (pendiente)
Hoy, si el cliente rechaza parte de la mercancía, las canastillas anotadas se dan por entregadas igual, salvo que el chofer registre devolución. No me convence del todo; lo dejo así hasta ver qué pasa en una ruta real.
