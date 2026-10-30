/* Abrir y ejecutar en SSMS para recorrer el proyecto instalado.
   Todas las instrucciones de este archivo son de consulta.
   Cambiar USE si se desea inspeccionar otra copia de pruebas del proyecto. */
USE NEOBANK_GT;
GO
-- 1. Confirmar la base seleccionada y los objetos desarrollados.
SELECT DB_NAME() AS base_actual;
SELECT name AS procedimiento FROM sys.procedures
WHERE schema_id=SCHEMA_ID('dbo') AND name LIKE 'SP[0-9][0-9][_]%' ORDER BY name;
SELECT name AS funcion FROM sys.objects
WHERE schema_id=SCHEMA_ID('dbo') AND type='FN' AND name LIKE 'F0%' ORDER BY name;

-- 2. Productos y saldos de los clientes ficticios; no expone CUI/NIT ni claves.
SELECT c.nombre,cu.numero_cuenta,t.nombre AS tipo,mo.codigo AS moneda,cu.saldo,cu.estado
FROM dbo.TB_CLIENTE c
JOIN dbo.TB_TITULAR_CUENTA tc ON tc.id_cliente=c.id_cliente
JOIN dbo.TB_CUENTA cu ON cu.id_cuenta=tc.id_cuenta
JOIN dbo.TB_TIPO_CUENTA t ON t.id_tipo_cuenta=cu.id_tipo_cuenta
JOIN dbo.TB_MONEDA mo ON mo.id_moneda=cu.id_moneda
ORDER BY c.id_cliente,cu.id_cuenta;

-- 3. Cada función toma identificadores de registros existentes.
DECLARE @cuenta int=(SELECT id_cuenta FROM dbo.TB_CUENTA WHERE numero_cuenta='DEMO-GTQ-1'),
 @tarjeta int=(SELECT id_tarjeta FROM dbo.TB_TARJETA WHERE numero_tarjeta='DEMO-CREDITO-001'),
 @plazo int=(SELECT id_plazo_fijo FROM dbo.TB_PLAZO_FIJO WHERE referencia='DEMO-PLAZO'),
 @gtq int=(SELECT id_moneda FROM dbo.TB_MONEDA WHERE codigo='GTQ'),
 @usd int=(SELECT id_moneda FROM dbo.TB_MONEDA WHERE codigo='USD');
SELECT dbo.F01_SALDO_DISPONIBLE(@cuenta) AS saldo_disponible,
 dbo.F02_INTERES_PLAZO_FIJO(@plazo) AS interes_al_vencimiento,
 dbo.F03_UTILIZACION_TARJETA(@tarjeta) AS utilizacion_porcentaje,
 dbo.F04_CONVERTIR_MONEDA(765,@gtq,@usd,GETDATE()) AS conversion_gtq_a_usd;

-- 4. Estados de las transferencias simuladas y movimiento de devolución.
SELECT referencia,tipo_transferencia,monto,estado,fecha_transferencia
FROM dbo.TB_TRANSFERENCIA ORDER BY id_transferencia;
SELECT m.referencia,m.monto,m.id_movimiento_original,t.nombre AS tipo
FROM dbo.TB_MOVIMIENTO m JOIN dbo.TB_TIPO_MOVIMIENTO t ON t.id_tipo_movimiento=m.id_tipo_movimiento
WHERE m.id_movimiento_original IS NOT NULL;

-- 5. Auditoría de las operaciones: referencia, operador y fecha.
SELECT TOP(15) o.referencia,u.nombre_usuario,o.fecha_operacion
FROM dbo.TB_OPERACION o JOIN dbo.TB_USUARIO u ON u.id_usuario=o.id_usuario
ORDER BY o.fecha_operacion DESC,o.referencia;
-- Abrir 07_consultas.sql para ejecutar C01-C12 y editar sus parámetros iniciales.
