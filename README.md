# README

# TablaBack API (Rails)

API JSON pour une application web **“GuitarPro-like”** :
gestion de projets, partitions (scores), pistes (tracks), import asynchrone de fichiers Guitar Pro / MusicXML, et exports (MIDI / PDF / PNG).

---

## ⚙️ Stack technique

- Ruby on Rails 7.1
- PostgreSQL
- Devise + devise-jwt (authentification JWT)
- Pundit (autorisations / policies)
- Active Storage (fichiers importés & exports)
- Sidekiq 8 + Redis ≥ 7 (jobs asynchrones)
- Sentry (sentry-rails, sentry-ruby) pour la télémétrie d’erreur

---

## 📦 Prérequis

- Ruby 3.3.x, Bundler
- PostgreSQL
- Redis 7+ (Sidekiq 8 l’exige)
- Node/Yarn (facultatif, pour un front local en dev)

---

## 🚀 Installation & démarrage (dev)

  # 1) Dépendances
  bundle install
  # 2) DB
  rails db:setup   # crée + migre + seeds si présents
  # 3) Redis (au choix)
  # Docker :
  docker run -p 6379:6379 --name redis -d redis:7
  # OU service local :
  redis-server
  # 4) Lancer API + jobs
  bin/dev        # (via Foreman)
  # ou, séparé :
  rails s
  # puis dans un autre terminal
  bundle exec sidekiq -C config/sidekiq.yml

## bin/dev (Foreman) :

  Un script bin/dev (fourni) lance Rails s + Sidekiq (et Redis via Docker optionnel si tu ajoutes un process).
  Sinon, utilise ce Procfile.dev :
  web:    bin/rails s
  worker: bundle exec sidekiq -C config/sidekiq.yml
  redis: docker run --rm -p 6379:6379 redis:7   (optionnel)
  Puis :
  foreman start -f Procfile.dev

## Configuration :

  # Environnements / variables :
    Crée .env (ignoré par git) pour le dev :

    # 1) JWT (si tu customises)

    DEVISE_JWT_SECRET_KEY=une_clé_sûre_en_dev

    # 2) Redis (Sidekiq + Action Cable)

    REDIS_URL=redis://localhost:6379/0

    # 3) Sentry (optionnel)

    SENTRY_DSN=

    En production, configure via variables d’env (12-factor) : DATABASE_URL, RAILS_MASTER_KEY, REDIS_URL, SENTRY_DSN, etc.

  # Sidekiq :
    config/sidekiq.yml (exemple) :

    :concurrency: 5
    :queues:
      - [imports, 5]
      - [exports, 3]
      - [default, 2]

    ActiveJob -> Adapter Sidekiq :
      # config/environments/development.rb
      config.active_job.queue_adapter = :sidekiq

  # Sentry :
    Si SENTRY_DSN est présent, les exceptions seront envoyées (notamment depuis les jobs).

  # Authentification :
    Login via endpoint API (Devise JWT).
    Ensuite, chaque requête : Authorization: Bearer <token>.
    Exemple rapide (selon ton AuthController) :

    curl -X POST http://localhost:3000/api/v1/auth/login \
      -H 'Content-Type: application/json' \
      -d '{"email":"user@example.com","password":"secret"}'

  # Autorisations (Pundit) :
    ProjectPolicy, ScorePolicy, TrackPolicy
    Pattern d’accès : l’utilisateur ne voit que ses projets/scores/tracks.
    Les contrôleurs utilisent policy_scope(...) pour index et authorize record pour le reste.
    UploadsController : c’est un endpoint “service” → on skip les after_actions Pundit et on sécurise via current_user.projects.find(...). L’import sur un score passe par l’autorisation ScorePolicy#import? quand la ressource est résolue.

