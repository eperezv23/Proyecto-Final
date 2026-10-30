/* Esquema del respaldo original NEOBANK_GT, recuperado el 30/10/2026.
   Sin datos personales ni credenciales. Conserva las 19 tablas originales. */
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
-- Entidad TB_BANCO: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_BANCO](
 [id_banco] int IDENTITY(1,1) NOT NULL,
 [nombre] varchar(100) NOT NULL,
 CONSTRAINT [PK_BASE_TB_BANCO] PRIMARY KEY ([id_banco])
);
-- Entidad TB_CLIENTE: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_CLIENTE](
 [id_cliente] int IDENTITY(1,1) NOT NULL,
 [id_tipo_cliente] int NOT NULL,
 [nombre] varchar(150) NOT NULL,
 [cui] varchar(20) NULL,
 [nit] varchar(20) NULL,
 [telefono] varchar(25) NULL,
 [correo] varchar(150) NULL,
 [direccion] varchar(250) NULL,
 [estado] varchar(20) NOT NULL,
 [fecha_registro] date NOT NULL,
 CONSTRAINT [PK_BASE_TB_CLIENTE] PRIMARY KEY ([id_cliente])
);
-- Entidad TB_CONSUMO_TARJETA: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_CONSUMO_TARJETA](
 [id_consumo] int IDENTITY(1,1) NOT NULL,
 [id_tarjeta] int NOT NULL,
 [referencia] varchar(50) NOT NULL,
 [fecha_consumo] datetime NOT NULL CONSTRAINT [DF_BASE_TB_CONSUMO_TARJETA_fecha_consumo] DEFAULT (getdate()),
 [comercio] varchar(150) NOT NULL,
 [monto] decimal(18,6) NOT NULL,
 [estado] varchar(20) NOT NULL,
 [id_usuario] int NOT NULL,
 CONSTRAINT [PK_BASE_TB_CONSUMO_TARJETA] PRIMARY KEY ([id_consumo])
);
-- Entidad TB_CONVERSION_MONEDA: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_CONVERSION_MONEDA](
 [id_conversion] int IDENTITY(1,1) NOT NULL,
 [id_cuenta_origen] int NOT NULL,
 [id_cuenta_destino] int NOT NULL,
 [id_tipo_cambio] int NOT NULL,
 [referencia] varchar(150) NOT NULL,
 [monto_origen] decimal(18,6) NOT NULL,
 [monto_destino] decimal(18,6) NOT NULL,
 [tipo_cambio_aplicado] decimal(18,8) NOT NULL,
 [fecha_conversion] datetime NOT NULL CONSTRAINT [DF_BASE_TB_CONVERSION_MONEDA_fecha_conversion] DEFAULT (getdate()),
 [estado] varchar(20) NOT NULL,
 [id_usuario] int NOT NULL,
 CONSTRAINT [PK_BASE_TB_CONVERSION_MONEDA] PRIMARY KEY ([id_conversion])
);
-- Entidad TB_CUENTA: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_CUENTA](
 [id_cuenta] int IDENTITY(1,1) NOT NULL,
 [numero_cuenta] varchar(30) NOT NULL,
 [id_tipo_cuenta] int NOT NULL,
 [id_moneda] int NOT NULL,
 [saldo] decimal(18,6) NOT NULL CONSTRAINT [DF_BASE_TB_CUENTA_saldo] DEFAULT ((0)),
 [estado] varchar(20) NOT NULL CONSTRAINT [DF_BASE_TB_CUENTA_estado] DEFAULT ('Activa'),
 [fecha_apertura] date NOT NULL CONSTRAINT [DF_BASE_TB_CUENTA_fecha_apertura] DEFAULT (getdate()),
 CONSTRAINT [PK_BASE_TB_CUENTA] PRIMARY KEY ([id_cuenta])
);
-- Entidad TB_MONEDA: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_MONEDA](
 [id_moneda] int IDENTITY(1,1) NOT NULL,
 [codigo] varchar(10) NOT NULL,
 [nombre] varchar(80) NOT NULL,
 CONSTRAINT [PK_BASE_TB_MONEDA] PRIMARY KEY ([id_moneda])
);
-- Entidad TB_MOVIMIENTO: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_MOVIMIENTO](
 [id_movimiento] int IDENTITY(1,1) NOT NULL,
 [id_cuenta] int NOT NULL,
 [id_tipo_movimiento] int NOT NULL,
 [referencia] varchar(100) NOT NULL,
 [fecha_movimiento] datetime NOT NULL CONSTRAINT [DF_BASE_TB_MOVIMIENTO_fecha_movimiento] DEFAULT (getdate()),
 [monto] decimal(18,6) NOT NULL,
 [estado] varchar(20) NOT NULL,
 [descripcion] varchar(250) NULL,
 [id_usuario] int NOT NULL,
 [id_movimiento_original] int NULL,
 CONSTRAINT [PK_BASE_TB_MOVIMIENTO] PRIMARY KEY ([id_movimiento])
);
-- Entidad TB_PAGO_TARJETA: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_PAGO_TARJETA](
 [id_pago] int IDENTITY(1,1) NOT NULL,
 [id_tarjeta] int NOT NULL,
 [id_cuenta_origen] int NOT NULL,
 [referencia] varchar(50) NOT NULL,
 [fecha_pago] datetime NOT NULL CONSTRAINT [DF_BASE_TB_PAGO_TARJETA_fecha_pago] DEFAULT (getdate()),
 [monto] decimal(18,6) NOT NULL,
 [estado] varchar(20) NOT NULL,
 [id_usuario] int NOT NULL,
 CONSTRAINT [PK_BASE_TB_PAGO_TARJETA] PRIMARY KEY ([id_pago])
);
-- Entidad TB_PLAZO_FIJO: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_PLAZO_FIJO](
 [id_plazo_fijo] int IDENTITY(1,1) NOT NULL,
 [id_cliente] int NOT NULL,
 [id_cuenta_origen] int NOT NULL,
 [monto] decimal(18,6) NOT NULL,
 [tasa_interes] decimal(18,6) NOT NULL,
 [plazo_dias] int NOT NULL,
 [fecha_inicio] date NOT NULL,
 [fecha_vencimiento] date NOT NULL,
 [estado] varchar(20) NOT NULL,
 [fecha_liquidacion] date NULL,
 [id_usuario] int NOT NULL,
 CONSTRAINT [PK_BASE_TB_PLAZO_FIJO] PRIMARY KEY ([id_plazo_fijo])
);
-- Entidad TB_TARJETA: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_TARJETA](
 [id_tarjeta] int IDENTITY(1,1) NOT NULL,
 [id_cliente] int NOT NULL,
 [id_tipo_tarjeta] int NOT NULL,
 [id_cuenta] int NULL,
 [numero_tarjeta] varchar(20) NOT NULL,
 [fecha_emision] date NOT NULL,
 [fecha_vencimiento] date NOT NULL,
 [limite_credito] decimal(18,6) NULL,
 [saldo_utilizado] decimal(18,6) NULL,
 [estado] varchar(20) NOT NULL,
 CONSTRAINT [PK_BASE_TB_TARJETA] PRIMARY KEY ([id_tarjeta])
);
-- Entidad TB_TIPO_CAMBIO: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_TIPO_CAMBIO](
 [id_tipo_cambio] int IDENTITY(1,1) NOT NULL,
 [id_moneda_origen] int NOT NULL,
 [id_moneda_destino] int NOT NULL,
 [valor_cambio] decimal(18,8) NOT NULL,
 [fecha_registro] datetime NOT NULL CONSTRAINT [DF_BASE_TB_TIPO_CAMBIO_fecha_registro] DEFAULT (getdate()),
 [estado] varchar(20) NOT NULL,
 CONSTRAINT [PK_BASE_TB_TIPO_CAMBIO] PRIMARY KEY ([id_tipo_cambio])
);
-- Entidad TB_TIPO_CLIENTE: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_TIPO_CLIENTE](
 [id_tipo_cliente] int IDENTITY(1,1) NOT NULL,
 [nombre] varchar(100) NOT NULL,
 CONSTRAINT [PK_BASE_TB_TIPO_CLIENTE] PRIMARY KEY ([id_tipo_cliente])
);
-- Entidad TB_TIPO_CUENTA: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_TIPO_CUENTA](
 [id_tipo_cuenta] int IDENTITY(1,1) NOT NULL,
 [nombre] varchar(100) NOT NULL,
 CONSTRAINT [PK_BASE_TB_TIPO_CUENTA] PRIMARY KEY ([id_tipo_cuenta])
);
-- Entidad TB_TIPO_MOVIMIENTO: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_TIPO_MOVIMIENTO](
 [id_tipo_movimiento] int IDENTITY(1,1) NOT NULL,
 [nombre] varchar(100) NOT NULL,
 CONSTRAINT [PK_BASE_TB_TIPO_MOVIMIENTO] PRIMARY KEY ([id_tipo_movimiento])
);
-- Entidad TB_TIPO_TARJETA: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_TIPO_TARJETA](
 [id_tipo_tarjeta] int IDENTITY(1,1) NOT NULL,
 [nombre] varchar(100) NOT NULL,
 CONSTRAINT [PK_BASE_TB_TIPO_TARJETA] PRIMARY KEY ([id_tipo_tarjeta])
);
-- Entidad TB_TITULAR_CUENTA: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_TITULAR_CUENTA](
 [id_cliente] int NOT NULL,
 [id_cuenta] int NOT NULL,
 CONSTRAINT [PK_BASE_TB_TITULAR_CUENTA] PRIMARY KEY ([id_cliente],[id_cuenta])
);
-- Entidad TB_TRANSFERENCIA: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_TRANSFERENCIA](
 [id_transferencia] int IDENTITY(1,1) NOT NULL,
 [id_cuenta_origen] int NOT NULL,
 [id_cuenta_destino] int NULL,
 [tipo_transferencia] varchar(40) NOT NULL,
 [referencia] varchar(100) NOT NULL,
 [monto] decimal(18,6) NOT NULL,
 [fecha_transferencia] datetime NOT NULL CONSTRAINT [DF_BASE_TB_TRANSFERENCIA_fecha_transferencia] DEFAULT (getdate()),
 [estado] varchar(20) NOT NULL,
 [id_usuario] int NOT NULL,
 [id_banco_destino] int NULL,
 [cuenta_externa_destino] varchar(30) NULL,
 CONSTRAINT [PK_BASE_TB_TRANSFERENCIA] PRIMARY KEY ([id_transferencia])
);
-- Entidad TB_TRANSFERENCIA_MOVIMIENTO: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_TRANSFERENCIA_MOVIMIENTO](
 [id_transferencia] int NOT NULL,
 [id_movimiento] int NOT NULL,
 CONSTRAINT [PK_BASE_TB_TRANSFERENCIA_MOVIMIENTO] PRIMARY KEY ([id_transferencia],[id_movimiento])
);
-- Entidad TB_USUARIO: atributos propios y clave primaria; las relaciones se definen al final.
CREATE TABLE dbo.[TB_USUARIO](
 [id_usuario] int IDENTITY(1,1) NOT NULL,
 [nombre_usuario] varchar(100) NOT NULL,
 [nombre_completo] varchar(150) NOT NULL,
 [clave_hash] varchar(255) NOT NULL,
 [estado] varchar(50) NOT NULL,
 [fecha_registro] date NOT NULL CONSTRAINT [DF_BASE_TB_USUARIO_fecha_registro] DEFAULT (getdate()),
 CONSTRAINT [PK_BASE_TB_USUARIO] PRIMARY KEY ([id_usuario])
);
CREATE UNIQUE INDEX [UQ_TM_MOVIMIENTO] ON dbo.[TB_TRANSFERENCIA_MOVIMIENTO] ([id_movimiento]);
CREATE UNIQUE INDEX [UQ__TB_TARJE__90FF5A61E335BF18] ON dbo.[TB_TARJETA] ([numero_tarjeta]);
CREATE UNIQUE INDEX [UQ__TB_CONSU__85C4EB33F44E349F] ON dbo.[TB_CONSUMO_TARJETA] ([referencia]);
CREATE UNIQUE INDEX [UQ__TB_PAGO___85C4EB33DFBB8597] ON dbo.[TB_PAGO_TARJETA] ([referencia]);
CREATE UNIQUE INDEX [UQ__TB_CONVE__85C4EB33662406BD] ON dbo.[TB_CONVERSION_MONEDA] ([referencia]);
CREATE UNIQUE INDEX [UQ__TB_TIPO___72AFBCC603EC5FD5] ON dbo.[TB_TIPO_CLIENTE] ([nombre]);
CREATE UNIQUE INDEX [UQ__TB_TIPO___72AFBCC66952BF8E] ON dbo.[TB_TIPO_CUENTA] ([nombre]);
CREATE UNIQUE INDEX [UQ__TB_MONED__40F9A20675CF0091] ON dbo.[TB_MONEDA] ([codigo]);
CREATE UNIQUE INDEX [UQ__TB_TIPO___72AFBCC60CE4A2A2] ON dbo.[TB_TIPO_MOVIMIENTO] ([nombre]);
CREATE UNIQUE INDEX [UQ__TB_TIPO___72AFBCC6FC4ABC1B] ON dbo.[TB_TIPO_TARJETA] ([nombre]);
CREATE UNIQUE INDEX [UQ__TB_CUENT__C6B74B88D0FB631F] ON dbo.[TB_CUENTA] ([numero_cuenta]);
CREATE UNIQUE INDEX [UQ__TB_USUAR__D4D22D74288E1EAD] ON dbo.[TB_USUARIO] ([nombre_usuario]);
CREATE UNIQUE INDEX [UQ__TB_MOVIM__85C4EB339CE929ED] ON dbo.[TB_MOVIMIENTO] ([referencia]);
CREATE UNIQUE INDEX [UQ__TB_BANCO__72AFBCC687A5F1C5] ON dbo.[TB_BANCO] ([nombre]);
CREATE UNIQUE INDEX [UQ__TB_TRANS__85C4EB33D34EEA40] ON dbo.[TB_TRANSFERENCIA] ([referencia]);
ALTER TABLE dbo.[TB_TRANSFERENCIA] WITH CHECK ADD CONSTRAINT [CK_TRANSFERENCIA_MONTO] CHECK ([monto]>(0));
ALTER TABLE dbo.[TB_TRANSFERENCIA] WITH CHECK ADD CONSTRAINT [CK_TRANSFERENCIA_ESTADO] CHECK ([estado]='Rechazada' OR [estado]='Confirmada' OR [estado]='Pendiente');
ALTER TABLE dbo.[TB_TRANSFERENCIA] WITH CHECK ADD CONSTRAINT [CK_TRANSFERENCIA_TIPO] CHECK ([tipo_transferencia]='Interbancaria' OR [tipo_transferencia]='Interna');
ALTER TABLE dbo.[TB_TRANSFERENCIA] WITH CHECK ADD CONSTRAINT [CK_TRANSFERENCIA_DESTINO] CHECK ([tipo_transferencia]='Interna' AND [id_cuenta_destino] IS NOT NULL AND [id_banco_destino] IS NULL AND [cuenta_externa_destino] IS NULL OR [tipo_transferencia]='Interbancaria' AND [id_cuenta_destino] IS NULL AND [id_banco_destino] IS NOT NULL AND [cuenta_externa_destino] IS NOT NULL);
ALTER TABLE dbo.[TB_TARJETA] WITH CHECK ADD CONSTRAINT [CK_TARJETA_FECHAS] CHECK ([fecha_vencimiento]>[fecha_emision]);
ALTER TABLE dbo.[TB_TARJETA] WITH CHECK ADD CONSTRAINT [CK_TARJETA_ESTADO] CHECK ([estado]='Cancelada' OR [estado]='Bloqueada' OR [estado]='Activa');
ALTER TABLE dbo.[TB_TARJETA] WITH CHECK ADD CONSTRAINT [CK_TARJETA_LIMITE] CHECK ([limite_credito] IS NULL AND [saldo_utilizado] IS NULL OR [limite_credito]>(0) AND [saldo_utilizado]>=(0) AND [saldo_utilizado]<=[limite_credito]);
ALTER TABLE dbo.[TB_CONSUMO_TARJETA] WITH CHECK ADD CONSTRAINT [CK_CONSUMO_MONTO] CHECK ([monto]>(0));
ALTER TABLE dbo.[TB_CONSUMO_TARJETA] WITH CHECK ADD CONSTRAINT [CK_CONSUMO_ESTADO] CHECK ([estado]='Rechazado' OR [estado]='Confirmado' OR [estado]='Pendiente');
ALTER TABLE dbo.[TB_PAGO_TARJETA] WITH CHECK ADD CONSTRAINT [CK_PAGO_MONTO] CHECK ([monto]>(0));
ALTER TABLE dbo.[TB_PAGO_TARJETA] WITH CHECK ADD CONSTRAINT [CK_PAGO_ESTADO] CHECK ([estado]='Rechazado' OR [estado]='Confirmado' OR [estado]='Pendiente');
ALTER TABLE dbo.[TB_PLAZO_FIJO] WITH CHECK ADD CONSTRAINT [CK_PLAZO_MONTO] CHECK ([monto]>(0));
ALTER TABLE dbo.[TB_PLAZO_FIJO] WITH CHECK ADD CONSTRAINT [CK_PLAZO_TASA] CHECK ([tasa_interes]>=(0));
ALTER TABLE dbo.[TB_PLAZO_FIJO] WITH CHECK ADD CONSTRAINT [CK_PLAZO_DIAS] CHECK ([plazo_dias]>(0));
ALTER TABLE dbo.[TB_PLAZO_FIJO] WITH CHECK ADD CONSTRAINT [CK_PLAZO_FECHAS] CHECK ([fecha_vencimiento]>[fecha_inicio]);
ALTER TABLE dbo.[TB_PLAZO_FIJO] WITH CHECK ADD CONSTRAINT [CK_PLAZO_ESTADO] CHECK ([estado]='Liquidado' OR [estado]='Vencido' OR [estado]='Activo');
ALTER TABLE dbo.[TB_TIPO_CAMBIO] WITH CHECK ADD CONSTRAINT [CK_TIPO_CAMBIO_VALOR] CHECK ([valor_cambio]>(0));
ALTER TABLE dbo.[TB_TIPO_CAMBIO] WITH CHECK ADD CONSTRAINT [CK_TIPO_CAMBIO_MONEDAS] CHECK ([id_moneda_origen]<>[id_moneda_destino]);
ALTER TABLE dbo.[TB_TIPO_CAMBIO] WITH CHECK ADD CONSTRAINT [CK_TIPO_CAMBIO_ESTADO] CHECK ([estado]='Inactivo' OR [estado]='Activo');
ALTER TABLE dbo.[TB_CONVERSION_MONEDA] WITH CHECK ADD CONSTRAINT [CK_CONVERSION_MONTOS] CHECK ([monto_origen]>(0) AND [monto_destino]>(0));
ALTER TABLE dbo.[TB_CONVERSION_MONEDA] WITH CHECK ADD CONSTRAINT [CK_CONVERSION_CAMBIO] CHECK ([tipo_cambio_aplicado]>(0));
ALTER TABLE dbo.[TB_CONVERSION_MONEDA] WITH CHECK ADD CONSTRAINT [CK_CONVERSION_ESTADO] CHECK ([estado]='Rechazada' OR [estado]='Confirmada' OR [estado]='Pendiente');
ALTER TABLE dbo.[TB_CONVERSION_MONEDA] WITH CHECK ADD CONSTRAINT [CK_CONVERSION_CUENTAS] CHECK ([id_cuenta_origen]<>[id_cuenta_destino]);
ALTER TABLE dbo.[TB_CUENTA] WITH CHECK ADD CONSTRAINT [CK_CUENTA_SALDO] CHECK ([saldo]>=(0));
ALTER TABLE dbo.[TB_CUENTA] WITH CHECK ADD CONSTRAINT [CK_CUENTA_ESTADO] CHECK ([estado]='Cerrada' OR [estado]='Bloqueada' OR [estado]='Activa');
ALTER TABLE dbo.[TB_USUARIO] WITH CHECK ADD CONSTRAINT [CK_USUARIO_ESTADO] CHECK ([estado]='Bloqueado' OR [estado]='Inactivo' OR [estado]='Activo');
ALTER TABLE dbo.[TB_MOVIMIENTO] WITH CHECK ADD CONSTRAINT [CK_MOVIMIENTO_MONTO] CHECK ([monto]>(0));
ALTER TABLE dbo.[TB_MOVIMIENTO] WITH CHECK ADD CONSTRAINT [CK_MOVIMIENTO_ESTADO] CHECK ([estado]='Rechazado' OR [estado]='Confirmado' OR [estado]='Pendiente');
ALTER TABLE dbo.[TB_CONSUMO_TARJETA] WITH CHECK ADD CONSTRAINT [FK_CONSUMO_TARJETA] FOREIGN KEY ([id_tarjeta]) REFERENCES dbo.[TB_TARJETA]([id_tarjeta]);
ALTER TABLE dbo.[TB_PAGO_TARJETA] WITH CHECK ADD CONSTRAINT [FK_PAGO_TARJETA] FOREIGN KEY ([id_tarjeta]) REFERENCES dbo.[TB_TARJETA]([id_tarjeta]);
ALTER TABLE dbo.[TB_CONVERSION_MONEDA] WITH CHECK ADD CONSTRAINT [FK_CONVERSION_TIPO_CAMBIO] FOREIGN KEY ([id_tipo_cambio]) REFERENCES dbo.[TB_TIPO_CAMBIO]([id_tipo_cambio]);
ALTER TABLE dbo.[TB_CLIENTE] WITH CHECK ADD CONSTRAINT [FK_CLIENTE_TIPO] FOREIGN KEY ([id_tipo_cliente]) REFERENCES dbo.[TB_TIPO_CLIENTE]([id_tipo_cliente]);
ALTER TABLE dbo.[TB_TARJETA] WITH CHECK ADD CONSTRAINT [FK_TARJETA_CLIENTE] FOREIGN KEY ([id_cliente]) REFERENCES dbo.[TB_CLIENTE]([id_cliente]);
ALTER TABLE dbo.[TB_PLAZO_FIJO] WITH CHECK ADD CONSTRAINT [FK_PLAZO_CLIENTE] FOREIGN KEY ([id_cliente]) REFERENCES dbo.[TB_CLIENTE]([id_cliente]);
ALTER TABLE dbo.[TB_TITULAR_CUENTA] WITH CHECK ADD CONSTRAINT [FK_TITULAR_CLIENTE] FOREIGN KEY ([id_cliente]) REFERENCES dbo.[TB_CLIENTE]([id_cliente]);
ALTER TABLE dbo.[TB_CUENTA] WITH CHECK ADD CONSTRAINT [FK_CUENTA_TIPO] FOREIGN KEY ([id_tipo_cuenta]) REFERENCES dbo.[TB_TIPO_CUENTA]([id_tipo_cuenta]);
ALTER TABLE dbo.[TB_TIPO_CAMBIO] WITH CHECK ADD CONSTRAINT [FK_TIPO_CAMBIO_ORIGEN] FOREIGN KEY ([id_moneda_origen]) REFERENCES dbo.[TB_MONEDA]([id_moneda]);
ALTER TABLE dbo.[TB_TIPO_CAMBIO] WITH CHECK ADD CONSTRAINT [FK_TIPO_CAMBIO_DESTINO] FOREIGN KEY ([id_moneda_destino]) REFERENCES dbo.[TB_MONEDA]([id_moneda]);
ALTER TABLE dbo.[TB_CUENTA] WITH CHECK ADD CONSTRAINT [FK_CUENTA_MONEDA] FOREIGN KEY ([id_moneda]) REFERENCES dbo.[TB_MONEDA]([id_moneda]);
ALTER TABLE dbo.[TB_MOVIMIENTO] WITH CHECK ADD CONSTRAINT [FK_MOVIMIENTO_TIPO] FOREIGN KEY ([id_tipo_movimiento]) REFERENCES dbo.[TB_TIPO_MOVIMIENTO]([id_tipo_movimiento]);
ALTER TABLE dbo.[TB_TARJETA] WITH CHECK ADD CONSTRAINT [FK_TARJETA_TIPO] FOREIGN KEY ([id_tipo_tarjeta]) REFERENCES dbo.[TB_TIPO_TARJETA]([id_tipo_tarjeta]);
ALTER TABLE dbo.[TB_TRANSFERENCIA] WITH CHECK ADD CONSTRAINT [FK_TRANSFERENCIA_DESTINO] FOREIGN KEY ([id_cuenta_destino]) REFERENCES dbo.[TB_CUENTA]([id_cuenta]);
ALTER TABLE dbo.[TB_TARJETA] WITH CHECK ADD CONSTRAINT [FK_TARJETA_CUENTA] FOREIGN KEY ([id_cuenta]) REFERENCES dbo.[TB_CUENTA]([id_cuenta]);
ALTER TABLE dbo.[TB_PAGO_TARJETA] WITH CHECK ADD CONSTRAINT [FK_PAGO_CUENTA] FOREIGN KEY ([id_cuenta_origen]) REFERENCES dbo.[TB_CUENTA]([id_cuenta]);
ALTER TABLE dbo.[TB_PLAZO_FIJO] WITH CHECK ADD CONSTRAINT [FK_PLAZO_CUENTA] FOREIGN KEY ([id_cuenta_origen]) REFERENCES dbo.[TB_CUENTA]([id_cuenta]);
ALTER TABLE dbo.[TB_CONVERSION_MONEDA] WITH CHECK ADD CONSTRAINT [FK_CONVERSION_ORIGEN] FOREIGN KEY ([id_cuenta_origen]) REFERENCES dbo.[TB_CUENTA]([id_cuenta]);
ALTER TABLE dbo.[TB_CONVERSION_MONEDA] WITH CHECK ADD CONSTRAINT [FK_CONVERSION_DESTINO] FOREIGN KEY ([id_cuenta_destino]) REFERENCES dbo.[TB_CUENTA]([id_cuenta]);
ALTER TABLE dbo.[TB_TITULAR_CUENTA] WITH CHECK ADD CONSTRAINT [FK_TITULAR_CUENTA] FOREIGN KEY ([id_cuenta]) REFERENCES dbo.[TB_CUENTA]([id_cuenta]);
ALTER TABLE dbo.[TB_MOVIMIENTO] WITH CHECK ADD CONSTRAINT [FK_MOVIMIENTO_CUENTA] FOREIGN KEY ([id_cuenta]) REFERENCES dbo.[TB_CUENTA]([id_cuenta]);
ALTER TABLE dbo.[TB_TRANSFERENCIA] WITH CHECK ADD CONSTRAINT [FK_TRANSFERENCIA_ORIGEN] FOREIGN KEY ([id_cuenta_origen]) REFERENCES dbo.[TB_CUENTA]([id_cuenta]);
ALTER TABLE dbo.[TB_TRANSFERENCIA] WITH CHECK ADD CONSTRAINT [FK_TRANSFERENCIA_USUARIO] FOREIGN KEY ([id_usuario]) REFERENCES dbo.[TB_USUARIO]([id_usuario]);
ALTER TABLE dbo.[TB_CONSUMO_TARJETA] WITH CHECK ADD CONSTRAINT [FK_CONSUMO_USUARIO] FOREIGN KEY ([id_usuario]) REFERENCES dbo.[TB_USUARIO]([id_usuario]);
ALTER TABLE dbo.[TB_PAGO_TARJETA] WITH CHECK ADD CONSTRAINT [FK_PAGO_USUARIO] FOREIGN KEY ([id_usuario]) REFERENCES dbo.[TB_USUARIO]([id_usuario]);
ALTER TABLE dbo.[TB_PLAZO_FIJO] WITH CHECK ADD CONSTRAINT [FK_PLAZO_USUARIO] FOREIGN KEY ([id_usuario]) REFERENCES dbo.[TB_USUARIO]([id_usuario]);
ALTER TABLE dbo.[TB_CONVERSION_MONEDA] WITH CHECK ADD CONSTRAINT [FK_CONVERSION_USUARIO] FOREIGN KEY ([id_usuario]) REFERENCES dbo.[TB_USUARIO]([id_usuario]);
ALTER TABLE dbo.[TB_MOVIMIENTO] WITH CHECK ADD CONSTRAINT [FK_MOVIMIENTO_USUARIO] FOREIGN KEY ([id_usuario]) REFERENCES dbo.[TB_USUARIO]([id_usuario]);
ALTER TABLE dbo.[TB_TRANSFERENCIA_MOVIMIENTO] WITH CHECK ADD CONSTRAINT [FK_TM_MOVIMIENTO] FOREIGN KEY ([id_movimiento]) REFERENCES dbo.[TB_MOVIMIENTO]([id_movimiento]);
ALTER TABLE dbo.[TB_MOVIMIENTO] WITH CHECK ADD CONSTRAINT [FK_MOVIMIENTO_ORIGINAL] FOREIGN KEY ([id_movimiento_original]) REFERENCES dbo.[TB_MOVIMIENTO]([id_movimiento]);
ALTER TABLE dbo.[TB_TRANSFERENCIA] WITH CHECK ADD CONSTRAINT [FK_TRANSFERENCIA_BANCO] FOREIGN KEY ([id_banco_destino]) REFERENCES dbo.[TB_BANCO]([id_banco]);
ALTER TABLE dbo.[TB_TRANSFERENCIA_MOVIMIENTO] WITH CHECK ADD CONSTRAINT [FK_TM_TRANSFERENCIA] FOREIGN KEY ([id_transferencia]) REFERENCES dbo.[TB_TRANSFERENCIA]([id_transferencia]);
COMMIT;
END TRY
BEGIN CATCH
IF XACT_STATE()<>0 ROLLBACK;
THROW;
END CATCH;
