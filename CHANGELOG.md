# Cambios

Lo que cambia entre versiones, en corto. Las razones largas viven en `docs/decisiones.md`.

## Sin publicar

- **Módulo Compras** (se enciende en abarrotes, recaudería, distribuidora y todo): proveedores; recepción de mercancía escaneando el código del proveedor, con remisión, folio RC por sucursal y los envases que deja (canastilla, tarima, tote); factura del proveedor con renglones (el precio de compra solo vive ahí, el monto se deriva) o solo monto, vencimiento por días de crédito, ligada a sus recepciones y comparativo facturado contra recibido por producto; cuentas por pagar con vencidas y por vencer; pago desde la gaveta abierta (retiro) o por transferencia/depósito, ligado a factura o a cuenta, con anulación que compensa; libro de deuda y libro de envases solo-inserción. Cierra #22.
- **Folios configurables** (Ajustes › Folios): el prefijo de cada documento lo elige el negocio (hasta 4 letras o números, o ninguno), o una sola numeración corrida para todo. El primer arranque lo pregunta en su propio paso: una cuenta por documento o una sola, y la letra: la de la sucursal (su código delante: MTZ-00001), la que escribas para las notas de caja, o ninguna. El contador va por documento y por sucursal, así que cambiar la letra no reinicia la cuenta.
- **Módulos Retornables y Almacenes**, conjuntos aparte de Compras y Salidas, con sus permisos (`retornables.*`, `almacenes.*`), su pestaña y su interruptor; retornables necesita compras. Ajustes ya no mezcla enlaces de Admin. Mapa de módulos en `docs/arquitectura.md`.
- **Almacenes**: sucursal tipo almacén (frigorífico o bodega: solo guarda a granel, sin caja, etiquetas ni conteos) y traspasos a granel (kilos y cajas sin escanear, folio TG, sale y entra en la misma transacción, idempotente, cancelable). De un almacén solo a la matriz; a un almacén lo etiquetado vuelve al granel (sus etiquetas se dan de baja); a una tienda lo etiquetado va solo con salida escaneando. Buscador de productos compartido en `/productos/buscar`.
- **Ajustes** con barra lateral por secciones (Para ti, Negocio y ticket, Módulos, Etiqueta, Caja); el diseñador de ticket vive dentro.
- **Canastillas**: saldo por ruta; en rechazo parcial se cargan en proporción a lo que el cliente se quedó.
- **PWA instalable** con aviso de versión nueva; semi sin conexión queda como #21.
- **Letra chica** y modo compacto que compacta también la cinta; cinta fija al desplazarse; báscula en caja solo si hay productos por kilo.
- **Recepción**: canto por caja al recibir, diferencias en la bandeja de revisión y supervisiones con folio SV.

## 0.2.0 · 24 de septiembre de 2026

El sistema deja de ser solo para la planta de carne y se vuelve un punto de venta y etiquetador por módulos para negocios pequeños.

- **Módulos por negocio**: etiquetas y producción, pedidos, salidas y recepción, rutas y conteos se encienden o apagan en Ajustes › Sistema; caja, inventario y administración van siempre. Un módulo apagado desaparece de la cinta, de los roles y de sus pantallas, y no se apaga con trabajo abierto.
- **Primer arranque**: con la base vacía, una pantalla por pasos pide idioma, apariencia, negocio y giro (abarrotes, recaudería, distribuidora, planta con todo), sucursal principal y el primer administrador. Las semillas ya solo crean los roles base.
- **Tres idiomas**: inglés por defecto, español y alemán, por usuario. Todo lo que ve una persona pasa por traducción, incluidos los avisos y el JS.
- **Ajustes**: preferencias por usuario (idioma, tema, densidad, tamaño de letra) que se aplican al elegir; ajustes del sistema (etiqueta, caja) y **diseño del ticket** con vista previa en vivo: logo, nombre, lema, dirección, teléfonos, identificación fiscal, leyendas, papel de 80 o 58 mm.
- **Unidades litro y metro**, fraccionables como el kilo; la báscula solo pesa kilos.
- **Interfaz**: formularios a todo lo ancho con campos en rejilla, opciones grandes tipo tarjeta, avisos como toast flotante, el tema se aplica sin recargar, modo claro por defecto, ticket térmico limpio y hojas de trabajo legibles.
- **Licencia** Apache 2.0 con NOTICE; README por módulos.

## 0.1.0 · 18 de septiembre de 2026

Primera versión completa para la planta: pedidos, producción con merma, etiquetas EAN-13 de identidad con báscula por Web Serial, salidas con doble escaneo y recepción, caja con corte, conteos con cargos, rutas de reparto con la parada del chofer en el teléfono, crédito de ruta, cobranza, canastillas, convenios, precios por sucursal, promociones y autorización diferida.