## Import & Export (asynchrone) :

  # 1) Formats supportés:
    Canon (interne) : .mxl (compressed MusicXML)
    Sources acceptées : -Guitar Pro : .gp3, .gp4, .gp5, .gpx, .gp
                        -MusicXML clair : .xml, .musicxml
                        -MusicXML compressé : .mxl
    Exports générés : -MIDI (.mid)
                      -PDF (.pdf)
                      -PNG (pages preview)

  # 2) Cycle d’import
    Upload → Score en processing
    Canonisation → attache du .mxl (normalized_mxl)
    Génération des exports : .mid, .pdf, page-*.png
    Indexation via MusicxmlIndexer (tempo, pistes, notes, durée)
    Score en ready (ou failed si erreur)

  # 3) Endpoint Upload

    POST /api/v1/uploads avec file + (au choix) project_id ou project_title, et optionnellement score_id ou score_title.
    L’upload attache le fichier au score, met le score en processing, puis enfile ImportScoreJob :

      curl -X POST http://localhost:3000/api/v1/uploads \
        -H "Authorization: Bearer <TOKEN>" \
        -F "file=@/path/to/partition.gp3" \
        -F "project_id=123"


    Réponse (201) :
      {
        "ok": true,
        "project_id": 123,
        "score_id": 456,
        "status": "processing",
        "imported_format": "guitarpro",
        "source_url": "http://.../rails/active_storage/blobs/..."
      }

    Le job va parser en tâche de fond et mettre le score en ready ou failed.

## Routes principales :

    POST /api/v1/auth/login
    DELETE /api/v1/auth/logout
    GET/POST/PATCH/DELETE /api/v1/projects
    GET/POST/PATCH/DELETE /api/v1/projects/:project_id/scores
    POST /api/v1/uploads (upload + import async)
    GET/POST/PATCH/DELETE /api/v1/projects/:project_id/scores/:score_id/tracks
    Dashboard Sidekiq (dev) : /sidekiq (voir section Sécurité ci-dessous pour la prod).

## Conventions d’erreurs & statuts :

    400 :bad_request — paramètres manquants/mal formés (ex: file_missing, project_missing).

    404 :not_found — ressource absente / n’appartient pas à l’utilisateur (via scoping Pundit ou current_user.*).

    409 :conflict — (optionnel) unicité, sinon 422.

    422 :unprocessable_content (Rack 3) — validations/format non supporté (unsupported_format, attach_failed, validations modèle).

    202 :accepted — si tu décides de signaler “job en file d’attente”.

    201 :created — upload accepté et score en processing

    Remarque : Rack 3 déprécie :unprocessable_entity au profit de :unprocessable_content. Le projet utilise déjà ce dernier.

## Sécurité — Sidekiq Web en production

    Sidekiq Web protégé en production (/sidekiq) avec Basic Auth.

    Variables d’env obligatoires : SIDEKIQ_USER, SIDEKIQ_PASSWORD.

    En prod, définis SIDEKIQ_USER / SIDEKIQ_PASSWORD (ex. via variables d’env sur l’hébergeur).

## Tests :

    -RSpec (request specs + policy specs)
    -pundit/rspec + (optionnel) pundit-matchers
    -Helpers JWT pour headers d’auth dans spec/support

    Lancer la suite :
      bundle exec rspec
      # ou
      bundle exec rspec -fd

    Exécuter un fichier précis :
      bundle exec rspec spec/requests/api/v1/projects_spec.rb

    Exécuter une ligne précise :
      bundle exec rspec spec/requests/api/v1/projects_spec.rb:42

## Déploiement (prod)

  -RAILS_SERVE_STATIC_FILES=1 si assets
  -REDIS_URL=redis://... (Redis 7+)
  -RAILS_MASTER_KEY (ou credentials)
  -SENTRY_DSN (optionnel)
  -Adapter config/environments/production.rb : config.active_job.queue_adapter = :sidekiq
  -Lancer Sidekiq avec ton config/sidekiq.yml (systemd, Procfile, container)

## Licence :

  Distribué sous licence **MIT**.
  Voir le fichier [`LICENSE`](./LICENSE) pour plus d’informations.

  SPDX: `MIT`
