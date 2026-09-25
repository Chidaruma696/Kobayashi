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
El PIN frenaba el flujo: si no había admin y urgía el pedido, nadie podía hacer nada. Lo que hacía el sistema anterior (pedir aprobación y esperar) también bloquea, solo que de otra forma. Ahora la operación se hace con motivo y queda a nombre de quien la hizo en una bandeja; el supervisor la aprueba u observa al final del día, y lo observado se puede cargar. Bajar precio en caja iba a seguir con PIN porque ahí el hueco es dinero directo; el 24 de septiembre se quitó el PIN de todo el sistema: bajar precio también queda por revisar, con lo que se dejó de cobrar como valor.

## Doble escaneo sí, doble pesada no
Surtir escaneando y que otra persona verifique escaneando antes de cargar. La doble pesada a ciegas del sistema anterior (romaneo + aduana) la descarté: es lenta y el problema real era la falta de trazabilidad, no el peso. Pero mandar sin escanear tiene que poder pasar: renglón sin etiqueta o sellar sin verificar, con motivo, y cae a revisión.

## Contado en el punto de venta, crédito en ruta
En mostrador todo es de contado, punto. En la ruta el cliente sí tiene crédito y de varios tipos (nota por nota, límite, semanal, contado abonando, especial), porque así funciona el negocio. Me confundí una vez y lo hice todo de contado; corregido.

## La báscula desde el navegador
Web Serial con Kana (mi librería). Vendorizada dentro del repo para no depender de npm en la planta.

## Canastillas en un rechazo parcial: se regresan con la mercancía (decidido 25 sept 2026)
Estuvo pendiente hasta ver la calle. La regla real es simple: lo que el cliente rechaza se regresa al camión con todo y canastilla. Así que al cerrar la parada al cliente se le cargan las canastillas en proporción a las cajas que sí se quedó (rechazó 2 de 5 cajas → se le cargan 3 de 5 canastillas, redondeando), y el resto sigue a bordo. Nada de preguntarle al chofer ni de depender de que registre una devolución.

## La caja entra sola a la salida (24 sept 2026)
Etiquetar contra el pedido y luego volver a escanear cada caja para meterla a la salida era doble trabajo, y en el sistema anterior el armado incremental del traspaso era lo que hacía rápido el surtido. Así que la caja que nace de un renglón cae en la salida que se está armando para ese destino (o la abre). El escaneo de quien carga el camión se queda: ese es el control, no el del surtidor.

## Etiqueté mal: baja con motivo, no borrar (24 sept 2026)
El sistema anterior no dejaba tirar un error una vez ligado al traspaso. Aquí se da de baja con motivo desde la misma lista: sale del renglón y de la salida en preparación, y la caja se queda con lo que de verdad trae. Si la salida ya se selló o viajó, se resuelve en la recepción; nada se borra.

## Lo que llega sin venir en la salida es sobrante, no un error (24 sept 2026)
Pasaba que se hacían cajas por fuera del pedido y viajaban sin ir en el traspaso; en la tienda "no pasaban". Aquí eso ya casi no puede ocurrir (etiquetar sin pedido exige motivo y revisión), pero si un paquete llega sin venir en la salida, se recibe como sobrante con motivo: sale del origen, entra a la tienda y queda por revisar. Que la mercancía no se pierda y el hueco se vea.

## El precio no frena el traspaso; frena la venta (24 sept 2026)
En el sistema anterior no se podía enviar sin ponerle precio a todo, y un producto nuevo sin precio retenía el traspaso entero. Aquí la salida y la recepción pasan siempre; lo que no tiene precio en esa tienda no se vende hasta que lo tenga (antes se cobraba en $0, que era peor).

## La producción no tiene nada que ver con los pedidos (24 sept 2026)
Producción es solo esto: entra una mercancía en una cantidad y salen las etiquetas de lo que se saca de ella; al cerrar, la diferencia es merma. Ni pedido, ni motivo, ni PIN, ni revisión. Lo que sale queda vivo en la matriz y se surte a los pedidos escaneándolo o etiquetando contra el renglón, como todo lo demás. (Lo tenía enredado con los pedidos y hasta con el PIN viejo; me lo dijeron tres veces.)

