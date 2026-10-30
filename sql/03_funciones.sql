/* Funciones obligatorias. Supuestos académicos explícitos:
   - Tasa de plazo fijo: porcentaje anual, interés simple, base 365 días.
   - Redondeo de importes monetarios a dos decimales.
   - Un tipo de cambio expresa unidades destino por una unidad origen.
   - La cotización vigente debe estar activa y no tener fecha futura.
*/
-- F01: identifica la cuenta por su clave y permite usar fondos sólo si está activa.
-- Un identificador inexistente devuelve NULL; bloqueada/cerrada devuelve cero.
CREATE OR ALTER FUNCTION dbo.F01_SALDO_DISPONIBLE(@id_cuenta int)
RETURNS decimal(18,6)
AS
BEGIN
 DECLARE @saldo decimal(18,6);
 SELECT @saldo=CASE WHEN estado='Activa' THEN saldo ELSE 0 END
 FROM dbo.TB_CUENTA WHERE id_cuenta=@id_cuenta;
 RETURN @saldo;
END;
GO
-- F02: calcula el interés al vencimiento a partir de las condiciones registradas.
-- La tasa es un porcentaje anual, no una fracción ni una tasa mensual.
CREATE OR ALTER FUNCTION dbo.F02_INTERES_PLAZO_FIJO(@id_plazo_fijo int)
RETURNS decimal(18,6)
AS
BEGIN
 DECLARE @interes decimal(18,6);
 SELECT @interes=ROUND(CONVERT(decimal(28,8),monto)*tasa_interes/100.0*plazo_dias/365.0,2)
 FROM dbo.TB_PLAZO_FIJO WHERE id_plazo_fijo=@id_plazo_fijo;
 RETURN @interes;
END;
GO
-- F03: expresa qué porcentaje del límite representa la deuda vigente.
-- NULLIF evita dividir entre cero; sólo se consideran tarjetas de crédito.
CREATE OR ALTER FUNCTION dbo.F03_UTILIZACION_TARJETA(@id_tarjeta int)
RETURNS decimal(18,6)
AS
BEGIN
 DECLARE @porcentaje decimal(18,6);
 SELECT @porcentaje=CONVERT(decimal(28,8),t.saldo_utilizado)*100.0/NULLIF(t.limite_credito,0)
 FROM dbo.TB_TARJETA t JOIN dbo.TB_TIPO_TARJETA tt ON tt.id_tipo_tarjeta=t.id_tipo_tarjeta
 WHERE t.id_tarjeta=@id_tarjeta AND tt.nombre='Credito';
 RETURN @porcentaje;
END;
GO
-- F04: selecciona la cotización registrada más reciente a la fecha indicada.
-- Mantiene los ocho decimales de la tasa; redondea sólo el resultado monetario.
CREATE OR ALTER FUNCTION dbo.F04_CONVERTIR_MONEDA(
 @monto decimal(18,6),@id_moneda_origen int,@id_moneda_destino int,@fecha datetime
)
RETURNS decimal(18,6)
AS
BEGIN
 IF @monto IS NULL OR @monto<0 OR @fecha IS NULL RETURN NULL;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_MONEDA WHERE id_moneda=@id_moneda_origen AND codigo IN('GTQ','USD')) RETURN NULL;
 IF NOT EXISTS(SELECT 1 FROM dbo.TB_MONEDA WHERE id_moneda=@id_moneda_destino AND codigo IN('GTQ','USD')) RETURN NULL;
 IF @id_moneda_origen=@id_moneda_destino RETURN ROUND(@monto,2);
 DECLARE @tasa decimal(18,8);
 SELECT TOP(1) @tasa=valor_cambio FROM dbo.TB_TIPO_CAMBIO
 WHERE id_moneda_origen=@id_moneda_origen AND id_moneda_destino=@id_moneda_destino
 AND estado='Activo' AND fecha_registro<=@fecha AND valor_cambio>0
 ORDER BY fecha_registro DESC,id_tipo_cambio DESC;
 RETURN CONVERT(decimal(18,6),ROUND(CONVERT(decimal(28,8),@monto)*@tasa,2));
END;
