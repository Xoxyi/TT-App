# Serves build/web locally with the right MIME types for the wasm build
# (Python on Windows sends .mjs as text/plain otherwise):
#   python -I app/tool/serve_web.py 8080 app/build/web
import functools, http.server, sys
H = http.server.SimpleHTTPRequestHandler
H.extensions_map.update({'.mjs': 'text/javascript', '.js': 'text/javascript', '.wasm': 'application/wasm'})
http.server.test(HandlerClass=functools.partial(H, directory=sys.argv[2]), port=int(sys.argv[1]), bind='127.0.0.1')