## Folios por sucursal, únicos por sucursal (24 sept 2026)
Cada tienda numera lo suyo (su B-00001, su C-00001), como el sistema anterior, pero el índice los exigía únicos en todo el sistema: la segunda tienda no podía ni abrir caja. Salió al cargar datos de prueba con tres sucursales; nunca se había probado con más de una. Ahora la unicidad es por sucursal. Las listas y búsquedas ya están acotadas a la sucursal del usuario, así que el folio corto sigue sirviendo.

## La paleta es Kobayashi (24 sept 2026)
El sistema se llama como ella, así que los colores salen de ella: el rosa salmón claro de su pelo es la marca (la cinta va en ese rosa; los botones en un rosa más hondo para que se lea), el granate de la corbata es el acento de peligro y los grises son cálidos como su oficina. Y una regla de interfaz: nada de enlaces pelones; lo que hace algo es un botón, y lo que apunta a otro documento (un folio, un cliente) es un chip con fondo. Los estilos viven en `app/assets/tailwind/application.css` como clases (`btn`, `enlace`, `chip-folio`, `card`, `tabla`, `badge`) para no repetir utilidades en cada vista.

## Apache 2.0 en vez de MIT (24 sept 2026)
Quiero que se use, se cambie y hasta se venda; lo único que pido es el crédito. MIT solo obliga a conservar el aviso en el código; Apache 2.0 obliga además a conservar el NOTICE y a marcar lo que se cambie, y es estándar. En el NOTICE va la forma del crédito.

## Tres idiomas, inglés por defecto (24 sept 2026)
El sistema nació en español porque el negocio habla español, y así se quedan los modelos, las tablas y las claves. Pero la interfaz ahora va en inglés, español y alemán: cada usuario elige el suyo en Ajustes y, si no ha elegido, manda el idioma del navegador y luego el inglés. Todo lo que ve una persona pasa por `t()`: vistas, avisos de los controladores, los `raise` de los modelos (con `I18n.t`) y los textos del JS (`window.T` en el layout). Los nombres de datos (permisos, tipos de crédito, tipos de movimiento) tienen su español en el código como último recurso. Los tests siguen en español (`I18n.default_locale = :es` en test_helper), porque aseguran el texto que se escribió, no la traducción.

## El primer administrador se crea desde la pantalla, no desde las semillas (24 sept 2026)
Las semillas creaban `admin/admin1234`, una matriz, una tienda y productos de muestra: cómodo para desarrollar, peligroso en producción y confuso para quien instala. Ahora, mientras no haya ningún usuario activo, cualquier ruta lleva a `/instalar`: nombre del negocio, matriz con su código y el primer administrador, todo en una transacción, y entra con él. Las semillas solo dejan los roles base (`Rol.base!`). Los datos de prueba viven en un guion aparte, fuera del repo.

## Un solo esquema, módulos que se apagan; el giro es un preset (24 sept 2026)
El sistema deja de ser solo para la planta de carne: abarrotes, recauderías, distribuidoras. La tentación era una "base de datos dinámica" por giro; no. Lo que cambia por negocio no son las tablas, son los módulos que se ven: etiquetas, pedidos, salidas, rutas y conteos son interruptores en `Ajuste` (`modulos.*`), caja e inventario van siempre. El giro que se elige al arrancar solo enciende un conjunto (`Modulo::GIROS`), y en Ajustes › Sistema se cambia cuando haga falta. Un módulo apagado no está en la cinta, ni en los roles, ni responde sus pantallas (dice que está apagado, no 404); sus datos se quedan y no se apaga con trabajo abierto. Rutas arrastra pedidos y salidas porque un reparto es una salida a un cliente que pidió. Restaurante queda fuera: mesas y comandas son otro dominio, no un módulo.

