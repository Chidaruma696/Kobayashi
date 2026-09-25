# Arquitectura de primer nivel

Kobayashi es un solo sistema y una sola base de datos, partido en **módulos**. Un módulo es un conjunto aparte: sus tablas, sus reglas, sus permisos y su pestaña en la cinta. Se enciende o se apaga por negocio (el giro elegido al arrancar es solo un preset; después manda Ajustes › Módulos). Apagado, desaparece de la cinta, de los roles y de sus pantallas; sus datos se quedan y no se apaga con trabajo abierto. Nada nuevo se mete "dentro" de un módulo que ya existía: si es otra cosa, es otro módulo.

## Núcleo (siempre encendido)

| Conjunto | Qué es | Tablas propias | Permisos | Pestaña |
|---|---|---|---|---|
| **Caja** | Vender, ticket, gaveta, cortes, retiros, devoluciones, abonos. | ventas, venta_lineas, pagos, cortes, retiros, devoluciones, abonos | `caja.*` | Caja |
| **Inventario** | Existencias por sucursal y producto, kardex, entradas y ajustes a mano. Es la única puerta para mover existencias (`Inventario.mover!`). | existencias, movimientos | `inventario.*` | Inventario |
| **Administración** | Catálogos y gente: productos, códigos, promociones, precios por sucursal, usuarios, roles, sucursales. | productos, codigos_barras, promociones, precios, usuarios, roles, sucursales | `admin.*` | Admin |
| **Ajustes** | Preferencias de cada persona (idioma, tema, densidad, letra) y del negocio (ticket, moneda, etiqueta, caja, módulos). Es otra cosa que Admin: Admin da de alta, Ajustes configura. | ajustes | `admin.usuarios` para lo del sistema | Inicio › Ajustes |
| **Revisión** | La bandeja de autorización diferida: lo que hubiera necesitado a un supervisor y pasó con motivo. | revisiones, cargos | `revisiones.*` | Inicio |

## Módulos

| Módulo | Qué es | Tablas propias | Permisos | Pestaña | Necesita |
|---|---|---|---|---|---|
| **Compras** | Proveedores, recepción de mercancía (entrada con proveedor y remisión), factura del proveedor con renglones, cuentas por pagar, pago desde la gaveta. Sin costo en inventario. | proveedores, recepciones, recepcion_lineas, facturas_proveedor, factura_proveedor_lineas, movimientos_proveedor, pagos_proveedor | `compras.*` | Compras | — |
| **Retornables** | Canastillas, tarimas y totes que el proveedor deja y se le deben: libro por proveedor, devoluciones, ajustes. La recepción los anota solo si este módulo está encendido. | envases_proveedor | `retornables.*` | Retornables | Compras |
| **Almacenes** | Sucursales tipo *almacén* (frigorífico o bodega externa: solo guardan a granel, sin caja, etiquetas ni conteos) y traspasos a granel entre sucursales sin escanear. | traspasos, traspaso_lineas (y el tipo `almacen` en sucursales) | `almacenes.*` | Almacenes | — |
| **Etiquetas** | Etiquetas de identidad EAN-13 (paquete, caja, tarima), báscula, producción con merma. | etiquetas, producciones | `etiquetas.*`, `produccion.*` | Etiquetas | — |
| **Pedidos** | Las tiendas y los clientes piden; la matriz surte renglón por renglón. | pedidos, pedido_lineas | `pedidos.*` | Pedidos | — |
| **Salidas** | Traspasos escaneando entre sucursales, verificación por segunda persona, sello, envío, recepción paquete por paquete, supervisión. | salidas, salida_etiquetas, salida_lineas, supervisiones | `salidas.*` | Salidas | — |
| **Rutas** | Reparto: viajes, chofer, entregas, rechazo, cobranza, crédito, canastillas de clientes, convenios, zonas. | viajes, paradas, movimientos_credito, movimientos_canastilla, tipos_canastilla, convenios, zonas, rutas, clientes | `rutas.*`, `cobranza.*`, `canastillas.*` | Rutas | Pedidos, Salidas |
| **Conteos** | Conteos físicos escaneando; el faltante se carga al responsable. | conteos, conteo_lineas | `conteos.*` | Conteos | — |

## Reglas transversales

- **Una sola puerta al inventario**: todo pasa por `Inventario.mover!`, que escribe el movimiento y la existencia en la misma transacción. Ningún módulo toca `existencias` directo.
- **Libros solo-inserción** para lo que es dinero o deuda: crédito de clientes, deuda con proveedores, canastillas, envases. El saldo es la suma; nada se edita ni se borra; corregir es asentar.
- **Folios por sucursal** con prefijo por documento (B venta, C corte, RC recepción, TG traspaso a granel, SV supervisión…), únicos por sucursal.
- **Idempotencia** en lo que captura el navegador y podría reenviarse (venta, recepción, traspaso): una clave, y la misma clave devuelve el mismo documento.
- **Autorización diferida, sin PIN**: quien tiene el permiso lo hace a su nombre; quien no, lo hace con motivo y cae en Revisión.
- **Tipos de sucursal**: matriz (produce, etiqueta y de ahí sale todo), tienda (vende, todo con etiqueta), almacén (solo a granel). Las reglas se derivan del tipo, nunca de una bandera aparte.
- **i18n completa** (inglés por defecto, español, alemán): todo texto visible pasa por `t(...)`, incluidos avisos, errores y JS.

## Cómo se agrega un módulo

1. Clave en `Modulo::OPCIONALES` (y en `DEPENDE` si cuelga de otro, en `GIROS` donde arranque encendido, en `comprobar_apagable!` si puede tener trabajo abierto).
2. Sus permisos con prefijo propio en `Permiso` y el prefijo en `Modulo::PERMISOS`; el rol supervisor suele llevar `prefijo.*`.
3. `Ajuste::DEFAULTS["modulos.<clave>"] = "1"`.
4. Sus controladores con `pestana :<clave>` y `modulo :<clave>`; su pestaña en `RibbonHelper::PESTANAS`.
5. Textos `modulos.<clave>.{nombre,que}`, `cinta.pestanas.<clave>`, permisos, en es/en/de.
6. Tests: el flujo, y que apagado desaparece de la cinta y sus pantallas responden 404.
