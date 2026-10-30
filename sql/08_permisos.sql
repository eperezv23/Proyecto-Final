/* Rol sin miembros: no crea logins ni cambia la seguridad del servidor.
   Un administrador podrá asignarlo a usuarios SQL del equipo cuando corresponda.
   La cuenta propietaria usada para desarrollo conserva sus permisos anteriores.
*/
IF DATABASE_PRINCIPAL_ID('neobank_operador') IS NULL
 CREATE ROLE neobank_operador AUTHORIZATION dbo;
GO
DECLARE @nombre sysname,@sql nvarchar(max);
DECLARE rutinas CURSOR LOCAL FAST_FORWARD FOR
 SELECT name FROM sys.procedures WHERE schema_id=SCHEMA_ID('dbo') AND name LIKE 'SP[0-9][0-9][_]%' AND name NOT LIKE 'SP00[_]%';
OPEN rutinas; FETCH NEXT FROM rutinas INTO @nombre;
WHILE @@FETCH_STATUS=0
BEGIN
 SET @sql=N'GRANT EXECUTE ON OBJECT::dbo.'+QUOTENAME(@nombre)+N' TO neobank_operador;';
 EXEC sys.sp_executesql @sql;
 FETCH NEXT FROM rutinas INTO @nombre;
END;
CLOSE rutinas; DEALLOCATE rutinas;
-- Las funciones escalares requieren EXECUTE, aunque se invoquen desde SELECT.
GRANT EXECUTE ON dbo.F01_SALDO_DISPONIBLE TO neobank_operador;
GRANT EXECUTE ON dbo.F02_INTERES_PLAZO_FIJO TO neobank_operador;
GRANT EXECUTE ON dbo.F03_UTILIZACION_TARJETA TO neobank_operador;
GRANT EXECUTE ON dbo.F04_CONVERTIR_MONEDA TO neobank_operador;
DECLARE lectura CURSOR LOCAL FAST_FORWARD FOR
 SELECT name FROM sys.tables WHERE schema_id=SCHEMA_ID('dbo') AND name LIKE 'TB[_]%' AND name<>'TB_USUARIO';
OPEN lectura; FETCH NEXT FROM lectura INTO @nombre;
WHILE @@FETCH_STATUS=0
BEGIN
 SET @sql=N'GRANT SELECT ON OBJECT::dbo.'+QUOTENAME(@nombre)+N' TO neobank_operador;';
 EXEC sys.sp_executesql @sql;
 FETCH NEXT FROM lectura INTO @nombre;
END;
CLOSE lectura; DEALLOCATE lectura;
-- El rol no recibe INSERT/UPDATE/DELETE en tablas ni EXECUTE de auxiliares SP00.
GO
CREATE OR ALTER VIEW dbo.V_USUARIOS_AUDITORIA
AS SELECT id_usuario,nombre_usuario,nombre_completo,estado,fecha_registro FROM dbo.TB_USUARIO;
GO
GRANT SELECT ON dbo.V_USUARIOS_AUDITORIA TO neobank_operador;