## El ticket se diseña viendo el ticket (24 sept 2026)
Los datos del negocio que van impresos (logo, nombre, lema, dirección, teléfonos, identificación fiscal, leyendas, ancho del papel) se editan en Ajustes › Ticket con el ticket real al lado, dentro de un iframe con su misma hoja de estilos, y cada tecla se refleja al momento. El logo se guarda como data URL en `ajustes` (menos de 300 KB, sin Active Storage) porque un ticket térmico lo quiere chico y en negro. El ticket mismo es puro negro, letra chica y densa, tabla con encabezado y total grande: lo que se imprime bien en térmica de 80 o 58 mm.

## Núcleo abierto completo; lo de pago, aparte y sin capar (24 sept 2026, decidido, sin implementar)
Quiero que Kobayashi se use y también vivir de él, como hacen Odoo y Headwind: el código abierto es completo y honesto, y lo de pago es un añadido. Con Apache 2.0 nada de lo que esté en este repo se puede cerrar después (cualquiera lo forkea y quita el candado), así que la regla es una: **lo de pago nunca entra a este repo**. Vivirá como un motor de Rails aparte, en su propio repo privado y con su propia licencia, que el núcleo carga si está instalado; `Modulo` es el sitio natural para que un módulo diga "requiere licencia", y el Acerca de dirá qué plan corre. La licencia será una clave firmada que se comprueba en el propio equipo, sin llamar a ningún servidor: es software para negocios de barrio, no vale la pena una guerra de DRM.

Qué es de pago y qué no. De pago: lo que cuesta dinero real o trabajo mío continuo, que es lo que la gente paga sin sentirse estafada: la facturación electrónica (PAC y timbres), varias tiendas sincronizadas en la nube con respaldos, reportes avanzados, avisos por WhatsApp, y sobre todo la **renta**: hosting, actualizaciones y soporte, que es donde de verdad está el ingreso mensual. Gratis y sin límites artificiales: todo lo que hoy existe, los idiomas, los temas, el número de usuarios, sucursales o productos. Cobrar por eso es lo que hace que la gente huya a un fork, y con razón.

## Compras sin costo, con un solo camino de pago (25 sept 2026)
El módulo de compras se trae del sistema anterior, que ya lo tenía estable, pero adaptado a cómo funciona Kobayashi y sin repetir lo que allá dolía.

- **Sin órdenes de compra.** El negocio pide por teléfono y llega el camión; lo que se captura es lo que llegó (recepción) y lo que se cobra (factura). Una orden sería papel que nadie llena.
- **La recepción es una entrada al inventario con proveedor y remisión.** Se escanea el código del proveedor, el PLU o la clave, y entra a la sucursal que recibe, con su folio RC por sucursal. Ahí mismo se anotan las canastillas, tarimas y totes que deja el proveedor: eso es un libro aparte del de canastillas con clientes y choferes, porque es otra deuda (la nuestra con él).
- **Sin costo en el inventario.** El precio de compra solo vive en los renglones de la factura, y de ahí se deriva el monto. El inventario sigue sin saber cuánto costó nada: no hay costo promedio, ni utilidad por producto, ni valuación a costo. Se decidió así a propósito; si un día hace falta, la factura ya lo tiene renglón por renglón.
- **La factura es lo único que crea deuda**, y se captura cuando llega, después de la recepción, ligándola a las recepciones que cubre. Facturado contra recibido se compara por producto y se enseña; es un aviso, no un candado, porque en la práctica el papel y el camión no cuadran siempre y hay que poder seguir.
- **Un solo camino de pago.** El pago en efectivo sale de la gaveta abierta de la sucursal como un retiro (así cuadra el corte), y en la misma transacción abona al libro del proveedor. Transferencia y depósito no tocan la caja. Sin caja abierta no hay pago en efectivo. El sistema anterior tenía dos caminos (pago suelto y pago desde caja) y el saldo se desviaba.
- **El libro del proveedor solo se agrega.** Cargo (factura), abono (pago), ajuste (cancelación, anulación). Nada se edita ni se borra; anular un pago compensa con un ajuste y devuelve el efectivo a la gaveta solo si el corte sigue abierto. Cancelar una factura exige anular antes sus pagos. Todo con el proveedor bloqueado, para que dos pagos a la vez no pasen de lo que resta.
- **Folios por sucursal e idempotencia** en la recepción (una clave del navegador), para que el doble clic no meta la mercancía dos veces.

