# README

TablaBack API (Rails)

API JSON pour une application web “GuitarPro-like” : projets, partitions (scores), pistes (tracks), import asynchrone de fichiers Guitar Pro / MusicXML, et (optionnel) exports MIDI/MusicXML.

Stack :
-Ruby on Rails 7.1
-PostgreSQL
-Devise + devise-jwt (authentification JWT)
-Pundit (autorisations / policies)
-Active Storage (fichiers importés & exports)
-Sidekiq 8 + Redis ≥ 7 (jobs asynchrones)
-Sentry (sentry-rails, sentry-ruby) pour la télémétrie d’erreur

Prérequis :
  -Ruby 3.3.x, Bundler
  -PostgreSQL
  -Redis 7+ (Sidekiq 8 l’exige)
  -Node/Yarn si tu veux servir un front localement à côté (facultatif)

Installation & démarrage (dev) :
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

bin/dev (Foreman) :
  Un script bin/dev (fourni) lance Rails + Sidekiq (et Redis via Docker optionnel si tu ajoutes un process).
  Sinon, utilise ce Procfile.dev :
  web:    bin/rails s
  worker: bundle exec sidekiq -C config/sidekiq.yml
  # redis: docker run --rm -p 6379:6379 redis:7   # (optionnel)
  Puis :
  foreman start -f Procfile.dev

Configuration :
  Environnements / variables :
    Crée .env (ignoré par git) pour le dev :

    # JWT (si tu customises)
    DEVISE_JWT_SECRET_KEY=une_clé_sûre_en_dev

    # Redis (Sidekiq + Action Cable)
    REDIS_URL=redis://localhost:6379/0

    # Sentry (optionnel)
    SENTRY_DSN=

    En production, configure via variables d’env (12-factor) : DATABASE_URL, RAILS_MASTER_KEY, REDIS_URL, SENTRY_DSN, etc.

  Sidekiq :
    config/sidekiq.yml (exemple) :

    :concurrency: 5
    :queues:
      - [imports, 5]
      - [exports, 3]
      - [default, 2]

    Adapter l’adapter ActiveJob :
      # config/environments/development.rb
      config.active_job.queue_adapter = :sidekiq

  Sentry :
    Si SENTRY_DSN est présent, les exceptions seront envoyées (notamment depuis les jobs).

  Authentification :
    Login via endpoint API (Devise JWT).
    Ensuite, chaque requête : Authorization: Bearer <token>.
    Exemple rapide (selon ton AuthController) :

    curl -X POST http://localhost:3000/api/v1/auth/login \
      -H 'Content-Type: application/json' \
      -d '{"email":"user@example.com","password":"secret"}'

  Autorisations (Pundit) :
    ProjectPolicy, ScorePolicy, TrackPolicy
    Pattern d’accès : l’utilisateur ne voit que ses projets/scores/tracks.
    Les contrôleurs utilisent policy_scope(...) pour index et authorize record pour le reste.
    UploadsController : c’est un endpoint “service” → on skip les after_actions Pundit et on sécurise via current_user.projects.find(...). L’import sur un score passe par l’autorisation ScorePolicy#import? quand la ressource est résolue.

  Import & Export (asynchrone) :
    Upload + Import :
      POST /api/v1/uploads avec file + (au choix) project_id ou project_title, et optionnellement score_id ou score_title.
      L’upload attache le fichier au score, met le score en processing, puis enfile ImportScoreJob.

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

    ImportScoreJob :
      app/jobs/import_score_job.rb :
        queue_as :imports
        retry_on StandardError, wait: :exponentially_longer, attempts: 8
        MAJ du score : status: :ready + doc ou status: :failed + import_error
        Journalisation + Sentry

        Les parseurs (contrat) :
          Importers::GuitarPro.call(io) # => { doc: <Hash> }
          Importers::MusicXML.call(io)  # => { doc: <Hash> }

    Exports (optionnel) :
      ExportScoreJob (bonus) pour produire export_midi_file / export_musicxml_file et les attacher.

