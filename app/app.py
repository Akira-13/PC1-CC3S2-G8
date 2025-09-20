#!/usr/bin/env python3

"""
app/app.py - Aplicación demo mínima y documentada para laboratorio
"""

from flask import Flask, request, make_response, render_template_string, jsonify
import os

app = Flask(__name__)

"""
VULN 1: secret_key hardcodeada
"""
app.secret_key = "key_123"

# Frontend de la aplicación

INDEX_HTML = """
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8"/>
  <title>App Vulnerable - Demo Lab</title>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <style>
    :root{--bg:#f6f8fa;--card:#ffffff;--muted:#6b7280;--accent:#0b5fff;--danger:#d9534f;}
    body{font-family:Inter,system-ui,Segoe UI,Roboto,"Helvetica Neue",Arial;margin:0;background:linear-gradient(180deg,#eef2ff,white);color:#0b1220}
    .wrap{max-width:900px;margin:36px auto;padding:20px;}
    .card{background:var(--card);border-radius:12px;box-shadow:0 6px 18px rgba(12,14,25,0.06);padding:22px;margin-bottom:18px;}
    h1{margin:0 0 8px;font-weight:700}
    p.lead{color:var(--muted);margin:0 0 16px}
    .row{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:12px}
    a.btn{display:inline-block;padding:8px 12px;border-radius:8px;text-decoration:none;background:var(--accent);color:white;font-weight:600}
    a.ghost{background:transparent;border:1px solid #e6edf8;color:var(--accent)}
    .muted{color:var(--muted);font-size:0.95rem}
    .vuln-list{margin-top:12px;padding:12px;border-radius:8px;background:#fff6f6;border:1px dashed rgba(217, 83, 79,0.15)}
    .vuln-item{display:flex;gap:12px;align-items:flex-start;padding:8px 0}
    .badge{min-width:36px;height:36px;border-radius:8px;background:var(--danger);color:white;display:inline-flex;align-items:center;justify-content:center;font-weight:700}
    code {background:#0f1724;color:#e6f3ff;padding:2px 6px;border-radius:6px;font-size:0.95rem}
    footer{font-size:0.85rem;color:var(--muted);margin-top:8px}
    pre.trace{background:#111827;color:#e6f3ff;padding:12px;border-radius:8px;overflow:auto;max-height:240px}
    @media(min-width:720px){ .row {flex-wrap:nowrap} }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>Demo app vulnerable</h1>
      <p class="lead">Servicio mínimo para pruebas de <strong>cabeceras</strong>, <strong>cookies</strong>, <strong>stacktraces</strong>.</p>
      <div class="row">
        <a class="btn" href="/">Inicio</a>
        <a class="btn" href="/headers">Ver headers</a>
        <a class="btn" href="/boom">Forzar error</a>
        <a class="btn" href="/health">Health</a>
      </div>

      <div class="card" style="background:linear-gradient(90deg,#fff8f8,#fff);margin-top:14px">
        <h3 style="margin-top:0">Vulnerabilidades incluidas</h3>
        <div class="vuln-list">
          <div class="vuln-item"><div class="badge">1</div><div><strong>Secret key hardcodeada</strong><div class="muted">Clave fija en el código app.secret_key.</div></div></div>
          <div class="vuln-item"><div class="badge">2</div><div><strong>Debug activado</strong><div class="muted">Con debug=True la ruta /boom muestra stacktrace.</div></div></div>
          <div class="vuln-item"><div class="badge">3</div><div><strong>Cabeceras informativas</strong><div class="muted">Presenta X-Powered-By y Cache-Control.</div></div></div>
          <div class="vuln-item"><div class="badge">4</div><div><strong>Cookies sin flags</strong><div class="muted">Cookie de sesión sin Secure ni HttpOnly.</div></div></div>
          
        </div>
      </div>

    </div>
  </div>
</body>
</html>
"""



@app.route("/")
def index():
    name = request.args.get("name", "invitado")
    resp = make_response(render_template_string(INDEX_HTML, name=name))

    """
    VULN 2: cabeceras inseguras
    """
    resp.headers["X-Powered-By"] = "vuln-flask-demo"
    resp.headers["Cache-Control"] = "no-store"
    
    """
    VULN 3: cookie sin HttpOnly ni Secure
    """
    resp.set_cookie("session", "demo-session-id", httponly=False, secure=False)
    return resp

@app.route("/headers")
def headers_view():
    # Retornar las cabeceras de la petición en JSON
    return jsonify(dict(request.headers))

@app.route("/health")
def health():
    return "OK", 200

@app.route("/boom")
def boom():
    # Forzar error para exponer el traceback en modo debug
    raise RuntimeError("Forzando error para demo de stacktrace")


if __name__ == "__main__":
    cert_file = os.environ.get("CERT_FILE", "app/certs/cert.pem")
    key_file = os.environ.get("KEY_FILE", "app/certs/key.pem")

    use_ssl = os.path.exists(cert_file) and os.path.exists(key_file)
    if use_ssl:
        print(f"[INFO] TLS habilitado: cert={cert_file} key={key_file}. HTTPS en 8443")
        app.run(host="0.0.0.0", port=8443, ssl_context=(cert_file, key_file), debug=True)
    else:
        print("[INFO] No se encontraron cert/key. HTTP en 8080")
        app.run(host="0.0.0.0", port=8080, debug=True)



