/* NEOBANK GT - C01 a C12. Intervalos de fecha: [desde, hasta).
   Cuentas compartidas: cada titular ve el saldo completo de sus cuentas.
   Los totales institucionales se calculan desde TB_CUENTA para no duplicarlos.
   Cambiar los parámetros antes de ejecutar en SSMS.
*/
DECLARE @id_cuenta int=1,
        @desde datetime=DATEADD(year,-1,GETDATE()),
        @hasta datetime=GETDATE(),
        @hoy date=CONVERT(date,GETDATE());

-- C01. Clientes activos, incluidos aquellos sin cuentas.
SELECT c.id_cliente,c.nombre,COUNT(tc.id_cuenta) AS cantidad_cuentas
FROM dbo.TB_CLIENTE c
LEFT JOIN dbo.TB_TITULAR_CUENTA tc ON tc.id_cliente=c.id_cliente
WHERE c.estado='Activo'
GROUP BY c.id_cliente,c.nombre;

-- C02. Clientes con cuentas monetarias y de ahorro simultáneamente.
SELECT c.id_cliente,c.nombre
FROM dbo.TB_CLIENTE c
JOIN dbo.TB_TITULAR_CUENTA tc ON tc.id_cliente=c.id_cliente
JOIN dbo.TB_CUENTA cu ON cu.id_cuenta=tc.id_cuenta
JOIN dbo.TB_TIPO_CUENTA t ON t.id_tipo_cuenta=cu.id_tipo_cuenta
GROUP BY c.id_cliente,c.nombre
HAVING MAX(CASE WHEN t.nombre='Monetaria' THEN 1 ELSE 0 END)=1
   AND MAX(CASE WHEN t.nombre='Ahorro' THEN 1 ELSE 0 END)=1;

-- C03. Últimos 10 movimientos; identificador desempata fechas iguales.
SELECT TOP(10) m.id_movimiento,m.fecha_movimiento,t.nombre AS tipo,
       m.referencia,m.monto,m.estado,m.descripcion
FROM dbo.TB_MOVIMIENTO m
JOIN dbo.TB_TIPO_MOVIMIENTO t ON t.id_tipo_movimiento=m.id_tipo_movimiento
WHERE m.id_cuenta=@id_cuenta
ORDER BY m.fecha_movimiento DESC,m.id_movimiento DESC;

-- C04. Sin movimientos en los últimos 90 días, incluidas cuentas sin historial.
SELECT c.id_cuenta,c.numero_cuenta,c.fecha_apertura,c.estado
FROM dbo.TB_CUENTA c
WHERE NOT EXISTS(SELECT 1 FROM dbo.TB_MOVIMIENTO m
  WHERE m.id_cuenta=c.id_cuenta
    AND m.fecha_movimiento>=DATEADD(day,-90,@hasta)
    AND m.fecha_movimiento<@hasta);

-- C05. Depósitos y retiros por cliente, separados por moneda.
SELECT c.id_cliente,c.nombre,mo.codigo AS moneda,
       SUM(CASE WHEN tm.nombre='Deposito' THEN m.monto ELSE 0 END) AS total_depositos,
       SUM(CASE WHEN tm.nombre='Retiro' THEN m.monto ELSE 0 END) AS total_retiros
FROM dbo.TB_CLIENTE c
JOIN dbo.TB_TITULAR_CUENTA tc ON tc.id_cliente=c.id_cliente
JOIN dbo.TB_CUENTA cu ON cu.id_cuenta=tc.id_cuenta
JOIN dbo.TB_MONEDA mo ON mo.id_moneda=cu.id_moneda
JOIN dbo.TB_MOVIMIENTO m ON m.id_cuenta=cu.id_cuenta
JOIN dbo.TB_TIPO_MOVIMIENTO tm ON tm.id_tipo_movimiento=m.id_tipo_movimiento
WHERE m.fecha_movimiento>=@desde AND m.fecha_movimiento<@hasta
  AND m.estado='Confirmado' AND tm.nombre IN('Deposito','Retiro')
