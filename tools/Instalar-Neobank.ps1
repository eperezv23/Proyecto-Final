# Instala una base nueva o actualiza explícitamente una copia del proyecto.
# Nunca elimina bases; las opciones de permisos se dejan fuera del instalador.
param(
 [string]$Server='lpc:localhost',
 [string]$Database='NEOBANK_GT',
 [switch]$Actualizar,
 [switch]$SinDemo
)
$ErrorActionPreference='Stop'
if($Database -notmatch '^NEOBANK_GT(?:_[A-Z0-9]+)*$'){throw 'El nombre debe ser NEOBANK_GT o empezar por NEOBANK_GT_.'}
$root=Split-Path $PSScriptRoot -Parent
$builder=[System.Data.SqlClient.SqlConnectionStringBuilder]::new()
$builder['Data Source']=$Server;$builder['Initial Catalog']='master';$builder['Integrated Security']=$true
$builder['Encrypt']=$false;$builder['Connect Timeout']=10
$cx=[System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
try{
 $cx.Open();$cmd=$cx.CreateCommand()
 $cmd.CommandText='SELECT DB_ID(@nombre)';$null=$cmd.Parameters.AddWithValue('@nombre',$Database)
 $exists=$cmd.ExecuteScalar() -isnot [DBNull]
 if($Actualizar -and -not $exists){throw 'La base no existe. Instale primero sin -Actualizar.'}
 if(-not $Actualizar -and $exists){throw 'La base ya existe. No se sobrescribe. Use -Actualizar sólo con una copia del proyecto compatible.'}
 # El nombre fue limitado a letras, números y guiones bajos para proteger el DDL.
 if(-not $exists){$cmd.Parameters.Clear();$cmd.CommandText="CREATE DATABASE [$Database] COLLATE Modern_Spanish_CI_AS";$null=$cmd.ExecuteNonQuery()}
 $cmd.Dispose()
}finally{$cx.Dispose()}
$files=@()
if(-not $Actualizar){$files+='01_esquema_original.sql'}
$files+=@('02_integridad_auditoria.sql','03_funciones.sql','04_procedimientos.sql','05_catalogos.sql')
if(-not $SinDemo){$files+='06_datos_demo.sql'}
# Respetar dependencias: esquema, integridad, funciones, procedimientos y datos.
foreach($file in $files){
 Write-Host "Instalando $file en $Database"
 & (Join-Path $PSScriptRoot 'Invoke-SqlScript.ps1') -Server $Server -Database $Database -SqlFile (Join-Path $root "sql\$file") | Out-Null
}
Write-Host "Instalación completada: $Database. No se aplicaron cambios de roles ni permisos."
