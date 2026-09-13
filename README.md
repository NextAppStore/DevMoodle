# DevMoodle

Entwicklungsumgebung für Moodle inklusive vorkonfiguriertem Testkurs und LTI 1.3 Mock-Backend.

## Voraussetzungen

- [Docker](https://docs.docker.com/get-docker/) & Docker Compose
- [Git](https://git-scm.com/)
- [uv](https://docs.astral.sh/uv/) (für den Python LTI Mock Server)
- [ngrok](https://ngrok.com/) (für den LTI-Tunnel zu Moodle)

---

## Schnellstart

### 1. Repository klonen
```bash
git clone <REPO_URL>
cd DevMoodle
```

### 2. Moodle starten
```bash
./start.sh
```
Das Skript führt automatisch folgende Schritte aus:
1. Lädt bei Bedarf das Git-Submodul `moodle-docker` herunter.
2. Lädt den Moodle 4.4 Quellcode herunter (`moodle-src`).
3. Startet die Docker-Container (Webserver, PostgreSQL, Mailpit etc.).
4. Initialisiert die Moodle-Datenbank aus `moodle-data/seed.sql.gz` mit dem **fertig vorkonfigurierten Kurs**, Admin-Zugang und LTI 1.3 Tool-Registrierung.

**Zugangsdaten:**
- **Moodle URL:** [http://localhost:8000](http://localhost:8000)
- **Benutzername:** `admin`
- **Passwort:** `test`
- **Vorkonfigurierter Kurs:** [http://localhost:8000/course/view.php?id=2](http://localhost:8000/course/view.php?id=2)

---

### 3. LTI Mock Server starten

In einem separaten Terminal:
```bash
cd lti-mock-server
uv run uvicorn ltimockserver.main:app --reload --port 8080
```

### 4. Ngrok Tunnel starten & Moodle aktualisieren

In einem weiteren Terminal:
```bash
ngrok http 8080
```
Kopiere die generierte HTTPS-Adresse von ngrok (z. B. `https://xyz.ngrok-free.dev`) und führe im Projekt-Hauptverzeichnis aus:
```bash
./set-lti-url.sh https://xyz.ngrok-free.dev
```
Dadurch werden die LTI-Tool-Endpunkte in Moodle sofort auf deine aktuelle ngrok-Adresse umgestellt. Alternativ kann die URL auch direkt beim Start übergeben werden:
```bash
./start.sh --lti-url https://xyz.ngrok-free.dev
```

Jetzt kannst du im Testkurs die Aktivität **"Mock Python Backend"** anklicken und der LTI 1.3 Launch wird ausgeführt!

---

## Nützliche Skripte

| Skript | Beschreibung |
|---|---|
| `./start.sh [--lti-url <url>]` | Startet Moodle-Container und richtet bei Bedarf die DB ein. |
| `./stop.sh` | Stoppt alle laufenden Moodle-Container. |
| `./set-lti-url.sh <url>` | Aktualisiert die Endpunkte des LTI 1.3 Tools in Moodle. |
| `./export-course.sh` | Exportiert den aktuellen Zustand (DB + Kurs `.mbz`) in `moodle-data/`, um Änderungen in Git zu sichern. |
