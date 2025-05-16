# Verify PsExec Tool path
$PsExecPath = "$($env:TEMP)\PSTools\PsExec.exe"
# Install PSTools if not found
if (!(Test-Path $PsExecPath)) {
    Write-Warning "PsExec.exe not found in $PsExecPath. Installing..."
    $url = "https://download.sysinternals.com/files/PSTools.zip"
    $dest = "$($env:TEMP)\PSTools.zip"
    Invoke-WebRequest -Uri $url -OutFile $dest
    Expand-Archive -Path $dest -DestinationPath "$($env:TEMP)\PSTools" -Force
    Remove-Item -Path $dest -Force
}
# CVS file path
$csvPath = "C:\Users\Nicu.Kirlacovschi\Downloads\salt-master\salt-master\files\datos.csv"
if (!(Test-Path $PsExecPath)) {
    Write-Host "CSV file not found in path: $csvPath ."
    exit 1
}
# Leer datos del CSV
$datos = Import-Csv -Path $csvPath

# Recorrer cada fila
foreach ($fila in $datos) {
    $usuario = $fila.UserName
    $shouldRun = $fila.ShouldRun
    $password = $fila.Password
    $domain = ".inputforyou.local"
    $programa = $fila.Path
    $argumentos = $fila.Arguments
    $environment = $fila.Environment
    $server = $fila.ServerName

    # Only execute if ShouldRun is 'true' o 'yes'
    if ($shouldRun -match "^(?i)true|yes$") {
        Write-Host "Connecting to $usuario@$server"

        # Store the credentials with cmdkey
        cmdkey /generic:"TERMSRV/$server$domain" /user:"$environment\$usuario" /pass:"$password"

        # Create a .rdp file for the connection
        $rdpPath = "$env:TEMP\$usuario.rdp"
        @"
full address:s:$server$domain
username:s:$environment\$usuario
authentication level:i:2
prompt for credentials:i:0
enablecredsspsupport:i:1
"@ | Out-File -Encoding ASCII $rdpPath

        # Start RDP Connection
        $rdpProcess = Start-Process "mstsc.exe" -ArgumentList $rdpPath -PassThru
        Start-Sleep -Seconds 5

        # Get the user session ID
        $sessions = qwinsta /server:$server
        $sessionId = $sessions | Select-String "$usuario\s+(\w+)" | Foreach-Object { $_.Matches[0].Groups[1].Value }

        # Build the path of the program with the arguments and then execute it
        $comando = "`"$programa`" $argumentos"

        Start-Process -FilePath $PsExecPath  -ArgumentList @(
                "\\$server",
                "-i", "$sessionId",
                "-u", "$usuario",
                "-p", "$password",
                "-w", "`"$workingDir`"",
                "$comando"
            ) -WindowStyle Hidden

        Start-Sleep -Seconds 5

        $rdpProcess |  Stop-Process -Force
    }
}
