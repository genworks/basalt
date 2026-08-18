;;; basalt.sexp - the base Basalt stack configuration
;;; -*- mode: lisp-data; -*-

;; Copyright © 2026 Genworks International
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;;
;;; The stack configuration: which services run in every Basalt
;;; deployment as installed.  This file is written in the Basalt
;;; register; glossary.sexp beside it maps these keys onto the ones
;;; the generator reads natively.  Only the generator's outputs speak
;;; docker and compose.
;;;
;;; Edit this file, then run (skewed-generate-all-configs) to regenerate:
;;;
;;;   - docker-compose.yml         (base compose config)
;;;   - mcp/mcp-container.json     (for claude/gemini CLI inside container)
;;;   - mcp/mcp-windows.json       (for Claude Desktop on Windows via WSL)
;;;   - mcp/mcp.toml               (for Codex CLI and Grok CLI)
;;;   - generated/services-generated.el
;;;
;;; DO NOT EDIT the generated files directly.
;;;
;;; A deployment takes on more services by OVERLAY: each host's *-stack
;;; repo carries its own configuration in this same register (an
;;; ingress, licensed engine variants), generated with that repo's
;;; prefix and merged by Docker Compose at up-time.  A subtractive
;;; rebuild -- trimming the base set of services -- is a fork of this
;;; repo, not an overlay.
;;;
;;; The console image ships in several variants (devo-full,
;;; devo-default, devo-lite, ...): the variant is the tag half of the
;;; image reference, so the build variant is already part of the image
;;; designation.  docker/BUILD.md in skewed-emacs carries the detail;
;;; EMACS_IMAGE_VARIANT in .env (or a --lite/--full switch) picks the
;;; variant a host runs, and this dev stack defaults to full.


