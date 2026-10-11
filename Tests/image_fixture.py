"""Loopback image fixture; no game connection or external download."""
from http.server import BaseHTTPRequestHandler, HTTPServer
import base64
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aT1kAAAAASUVORK5CYII=')
class Fixture(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'image/png')
        self.send_header('Content-Length', str(len(PNG)))
        self.end_headers()
        self.wfile.write(PNG)
    def log_message(self, *args): pass
HTTPServer(('127.0.0.1', 8935), Fixture).serve_forever()
