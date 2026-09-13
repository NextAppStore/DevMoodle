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

    <html lang="de">

    <head>

        <meta charset="UTF-8">

        <title>NextAppStore - LTI 1.3 Integration</title>

        <style>

            :root {{

                --primary: #2563eb;

                --primary-hover: #1d4ed8;

                --bg: #0f172a;

                --surface: #1e293b;

                --card-bg: #334155;

                --text: #f8fafc;

                --text-muted: #94a3b8;

                --border: #475569;

                --success: #10b981;

            }}

            * {{ box-sizing: border-box; margin: 0; padding: 0; }}

            body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--text); padding: 20px; }}

            .container {{ max-width: 1100px; margin: 0 auto; display: flex; flex-direction: column; gap: 24px; }}

            

            /* Frontend Mock Mockup */

            .mock-window {{ background: var(--surface); border: 2px solid var(--primary); border-radius: 10px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }}

            .window-header {{ background: #090d16; padding: 10px 16px; display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid var(--border); }}

            .window-title {{ font-size: 13px; color: var(--text-muted); display: flex; align-items: center; gap: 8px; }}

            .dots {{ display: flex; gap: 6px; }}

            .dot {{ width: 10px; height: 10px; border-radius: 50%; background: #475569; }}

            .dot.red {{ background: #ef4444; }} .dot.yellow {{ background: #f59e0b; }} .dot.green {{ background: #10b981; }}

            

            .app-nav {{ background: #182234; padding: 14px 20px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border); }}

            .brand {{ font-size: 18px; font-weight: 700; color: #fff; display: flex; align-items: center; gap: 8px; }}

            .user-chip {{ background: #0f172a; padding: 6px 14px; border-radius: 20px; font-size: 13px; display: flex; align-items: center; gap: 10px; border: 1px solid var(--border); }}

            .badge {{ padding: 3px 8px; border-radius: 12px; font-size: 11px; font-weight: 700; text-transform: uppercase; }}

            .badge-instructor {{ background: #0284c7; color: white; }}

            .badge-learner {{ background: #64748b; color: white; }}

            

            .app-body {{ padding: 24px; }}

            .course-banner {{ background: linear-gradient(90deg, #1e3a8a 0%, #1e293b 100%); padding: 16px 20px; border-radius: 8px; margin-bottom: 24px; border-left: 4px solid var(--primary); display: flex; justify-content: space-between; align-items: center; }}

            .course-info h2 {{ font-size: 18px; margin-bottom: 4px; }}

            .course-info p {{ font-size: 13px; color: #cbd5e1; }}

            

            .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; }}

            .app-card {{ background: var(--card-bg); border-radius: 8px; padding: 16px; border: 1px solid var(--border); display: flex; flex-direction: column; justify-content: space-between; }}

            .app-card h4 {{ margin-bottom: 6px; font-size: 16px; }}

            .app-card p {{ font-size: 12px; color: var(--text-muted); margin-bottom: 16px; }}

            .btn {{ background: var(--primary); color: white; border: none; padding: 8px 12px; border-radius: 6px; font-size: 13px; font-weight: 600; cursor: pointer; text-align: center; }}

            .btn-outline {{ background: transparent; border: 1px solid var(--border); color: var(--text-muted); }}


            /* JWT & Auth Architecture Analysis */

            .debug-card {{ background: var(--surface); border-radius: 10px; padding: 24px; border: 1px solid var(--border); }}

            .debug-card h3 {{ color: #38bdf8; margin-bottom: 12px; display: flex; align-items: center; gap: 8px; }}

            .auth-map-table {{ width: 100%; border-collapse: collapse; margin: 16px 0 24px 0; font-size: 13px; }}

            .auth-map-table th, .auth-map-table td {{ text-align: left; padding: 10px 12px; border-bottom: 1px solid var(--border); }}

            .auth-map-table th {{ color: var(--text-muted); background: #182234; }}

            .claim-key {{ color: #a5b4fc; font-family: monospace; font-size: 12px; }}

            .target-action {{ color: #34d399; font-weight: 600; }}

            pre {{ background: #090d16; color: #38bdf8; padding: 16px; border-radius: 6px; overflow-x: auto; font-size: 12px; border: 1px solid var(--border); }}

        </style>

    </head>

    <body>

        <div class="container">


            <!-- 1. Frontend Mock Bereich -->

            <div class="mock-window">

                <div class="window-header">

                    <div class="dots">

                        <div class="dot red"></div><div class="dot yellow"></div><div class="dot green"></div>

                    </div>

                    <div class="window-title">AppStore Single Page Application (Eingebettet via LTI 1.3 IFrame)</div>

                    <div></div>

                </div>


                <div class="app-nav">

                    <div class="brand">📦 NextAppStore</div>

                    <div class="user-chip">

                        <span>👤 <b>{name}</b></span>

                        <span class="badge {"badge-instructor" if is_instructor else "badge-learner"}">{role_badge}</span>

                    </div>

                </div>


                <div class="app-body">

                    <div class="course-banner">

                        <div class="course-info">

                            <h2>📚 {context.get("title", "Allgemeiner Bereich")}</h2>

                            <p>Moodle Context ID: <code>{context.get("id", "N/A")}</code> &bull; Automatischer Tenant-Filter aktiv</p>

                        </div>

                        <div>

                            <span style="font-size: 12px; color: var(--text-muted); margin-right: 8px;">VM-Quota: <b>2 / 10 verwendet</b></span>

                        </div>

                    </div>


                    <h3 style="margin-bottom: 14px; font-size: 15px;">Verfügbare App-Templates für diesen Kurs</h3>

                    <div class="grid">

                        <div class="app-card">

                            <div>

                                <h4>🪐 Jupyter Notebook</h4>

                                <p>Interaktives Python-Lab für Data-Science-Übungen.</p>

                            </div>

                            <button class="btn">{"Instanz starten" if is_instructor else "Verbinden"}</button>

                        </div>

                        <div class="app-card">

                            <div>

                                <h4>🐧 Ubuntu 24.04 Dev</h4>

                                <p>Standard Linux-VM inkl. SSH-Key & Portfreigabe.</p>

                            </div>

                            <button class="btn">{"Instanz starten" if is_instructor else "Verbinden"}</button>

                        </div>

                        <div class="app-card">

                            <div>

                                <h4>🐘 pgAdmin & Postgres</h4>

                                <p>Vorkonfigurierte relationale Datenbankinstanz.</p>

                            </div>

                            <button class="btn">{"Instanz starten" if is_instructor else "Verbinden"}</button>

                        </div>

                        <div class="app-card">

                            <div>

                                <h4>💻 VS Code Online</h4>

                                <p>Cloud IDE für Programmierübungen im Browser.</p>

                            </div>

                            <button class="btn">{"Instanz starten" if is_instructor else "Verbinden"}</button>

                        </div>

                    </div>

                </div>

            </div>


            <!-- 2. Architektur & Token Analyse Bereich -->

            <div class="debug-card">

                <h3>🔑 Architektur-Beweis: LTI 1.3 Claims & Login-Nutzung</h3>

                <p style="color: var(--text-muted); font-size: 14px; line-height: 1.5;">

                    Folgende Parameter wurden per kryptografisch signiertem JWT direkt von Moodle übergeben. 

                    Sie zeigen, wie Moodle als vollwertiger Identity- und Rollen-Provider fungiert und Keycloak ersetzen kann:

                </p>


                <table class="auth-map-table">

                    <thead>

                        <tr>

                            <th>LTI JWT Claim</th>

                            <th>Empfangener Wert</th>

                            <th>Nutzung im NextAppStore Backend / Auth</th>

                        </tr>

                    </thead>

                    <tbody>

                        <tr>

                            <td class="claim-key">sub</td>

                            <td><code>{user_id}</code></td>

                            <td class="target-action">Eindeutige User-ID (Ersetzt Keycloak-Sub / DB-Primary-Key)</td>

                        </tr>

                        <tr>

                            <td class="claim-key">name / email</td>

                            <td>{name} ({email})</td>

                            <td class="target-action">Profil-Initialisierung & Zuordnung bei Logins</td>

                        </tr>

                        <tr>

                            <td class="claim-key">.../claim/roles</td>

                            <td><code>{"Instructor" if is_instructor else "Learner"}</code></td>

                            <td class="target-action">RBAC: {"Dozenten-Rechte (VMs anlegen/löschen)" if is_instructor else "Studenten-Rechte (Nur Read/Connect)"}</td>

                        </tr>

                        <tr>

                            <td class="claim-key">.../claim/context</td>

                            <td>ID: <code>{context.get("id", "-")}</code> ({context.get("title", "-")})</td>

                            <td class="target-action">Mandantentrennung: Filtert OpenStack-Deployments auf Kurs</td>

                        </tr>

                    </tbody>

                </table>


                <h4 style="font-size: 13px; margin-bottom: 8px; color: var(--text-muted);">Vollständiger signierter Moodle id_token Payload:</h4>

                <pre>{json.dumps(decoded_payload, indent=2)}</pre>

            </div>


        </div>

    </body>

    </html>

    """
    return HTMLResponse(content=html_content)