## El almacén externo guarda a granel; un camión de cinco mil cajas no se escanea (25 sept 2026)
Lo tenía mal entendido: pensé que "almacén" era un cajón dentro de la sucursal (bodega fría, piso de venta). No: es el **frigorífico ajeno**, lejos, con renta, donde la mercancía llega a granel y se guarda a granel. Ahí nadie procesa ni etiqueta, y no tiene sentido escanear cinco mil cajas a la entrada ni a la salida. Se resuelve como en el sistema anterior, que ya lo tenía bien:

- **Tres tipos de sucursal**, y las reglas se derivan del tipo, nunca de una bandera que alguien tenga que acordarse de marcar: *matriz* (produce, etiqueta, de ahí sale todo), *tienda* (vende; todo lo vendible con etiqueta) y *almacén* (solo guarda a granel: sin caja, sin etiquetas, sin conteos; su pestaña de Caja, Etiquetas y Conteos ni aparece).
- **Traspaso a granel**: kilos y cajas de una sucursal a otra sin escanear. Sale del origen y entra al destino en la misma transacción (dos renglones de kardex con el mismo folio TG), con clave de idempotencia para que el doble clic no meta el camión dos veces. Se cancela con motivo y la mercancía regresa; las etiquetas bajadas no reviven.
- **De un almacén la mercancía solo va a la matriz.** Ahí se concentra y de ahí sale a las tiendas. Un almacén no surte tiendas.
- **A un almacén lo etiquetado vuelve al granel.** Fuera de Kobayashi nadie garantiza que el paquete siga siendo ese paquete, así que las etiquetas vivas de ese producto en el origen se dan de baja, las más viejas primero, hasta cubrir lo que se manda, con el folio como motivo. El traspaso anota cuántas bajó.
- **A una tienda o a la matriz lo etiquetado no va a granel.** Si el producto tiene etiquetas vivas en el origen, el traspaso se niega y manda a usar una salida escaneando: la etiqueta es su identidad y así se recibe paquete por paquete. Lo que no tiene etiqueta (abarrotes, insumos, sin módulo de etiquetas) sí viaja a granel entre cualquier par de sucursales.
- Una salida escaneando no puede tener un almacén como destino, ni un pedido pedirle a uno: a un almacén se manda a granel.

## Lo nuevo va en módulos propios; Admin y Ajustes no se mezclan (25 sept 2026)
Metí los envases del proveedor dentro de Compras y los traspasos a granel dentro de Salidas, y puse enlaces de Admin en la barra de Ajustes. Corrección del usuario: cada capacidad nueva es un conjunto aparte, con su interruptor, sus permisos y su pestaña, y no se cuela en lo que ya había. Ahora **Retornables** (envases del proveedor; necesita Compras) y **Almacenes** (almacén externo y traspasos a granel) son módulos. Admin da de alta (gente, catálogos, sucursales); Ajustes configura (preferencias, ticket, módulos): son cosas distintas y cada una tiene su sitio. El mapa completo, con tablas, permisos y pestaña por módulo, vive en `docs/arquitectura.md` y ahí se agrega cada módulo nuevo.

## El prefijo del folio lo elige el negocio (25 sept 2026)
La "B-" de la venta, la "C-" del corte y las demás estaban fijas en el código. Eso no es del sistema, es del negocio: hay quien quiere sus letras, quien no quiere ninguna, y quien quiere una sola numeración corrida para todo (F-00001 venta, F-00002 corte…). Ahora se configura en Ajustes › Folios. El contador va por documento y por sucursal, no por letra: cambiar la letra a media vida sigue la cuenta donde iba, y volver de la numeración única a la de por documento retoma la cuenta de cada uno. El prefijo admite hasta cuatro letras o números y puede ir vacío (sale solo el número). Y como es del negocio, se pregunta en el primer arranque, en su propio paso: una cuenta por documento o una sola para todo, y de dónde sale la letra: de la sucursal (su código va delante, MTZ-00001, y cada sucursal se distingue sola), la que escriba para las notas de caja, o ninguna. Lo demás queda con su letra de fábrica y se afina en Ajustes › Folios.