Routes principales :
  POST /api/v1/auth/login / DELETE /api/v1/auth/logout

  GET/POST/PATCH/DELETE /api/v1/projects

  GET/POST/PATCH/DELETE /api/v1/projects/:project_id/scores

  POST /api/v1/uploads (upload + import async)

  GET/POST/PATCH/DELETE /api/v1/projects/:project_id/scores/:score_id/tracks

  Dashboard Sidekiq (dev) : /sidekiq (voir section Sécurité ci-dessous pour la prod).

Conventions d’erreurs & statuts :
  400 :bad_request — paramètres manquants/mal formés (ex: file_missing, project_missing).

  404 :not_found — ressource absente / n’appartient pas à l’utilisateur (via scoping Pundit ou current_user.*).

  409 :conflict — (optionnel) unicité, sinon 422.

  422 :unprocessable_content (Rack 3) — validations/format non supporté (unsupported_type, validations modèle).

  202 :accepted — si tu décides de signaler “job en file d’attente”.
  Actuellement, l’upload répond 201 et met en processing.

  Remarque : Rack 3 déprécie :unprocessable_entity au profit de :unprocessable_content. Le projet utilise déjà ce dernier.

Sécurité — Sidekiq Web en production
  Protéger /sidekiq en prod (Basic Auth + session Rack). Exemple :

    # config/routes.rb
    require "sidekiq/web"
    require "rack/auth/basic"

    Sidekiq::Web.use Rack::Session::Cookie, secret: Rails.application.secret_key_base

    Rails.application.routes.draw do
      # ... tes routes API ...

      if Rails.env.development?
        mount Sidekiq::Web => "/sidekiq"
      else
        Sidekiq::Web.use Rack::Auth::Basic do |u, p|
          u == ENV["SIDEKIQ_USER"] && p == ENV["SIDEKIQ_PASSWORD"]
        end
        mount Sidekiq::Web => "/sidekiq"
      end
    end

  En prod, définis SIDEKIQ_USER / SIDEKIQ_PASSWORD (ex. via variables d’env sur l’hébergeur).

Tests :
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

  Notes tests :
  -Les endpoints “scopés” via policy_scope(...).find renvoient 404 pour les ressources d’autrui (et c’est ce que testent les specs).
  -Uploads : tests couvrent 400 file_missing, 422 unsupported_type, 201 created, 404 invalid project/score.

Action Cable / Redis :
  config/cable.yml peut pointer sur Redis également (canaux de notifications en temps réel si tu en ajoutes).
  Tu peux partager le même serveur Redis que Sidekiq, de préférence avec des DB index différents (ex. /0 pour Sidekiq, /1 pour Cable).

À faire / Roadmap rapide :
  -Parser réel GuitarPro / MusicXML → implémenter Importers::GuitarPro / Importers::MusicXML (ou brancher MusicXmlToJson MVP).
  -(Bonus) ExportScoreJob + Exporters::Midi / Exporters::MusicXML.
  -Versionner le format doc (migration & compatibilité).
  -Observabilité : métriques de queue, délai moyen, DLQ si besoin.
  -Harden sécurité (rate limiting, audit, headers).

Déploiement (prod)
  -RAILS_SERVE_STATIC_FILES=1 si assets
  -REDIS_URL=redis://... (Redis 7+)
  -RAILS_MASTER_KEY (ou credentials)
  -SENTRY_DSN (optionnel)
  -Adapter config/environments/production.rb : config.active_job.queue_adapter = :sidekiq
  -Lancer Sidekiq avec ton config/sidekiq.yml (systemd, Procfile, container)

Licence :
  Distribué sous licence **MIT**.
  Voir le fichier [`LICENSE`](./LICENSE) pour plus d’informations.

  SPDX: `MIT`
