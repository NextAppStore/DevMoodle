import json
import urllib.parse

import jwt
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, RedirectResponse

app = FastAPI(title="LTI 1.3 Mock Tool for NextAppStore")


@app.api_route("/api/lti/login", methods=["GET", "POST"])
async def lti_login(request: Request):
    """Nimmt den OIDC Initiation Request von Moodle entgegen."""
    params = request.query_params if request.method == "GET" else await request.form()

    iss = params.get("iss")
    login_hint = params.get("login_hint")
    lti_message_hint = params.get("lti_message_hint")
    client_id = params.get("client_id")

    base_url = str(request.base_url).rstrip("/")
    if "ngrok" in base_url and base_url.startswith("http://"):
        base_url = base_url.replace("http://", "https://")
    redirect_uri = f"{base_url}/api/lti/launch"

    # Moodle Authentication URL
    auth_url = f"{iss}/mod/lti/auth.php"

    auth_params = {
        "response_type": "id_token",
        "scope": "openid",
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "login_hint": login_hint,
        "state": "mock_state_xyz123",
        "nonce": "mock_nonce_abc456",
        "response_mode": "form_post",
        "prompt": "none",
    }
    if lti_message_hint:
        auth_params["lti_message_hint"] = lti_message_hint

    redirect_target = f"{auth_url}?{urllib.parse.urlencode(auth_params)}"
    return RedirectResponse(url=redirect_target, status_code=302)


@app.api_route("/api/lti/launch", methods=["GET", "POST"])
async def lti_launch(request: Request):
    """Empfaengt das signierte JWT id_token tolerant via Form-Body oder URL-Parameter."""
    params = request.query_params if request.method == "GET" else await request.form()
    id_token = params.get("id_token")

    if not id_token:
        return HTMLResponse(
            content=f"""
            <div style="font-family: sans-serif; padding: 20px;">
                <h2 style="color: #b91c1c;">Kein id_token empfangen!</h2>
                <p>Der Endpunkt wurde ohne LTI-Token aufgerufen. Methode: <b>{request.method}</b></p>
                <p>Empfangene Parameter: <pre>{json.dumps(dict(params), indent=2)}</pre></p>
            </div>
            """,
            status_code=400,
        )

    # JWT payload ohne Verifikation zur Veranschaulichung dekodieren
    decoded_payload = jwt.decode(id_token, options={"verify_signature": False})

    user_id = decoded_payload.get("sub")
    name = decoded_payload.get("name", "Unbekannt")
    email = decoded_payload.get("email", "Unbekannt")
    roles = decoded_payload.get("https://purl.imsglobal.org/spec/lti/claim/roles", [])
    context = decoded_payload.get(
        "https://purl.imsglobal.org/spec/lti/claim/context", {}
    )

    is_instructor = any("Instructor" in r for r in roles)
    role_badge = "Dozent (Instructor)" if is_instructor else "Student (Learner)"

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>NextAppStore Mock Dashboard</title>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; padding: 30px; background: #f4f6f8; }}
            .card {{ background: white; padding: 24px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); max-width: 800px; margin: 0 auto; }}
            h1 {{ color: #1e293b; margin-top: 0; }}
            .badge {{ display: inline-block; padding: 4px 10px; border-radius: 4px; background: #0284c7; color: white; font-weight: bold; }}
            pre {{ background: #0f172a; color: #38bdf8; padding: 16px; border-radius: 6px; overflow-x: auto; }}
            table {{ width: 100%; border-collapse: collapse; margin-top: 15px; }}
            td, th {{ text-align: left; padding: 8px; border-bottom: 1px solid #e2e8f0; }}
        </style>
    </head>
    <body>
        <div class="card">
            <h1>NextAppStore - LTI Launch erfolgreich!</h1>
            <p>Session-Daten direkt aus Moodle empfangen:</p>
            <table>
                <tr><th>Benutzername</th><td>{name} ({email})</td></tr>
                <tr><th>User ID (sub)</th><td><code>{user_id}</code></td></tr>
                <tr><th>Erkannte Rolle</th><td><span class="badge">{role_badge}</span></td></tr>
                <tr><th>Kursname</th><td>{context.get("title", "Kein Kursname")} (ID: {context.get("id", "-")})</td></tr>
            </table>
            <h3>Vollstaendiger JWT Payload:</h3>
            <pre>{json.dumps(decoded_payload, indent=2)}</pre>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)
