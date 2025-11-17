import socket
import threading
import sys

print("🔄 Starting Simple Test Server...")

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('0.0.0.0', 4444))
server.listen(5)

print("✅ Server listening on 0.0.0.0:4444")
print("🌐 Domain: herculles.ddns.net")

def handle_client(client_socket, address):
    try:
        print(f"🎯 New connection from {address}")
        client_socket.send(b"SWILL Test Server - Connected!\n")
        
        while True:
            data = client_socket.recv(1024)
            if not data:
                break
            print(f"📨 Received: {data.decode().strip()}")
            client_socket.send(b"Message received\n")
            
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        client_socket.close()
        print(f"🔌 Disconnected: {address}")

while True:
    client, addr = server.accept()
    threading.Thread(target=handle_client, args=(client, addr)).start()