(
 :meta
 (:version "2.0"
  :description "base Basalt stack configuration")

 :defaults
 (:restart "unless-stopped"
  :volumes ((:source "${PROJECTS_DIR}" :target "/projects"))
  :timezone "${TZ:-Etc/UTC}"
  :network-ipv6 t
  ;; Deviation from the upstream class defaults: a Basalt deployment
  ;; can run beside an upstream one on the same host without the two
  ;; networks contending for one address pool.
  :network-ipv4-subnet "172.21.0.0/16"
  :network-ipv6-subnet "fd00:ba5a::/80")

 ;; How MCP clients connect: the lisply-mcp wrapper that every service
 ;; with :mcp enabled answers through.
 :mcp-wrapper
 (:wrapper-path-container "/home/emacs-user/lisply-mcp/scripts/mcp-wrapper.js"
  :request-timeout-ms 30000)

 ;; ROLE QUALIFICATIONS: what an image must be capable of to fill each
 ;; role.  Requirements only -- deliberately NOT a service catalogue.
 ;; An image states its CAPABILITIES in its own manifest (the
 ;; basilisk.capabilities label -- the single source of truth for what
 ;; an image can do), and startup verifies the match, warning and
 ;; proceeding: an ability may also be provided at runtime (a
 ;; services-init hook, at boot or later), which the manifest cannot
 ;; know.  A service's :post may be a LIST -- one service filling
 ;; several roles, none primary, ordering meaningless -- and its name
 ;; is a slug incorporating every role it fills, abbreviation allowed.
 :postings
 (;; A skewed-emacs console is recommended, not required -- the
  ;; qualification scheme says exactly that: a console from another
  ;; image starts with a warning and proceeds.
  (:post :captain :requires ("skewed-emacs"))
  (:post :1st-officer
   :description "Front-line interactive service: assists the console and its users."
   :requires ("gendl"))
  (:post :ships-engineer :requires ("gendl"))
  (:post :transporter-chief :requires ("reverse-proxy"))
  (:post :communications-officer
   :description "Runs the monitoring dashboard; polls the fleet."
   :requires ("bridge viewscreen operations")))

 :services
 (
  ;; NAMES ARE ROLES, not images.  :name becomes the compose service
  ;; name, the container_name and the hostname; the IMAGE is the full
  ;; registry reference; and a per-container identity is written into
  ;; the container at up-time.
  ;;
  ;; ONLY :image IS REQUIRED of a service entry.  :name is the
  ;; author's slug and optional: absent, it derives from the roles
  ;; filled (hyphen-joined), or, for an image deployed with NO
  ;; assigned role -- entered on the roster as unassigned -- as
  ;; unassigned-<repo>, the prefix making one obvious from its name
  ;; alone.  :post is only needed when capabilities are expected of
  ;; the service.  Explicit names below where derivation could not
  ;; tell two of a role apart (-human/-cyborg), or where an
  ;; abbreviated slug earns its keep.
  (:post :captain
   :description "The interactive control console, and the longest-lived process in the stack."
   :type "emacs-lisp"
   :mcp t
   :image "gornskew/${EMACS_IMAGE_BASE:-skewed-emacs}:${EMACS_IMAGE_BRANCH:-devo}-${EMACS_IMAGE_VARIANT:-full}"
   :ports ((:name "http" :container 7080)
           (:name "webterm" :container 6942 :host ${TTYD_HOST_PORT:-6942}))
   :environment (("WEBTERM" . "${WEBTERM:-ttyd}")
                 ("WEBTERM_PORT" . "6942")
                 ("TERM" . "xterm-256color")
                 ("COLORTERM" . "truecolor"))
   ;; The console's credentials and local config, mounted from the host.
   :volumes ((:source "${USER_HOME}/.claude/.credentials.json"
              :target "/home/emacs-user/.claude/.credentials.json")
             (:source "${USER_HOME}/.gemini/google_accounts.json"
              :target "/home/emacs-user/.gemini/google_accounts.json")
             (:source "${USER_HOME}/.gemini/oauth_creds.json"
              :target "/home/emacs-user/.gemini/oauth_creds.json")
             (:source "${USER_HOME}/.codex/auth.json"
              :target "/home/emacs-user/.codex/auth.json")
             ;; Credentials only -- never mount all of ~/.grok: it
             ;; would shadow the image's own grok binary under
             ;; ~/.grok/bin and downloads.
             (:source "${USER_HOME}/.grok/auth.json"
              :target "/home/emacs-user/.grok/auth.json")
             (:source "/tmp/.X11-unix" :target "/tmp/.X11-unix" :mode "rw")
             (:source "${EMACS_LOCAL_SRC:-/nonexistent}/.emacs-local"
              :target "/home/emacs-user/.emacs-local" :mode "ro")
             (:source "${EMACS_LOCAL_SRC:-/nonexistent}/.emacs-local-early"
              :target "/home/emacs-user/.emacs-local-early" :mode "ro"))
   ;; How this service shows on a monitoring dashboard.  :in-stack is
   ;; the ONLY sanctioned routing for the :emacs kind -- emacs lisply
   ;; has no token gate, so it never rides a public path.  From
   ;; outside the stack, the console is sampled through that
   ;; deployment's own gendl-ccl proxy (publish-emacs-metrics!),
   ;; which is gated.
   :probe (:tile "heap skewed-emacs"
           :in-stack (:kind :emacs
                      :url "http://captain:7080/lisply/lisp-eval"
                      :alert-mb 2000)
           :remote (:kind :metrics
                    :path "/eyes-only-metrics/skewed-emacs"
                    :alert-mb 2000))
   :healthcheck (:endpoint "/lisply/ping-lisp" :interval "30s"))

  ;; The front-line interactive service: assists the console and its
  ;; users.  The usual fit is the gendl ccl variant (the engineering
  ;; service below being gendl sbcl); the :image pin is what
  ;; GUARANTEES it -- the role states the duty, the image states the
  ;; software.  It keeps its historical name for now: rules and
  ;; templated configs address ROLES through the service ledger
  ;; (generated/crew.env), so the name can catch up in a later
  ;; recreate without anything else moving.
  (:name "jr-eng-human"
   :post :1st-officer
   :description "Front-line interactive service: assists the console and its users."
   :type "common-lisp"
   :image "gornskew/${GENDL_IMAGE_BASE:-gendl}:${GENDL_IMAGE_BRANCH:-devo}-ccl"
   :ports ((:name "http" :host ${GENDL_CCL_HOST_PORT:-19080} :container 9080)
           (:name "swank" :container 4200))
   :mcp t
   ;; One probe for the pair of engine services, and it rides here:
   ;; this one carries the metrics publisher; the sbcl service
   ;; publishes nothing, so there is no tile to ask for.  No
   ;; :in-stack form either -- a local dashboard samples its own
   ;; deployment's image without a probe entry.
   :probe (:tile "heap gendl-ccl"
           :remote (:kind :metrics
                    :path "/eyes-only-metrics/gendl-ccl"
                    :alert-mb 1200))
   :healthcheck (:endpoint "/lisply/ping-lisp" :interval "72s"))

  ;; The engineering service: the gendl sbcl variant.
  (:name "jr-eng-cyborg"
   :post :ships-engineer
   :description "The engineering service: computation and geometry for the stack and its users."
   :type "common-lisp"
   :image "gornskew/${GENDL_IMAGE_BASE:-gendl}:${GENDL_IMAGE_BRANCH:-devo}-sbcl"
   :ports ((:name "http" :host ${GENDL_SBCL_HOST_PORT:-29080} :container 9090)
           (:name "swank" :container 4210))
   :mcp t
   :healthcheck (:endpoint "/lisply/ping-lisp" :interval "90s"))

  ;; The monitor watches for hung services (added 2026-07-26, after a
  ;; console fell into an unbounded call and could not recover from
  ;; within).  A healthcheck only MARKS a container unhealthy; nothing
  ;; restarts it without an actor, so recovery must come from outside
  ;; the affected process.  The monitor restarts ANY service that
  ;; fails its healthcheck.
  (:post :medic
   :description "Watches for hung services and restarts them."
   :type "utility"
   :image "willfarrell/autoheal:latest"
   :environment (("AUTOHEAL_CONTAINER_LABEL" . "all")
                 ("AUTOHEAL_INTERVAL" . "15")
                 ("AUTOHEAL_START_PERIOD" . "60"))
   ;; The host's docker socket: how the monitor reaches the services.
   :volumes ((:source "/var/run/docker.sock"
              :target "/var/run/docker.sock")))
  )
 )