## La diferencia del corte no se frena, se revisa (25 sept 2026)
De Odoo me quedé con dos cosas del cierre de caja: contar la gaveta por billetes y monedas, que quita los errores de dedo al teclear un total, y un tope de diferencia autorizada. Odoo, al pasarse del tope, pide a un gerente ahí mismo. Aquí no: la caja se cierra igual, con motivo, y queda por revisar con el monto de la diferencia como valor, igual que un retiro sin permiso. Es la misma regla de siempre (autorización diferida): que al cierre no haya nadie con permiso no puede dejar la caja abierta toda la noche. El desglose se guarda en el corte para verlo después; sin tope (0, el de fábrica) nada cambia respecto a antes.

## La etiqueta es el lote (25 sept 2026)
Odoo lleva la caducidad por lote, con tres fechas (caducidad, alerta, retiro) y bloquea la entrega de lo vencido. Aquí no hay lotes ni falta que haya: cada paquete ya tiene identidad, así que la fecha vive en la etiqueta y sale de los días de vida del producto al momento de etiquetar. Una sola fecha, no tres. Y vender caducado no se frena: en una carnicería el que decide si el paquete va o no es el que lo tiene en la mano; el sistema lo marca en rojo al escanear, lo cobra y deja el renglón por revisar con su importe, como cualquier otra cosa hecha sin permiso. Lo que sí hace ruido es el tablero: lo vivo ya caducado y lo que caduca en los próximos días, para sacarlo antes de que llegue a la caja.

## El costo se reparte por lo que vale cada salida, y solo en la ficha (25 sept 2026)
Odoo reparte el costo del insumo entre los subproductos con un porcentaje fijo por producto en la lista de materiales. Aquí no hay lista de materiales: de un pollo sale lo que salga ese día. Así que el reparto es por valor de venta (el método de los coproductos de toda la vida): la pechuga se lleva más costo porque vale más, la merma no se lleva nada y la absorben las salidas. Eso deja el mismo margen en todas las salidas, y por eso el margen se enseña una vez, para toda la producción, y por renglón solo el costo por unidad contra el precio. El costo sale del último precio de compra en factura, se congela al abrir la producción y se queda en su ficha; no entra al kardex ni a la valuación, que siguen a precio de catálogo (decidido el 25 al hacer Compras). Y la merma esperada por producto es un aviso: pasarse cae a revisión con el exceso valuado, nadie se queda con la producción abierta esperando permiso.

## El pedido sugerido cuenta lo que ya viene en camino (25 sept 2026)
Las reglas de reabasto de Odoo pronostican con lo que hay más lo que está por llegar. Aquí igual, pero sin pronóstico: existencia más lo pendiente en pedidos abiertos de esa tienda. Si no se descontara lo pendiente, cada pedido nuevo volvería a pedir lo mismo hasta que llegara el camión. Es una sugerencia que se precarga en el formulario, no un pedido automático: la tienda lo ve, lo corrige y lo manda; la matriz no recibe nada que nadie haya mirado. Piezas enteras se redondean hacia arriba; sin máximo, se pide hasta el mínimo.

## El conteo parcial no toca lo que no se contó (25 sept 2026)
Odoo programa conteos por ubicación y ajusta cuant por cuant. Aquí el conteo era siempre de todo, y contar todo cierra la tienda media mañana. Ahora hay alcance: todo, o una línea o unos productos. En el parcial solo se ajusta lo elegido y las etiquetas de fuera no cuentan como no vistas ni mueren; escanear algo que no entra se rechaza antes de anotar nada, para que el conteo no se contamine. Sigue habiendo un solo conteo abierto por sucursal, aunque sea parcial: dos conteos a la vez sobre la misma existencia se pisan. Y la frecuencia por sucursal es solo un aviso en el tablero, no un conteo automático: contar lo hace una persona.

