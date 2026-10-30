# Requerimientos y diseño

Fuente principal: enunciado «Proyecto-1.pdf», NEOBANK GT, Base de Datos I.
Los materiales de Municipalidad, inmobiliaria, JOIN, funciones y reglas de Codd
son referencias de aprendizaje; sus entidades no se incorporaron al banco.

## Cobertura funcional

| Requisito | Implementación |
|---|---|
| RF-01 Clientes | TB_CLIENTE, TB_TIPO_CLIENTE, SP01 y auditoría de altas |
| RF-02 Cuentas | TB_CUENTA, TB_TITULAR_CUENTA, SP02 y SP11 |
| RF-03 Operaciones | TB_MOVIMIENTO, TB_TRANSFERENCIA, SP03-SP06 y SP14 |
| RF-04 Tarjetas | TB_TARJETA, consumos/pagos, SP09-SP10, SP12-SP13 y SP16 |
| RF-05 Plazos fijos | TB_PLAZO_FIJO, SP08, SP15 y F02 |
| RF-06 Moneda extranjera | TB_MONEDA, TB_TIPO_CAMBIO, TB_CONVERSION_MONEDA, SP07, SP20 y F04 |
| RF-07 Seguridad y auditoría | TB_USUARIO, TB_OPERACION, TB_EVENTO_AUDITORIA, SP19 y principal SQL |

## Reglas de negocio

| Regla | Mecanismo y verificación |
|---|---|
| RN-01 CUI/NIT únicos | Validación de SP01 e índices únicos filtrados; duplicados rechazados |
| RN-02 Varios productos/titulares | Claves foráneas y tabla TB_TITULAR_CUENTA con clave compuesta |
| RN-03 Cliente activo para contratar | SP02, SP08, SP11 y SP12 validan estado del cliente |
| RN-04 Cuentas bloqueadas/cerradas | Se rechazan operaciones de saldo y resolución interbancaria |
| RN-05 No superar fondos | Comprobación de saldo bajo bloqueo transaccional y CHECK no negativo |
| RN-06 Débito/crédito relacionados | Dos movimientos y tabla TB_TRANSFERENCIA_MOVIMIENTO |
| RN-07 ROLLBACK ante error | TRY/CATCH y XACT_ABORT; prueba provoca fallo después del débito |
| RN-08 Referencia, fecha, monto, estado | Registro global único más registros de cada producto y sus movimientos |
| RN-09 Estados interbancarios | Pendiente, Confirmada y Rechazada; SP14 sólo resuelve pendientes |
| RN-10 Conservar cambio aplicado | Valor histórico en TB_CONVERSION_MONEDA con ocho decimales |
| RN-11 Límite de crédito | SP09 y restricciones de saldo utilizado/límite |
| RN-12 Tarjetas bloqueadas | SP09/SP13 rechazan consumos; un pago de deuda sigue permitido |
| RN-13 Datos del plazo fijo | Monto, tasa, días, inicio/vencimiento e identificación de origen |
| RN-14 Conservar movimientos | Triggers de inmutabilidad, referencia al original e índice de reverso único |
| RN-15 Identificar ejecutor | Usuario de auditoría validado y principal SQL de la conexión |

## Consultas y funciones obligatorias

C01: clientes activos y cuentas, incluidos clientes sin cuentas mediante LEFT JOIN.
C02: cuentas de ambos tipos mediante agrupación y HAVING.
C03: últimos diez movimientos, con identificador para desempatar fechas.
C04: ausencia de movimientos recientes mediante NOT EXISTS.
C05: depósitos/retiros por cliente, período y moneda mediante CASE.
C06: plazos activos con vencimiento desde hoy hasta treinta días después.
C07: utilización de crédito estrictamente superior al 80%.
C08: captaciones por tipo y moneda sin unir cotitulares.
C09: primeros cinco clientes por moneda mediante CTE y ROW_NUMBER.
C10: estado de cuenta con SUM OVER y saldo acumulado.
C11: cantidades y porcentajes de los tres estados, incluidos estados sin filas.
C12: cuentas, inversiones y deuda agregadas por separado antes de consolidar.

Las funciones F01-F04 reciben parámetros y consultan registros existentes.
Su fórmula, unidades y comportamiento ante datos faltantes se explican en
`GUIA_DEL_CODIGO.md` y en los comentarios de `03_funciones.sql`.

## Modelo relacional y normalización

El archivo `MODELO_ER.md` representa las relaciones del esquema final. Se
conserva el diagrama original como referencia en `referencia/Diagrama_original.png`.
El esquema final tiene 22 tablas de negocio y control, sin contar tablas internas
de SQL Server o diagramas de SSMS.

- Primera forma normal: cada columna contiene un valor escalar; los titulares,
  consumos, pagos y movimientos se registran en filas independientes.
- Segunda forma normal: las entidades principales tienen claves simples. Las
  relaciones TB_TITULAR_CUENTA y TB_TRANSFERENCIA_MOVIMIENTO tienen claves
  compuestas y no guardan atributos dependientes de una parte de esa clave.
- Tercera forma normal: nombres de tipos, monedas, bancos y usuarios se guardan
  en sus entidades; las operaciones contienen referencias mediante claves
  foráneas. No se repiten nombres de clientes o bancos en los movimientos.

Se conservan atributos financieros del modelo original: saldo vigente, deuda
vigente, vencimiento pactado y cotización aplicada. Los saldos se mantienen
transaccionalmente; los importes de una conversión y su tasa aplicada son hechos
históricos. La documentación distingue estos valores de los cálculos de reporte.
Una revisión formal de dependencias debe considerar esa semántica contractual
y temporal, no asumir que son datos descriptivos de un catálogo.

## Decisiones donde el enunciado no da una fórmula

1. Interés simple anual con base de 365 días; no se implementan impuestos ni comisiones.
2. GTQ/USD: cotización = unidades destino por una unidad origen; se conserva
   la cotización más reciente activa con fecha no futura.
3. Fondos interbancarios: se debitan al solicitar el envío. Un rechazo crea
   un movimiento compensatorio; no elimina el débito.
4. Cuentas compartidas: el resumen individual muestra el saldo íntegro por
   titular; el total institucional cuenta cada cuenta una sola vez.
5. Fechas de reportes: intervalo cerrado al inicio y abierto al final
   `[desde,hasta)`. El vencimiento próximo incluye el día actual y el día 30.
6. Referencias de operación: máximo 40 caracteres. Los movimientos de una
   transferencia añaden `-D`/`-C` para distinguir débito y crédito.
7. Una tarjeta de crédito usa su cuenta vinculada para determinar la moneda.

Estas decisiones son visibles y pueden ajustarse si el docente define otra
convención. No se incorporó una interfaz, porque no forma parte del enunciado.
