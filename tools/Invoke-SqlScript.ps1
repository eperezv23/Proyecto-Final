# Ejecuta un archivo SQL por lotes GO y convierte sus resultados a JSON.
# La conexión utiliza Windows; no recibe ni guarda contraseñas.
param(
    [Parameter(Mandatory=$true)][string]$SqlFile,
    [string]$Database='master',
    [string]$Server='lpc:localhost',
    [string]$ResultFile,
    [int]$Timeout=120
)
$ErrorActionPreference='Stop'
$builder=[System.Data.SqlClient.SqlConnectionStringBuilder]::new()
$builder['Data Source']=$Server
$builder['Initial Catalog']=$Database
$builder['Integrated Security']=$true
$builder['Encrypt']=$false
$builder['Connect Timeout']=10
$builder['Application Name']='NEOBANK Desarrollo'
$connection=[System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
$results=[System.Collections.Generic.List[object]]::new()
try {
    $connection.Open()
    $connection.add_InfoMessage({param($sender,$e) Write-Output $e.Message})
    $source=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $SqlFile))
    # GO es un separador del cliente, no una instrucción del motor SQL Server.
    $batches=[regex]::Split($source,'(?im)^\s*GO\s*(?:--[^\r\n]*)?\r?$')
    $batchNumber=0
    foreach($batch in $batches) {
        $batchNumber++
        if([string]::IsNullOrWhiteSpace($batch)){continue}
        $command=$connection.CreateCommand()
        $command.CommandText=$batch
        $command.CommandTimeout=$Timeout
        try {
            $reader=$command.ExecuteReader()
            do {
                if($reader.FieldCount -eq 0){continue}
                $rows=[System.Collections.Generic.List[object]]::new()
                # Conservar nombres de columna y NULL para revisar los resultados.
                while($reader.Read()) {
                    $row=[ordered]@{}
                    for($i=0;$i -lt $reader.FieldCount;$i++){
                        $value=$reader.GetValue($i)
                        if($value -is [DBNull]){$value=$null}
                        $row[$reader.GetName($i)]=$value
                    }
                    $rows.Add([pscustomobject]$row)
                }
                $results.Add([pscustomobject]@{Batch=$batchNumber;Rows=$rows.ToArray()})
            }while($reader.NextResult())
            $reader.Dispose()
        }catch {throw "Error en lote ${batchNumber}: $($_.Exception.Message)"}
        finally {$command.Dispose()}
    }
    $json=ConvertTo-Json -InputObject $results.ToArray() -Depth 12
    if($ResultFile){[IO.File]::WriteAllText($ResultFile,$json,[Text.UTF8Encoding]::new($false))}
    $json
}finally{$connection.Dispose()}