## El candado de compras es opcional y, aun cerrado, no frena (25 sept 2026)
Odoo tiene la política por producto de facturar sobre lo pedido o sobre lo recibido, y no deja pasar la factura. Cuando hice Compras decidí que facturado contra recibido fuera aviso y no candado, porque el papel y el camión no cuadran siempre. Eso se queda como está de fábrica. Lo nuevo es un candado que el negocio enciende si quiere, y aun encendido sigue la regla de la casa: la factura entra con motivo y cae a revisión con el exceso valuado al precio de la propia factura; quien tiene el permiso de exceder la registra a su nombre. Y ya que la comparación se hace al capturar, las recepciones que cubre se marcan ahí mismo, no después desde la ficha (que sigue sirviendo para lo que se ligue tarde).

## Apagar una base no apaga en silencio a quien la necesita (25 sept 2026)
El manifiesto de Odoo declara dependencias y al desinstalar avisa qué se va con ello. Aquí `DEPENDE` ya existía, pero solo por debajo: al guardar, la base de un dependiente encendido se volvía a encender sola, sin decir nada, y el que apagaba Pedidos se quedaba con Pedidos encendido sin saber por qué. Ahora encender arrastra lo que necesita (eso era razonable y se queda) y apagar una base con dependientes encendidos se rechaza diciendo quién la necesita; la pantalla lo enseña y marca o desmarca en cadena antes de mandar. Nada se apaga en cascada por el servidor: apagar de más sin decirlo es peor que negarse.

## El resumen del día es una hoja, no un correo (25 sept 2026)
El digest de Odoo manda KPIs por correo con periodicidad. Aquí el dueño de una tienda de barrio no lee correos: quiere el papel al cerrar o el mensaje en el teléfono. Así que el resumen del corte es la misma hoja de 80 mm de los tickets, sale sola al cerrar, se imprime y se comparte con lo que tenga el teléfono (Web Share; si no hay, se copia al portapapeles). Correo o WhatsApp automático, si un día hace falta, van encima de esto y probablemente en lo de pago (es trabajo continuo mío), no en el núcleo.

## Retornables es una sola pestaña con dos libros (25 sept 2026)
Ayer dejé Retornables como módulo aparte con una pestaña de un solo botón, y hoy se vio lo que era: un desperdicio. La observación del usuario fue la correcta: los envases del proveedor y las canastillas de clientes y choferes son en esencia lo mismo, cosas que van y vienen y que alguien debe, solo que con la contraparte al revés. Así que la pestaña Retornables junta las dos mitades y Rutas se queda con lo suyo. Lo que no se junta son las tablas: la deuda con el proveedor es nuestra y la de los clientes es de ellos; un cliente que debe cinco canastillas y un proveedor al que le debemos tres tarimas no se compensan. Para que el módulo pudiera vivir con cualquiera de las dos mitades nació `ALGUNO` en `Modulo`: Retornables necesita Compras o Rutas, no las dos, y un controlador puede exigir más de un módulo (canastillas pide Retornables y Rutas; envases, Retornables y Compras).

## Retornables no tiene pestaña: es inventario que va y viene (25 sept 2026)
Segunda corrección del usuario el mismo día: aun con las dos mitades, una pestaña para eso es un desperdicio. Tiene razón: canastillas y envases son inventario que sale y regresa, así que sus dos grupos van dentro de la pestaña Inventario, cada uno con su módulo base. El módulo sigue existiendo (interruptor, permisos, tablas) porque eso sí es aparte; lo que no hace falta es un sitio propio en la cinta. Regla que queda: un módulo no implica pestaña; la pestaña es de quien tiene varias acciones, y un módulo chico se asienta donde le toca.