GROUP BY c.id_cliente,c.nombre,mo.codigo;

-- C06. Plazos activos que vencen desde hoy hasta los próximos 30 días inclusive.
SELECT p.id_plazo_fijo,c.nombre,p.monto,p.tasa_interes,p.plazo_dias,
       p.fecha_vencimiento,mo.codigo AS moneda
FROM dbo.TB_PLAZO_FIJO p
JOIN dbo.TB_CLIENTE c ON c.id_cliente=p.id_cliente
JOIN dbo.TB_CUENTA cu ON cu.id_cuenta=p.id_cuenta_origen
JOIN dbo.TB_MONEDA mo ON mo.id_moneda=cu.id_moneda
WHERE p.estado='Activo' AND p.fecha_vencimiento>=@hoy
 AND p.fecha_vencimiento<DATEADD(day,31,@hoy);

-- C07. Tarjetas de crédito con utilización estrictamente superior a 80%.
SELECT t.id_tarjeta,c.nombre,t.limite_credito,t.saldo_utilizado,
 CAST(100.0*t.saldo_utilizado/NULLIF(t.limite_credito,0) AS decimal(12,4)) AS porcentaje
FROM dbo.TB_TARJETA t
JOIN dbo.TB_TIPO_TARJETA tt ON tt.id_tipo_tarjeta=t.id_tipo_tarjeta
JOIN dbo.TB_CLIENTE c ON c.id_cliente=t.id_cliente
WHERE tt.nombre='Credito' AND t.limite_credito>0
 AND t.saldo_utilizado>t.limite_credito*0.80;

-- C08. Captaciones por tipo de cuenta y moneda, sin multiplicar cotitulares.
SELECT t.nombre AS tipo_cuenta,mo.codigo AS moneda,COUNT(*) AS cantidad,
 SUM(c.saldo) AS saldo_total
FROM dbo.TB_CUENTA c
JOIN dbo.TB_TIPO_CUENTA t ON t.id_tipo_cuenta=c.id_tipo_cuenta
JOIN dbo.TB_MONEDA mo ON mo.id_moneda=c.id_moneda
GROUP BY t.nombre,mo.codigo;

-- C09. Cinco clientes con mayor saldo por moneda.
;WITH Saldos AS (
 SELECT c.id_cliente,c.nombre,mo.codigo AS moneda,SUM(cu.saldo) AS saldo_total
 FROM dbo.TB_CLIENTE c
 JOIN dbo.TB_TITULAR_CUENTA tc ON tc.id_cliente=c.id_cliente
 JOIN dbo.TB_CUENTA cu ON cu.id_cuenta=tc.id_cuenta
 JOIN dbo.TB_MONEDA mo ON mo.id_moneda=cu.id_moneda
 GROUP BY c.id_cliente,c.nombre,mo.codigo
), Ranking AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY moneda ORDER BY saldo_total DESC,id_cliente) AS posicion
 FROM Saldos
)
SELECT * FROM Ranking WHERE posicion<=5 ORDER BY moneda,posicion;

