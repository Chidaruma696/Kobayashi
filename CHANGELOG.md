# Cambios

Lo que cambia entre versiones, en corto. Las razones largas viven en `docs/decisiones.md`.

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