-- C10. Estado de cuenta. El saldo inicial se deriva del saldo vigente menos
-- todos los movimientos confirmados desde @desde (también posteriores a @hasta).
-- Convención: tipos de crédito y débito explícitos en el catálogo instalado.
;WITH Importes AS (
 SELECT m.*,tm.nombre AS tipo,
 CASE WHEN tm.nombre IN('Deposito','Transferencia recibida','Conversion recibida',
                        'Liquidacion plazo fijo','Reverso credito') THEN m.monto
      WHEN tm.nombre IN('Retiro','Transferencia enviada','Transferencia interbancaria',
                        'Conversion enviada','Constitucion plazo fijo','Pago de tarjeta',
                        'Consumo debito','Reverso debito') THEN -m.monto END AS importe
 FROM dbo.TB_MOVIMIENTO m JOIN dbo.TB_TIPO_MOVIMIENTO tm
 ON tm.id_tipo_movimiento=m.id_tipo_movimiento
 WHERE m.id_cuenta=@id_cuenta AND m.estado='Confirmado'
), Apertura AS (
 SELECT cu.saldo-COALESCE((SELECT SUM(i.importe) FROM Importes i
   WHERE i.fecha_movimiento>=@desde),0) AS saldo_inicial
 FROM dbo.TB_CUENTA cu WHERE cu.id_cuenta=@id_cuenta
)
SELECT i.id_movimiento,i.fecha_movimiento,i.referencia,i.tipo,i.monto,i.importe,
 a.saldo_inicial+SUM(i.importe) OVER(ORDER BY i.fecha_movimiento,i.id_movimiento
 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS saldo_acumulado
FROM Importes i CROSS JOIN Apertura a
WHERE i.fecha_movimiento>=@desde AND i.fecha_movimiento<@hasta
ORDER BY i.fecha_movimiento,i.id_movimiento;

-- C11. Incluye estados con cero registros. Intervalo [desde,hasta).
;WITH Estados AS (
 SELECT estado FROM (VALUES('Confirmada'),('Pendiente'),('Rechazada')) e(estado)
), Conteos AS (
 SELECT estado,COUNT_BIG(*) AS cantidad FROM dbo.TB_TRANSFERENCIA
 WHERE fecha_transferencia>=@desde AND fecha_transferencia<@hasta
 GROUP BY estado
)
SELECT e.estado,COALESCE(c.cantidad,0) AS cantidad,
 CAST(COALESCE(100.0*c.cantidad/NULLIF(SUM(COALESCE(c.cantidad,0)) OVER(),0),0)
 AS decimal(7,2)) AS porcentaje
FROM Estados e LEFT JOIN Conteos c ON c.estado=e.estado;

-- C12. Resumen por cliente y moneda. Agregaciones independientes evitan
-- multiplicar cuentas, inversiones y tarjetas entre sí.
;WITH Cuentas AS (
 SELECT tc.id_cliente,cu.id_moneda,SUM(cu.saldo) AS saldos
 FROM dbo.TB_TITULAR_CUENTA tc JOIN dbo.TB_CUENTA cu ON cu.id_cuenta=tc.id_cuenta
 GROUP BY tc.id_cliente,cu.id_moneda
), Inversiones AS (
 SELECT p.id_cliente,cu.id_moneda,SUM(p.monto) AS inversiones
 FROM dbo.TB_PLAZO_FIJO p JOIN dbo.TB_CUENTA cu ON cu.id_cuenta=p.id_cuenta_origen
 WHERE p.estado IN('Activo','Vencido') GROUP BY p.id_cliente,cu.id_moneda
), Obligaciones AS (
 SELECT t.id_cliente,cu.id_moneda,SUM(t.saldo_utilizado) AS obligaciones
 FROM dbo.TB_TARJETA t JOIN dbo.TB_TIPO_TARJETA tt ON tt.id_tipo_tarjeta=t.id_tipo_tarjeta
 JOIN dbo.TB_CUENTA cu ON cu.id_cuenta=t.id_cuenta
 WHERE tt.nombre='Credito' GROUP BY t.id_cliente,cu.id_moneda
)
SELECT c.id_cliente,c.nombre,mo.codigo AS moneda,
 COALESCE(cu.saldos,0) AS saldo_cuentas,COALESCE(i.inversiones,0) AS inversiones,
 COALESCE(o.obligaciones,0) AS deuda_tarjetas,
 COALESCE(cu.saldos,0)+COALESCE(i.inversiones,0)-COALESCE(o.obligaciones,0) AS posicion_neta
FROM dbo.TB_CLIENTE c CROSS JOIN dbo.TB_MONEDA mo
LEFT JOIN Cuentas cu ON cu.id_cliente=c.id_cliente AND cu.id_moneda=mo.id_moneda
LEFT JOIN Inversiones i ON i.id_cliente=c.id_cliente AND i.id_moneda=mo.id_moneda
LEFT JOIN Obligaciones o ON o.id_cliente=c.id_cliente AND o.id_moneda=mo.id_moneda
ORDER BY c.id_cliente,mo.codigo;
