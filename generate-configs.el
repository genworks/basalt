;;; generate-configs.el --- Generate configs from basilisk.sexp -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;;
;;; Usage: (load "/projects/skewed-emacs/generate-configs.el")
;;;        (skewed-generate-all-configs)
;;;
;;; Or from command line:
;;;   emacs --batch -l generate-configs.el -f skewed-generate-all-configs
;;;
;;; For overlays (non-skewed-emacs directories), also generates install script.
;;;
;;; This generator reads ONE basilisk.sexp and outputs configs.
;;; Overlay behavior is handled at runtime:
;;;   - Docker Compose: native multi-file merge (-f base.yml -f overlay.yml)
;;;   - MCP configs: merged at startup via mcp/merge-configs.sh
;;;   - Install script: auto-generated for overlays (non-empty prefix);;; This generator reads ONE basilisk.sexp and outputs configs.
;;; Overlay behavior is handled at runtime:
;;;   - Docker Compose: native multi-file merge (-f base.yml -f overlay.yml)
;;;   - MCP configs: merged at startup via mcp/merge-configs.sh

;;; Code:

(require 'cl-lib)
(require 'json)

(defvar skewed-gen-yard-dir
  (file-name-directory (or load-file-name buffer-file-name default-directory))
  "The yard: the directory this generator was loaded from.")

(defvar skewed-gen-articles-filename
  (concat (file-name-nondirectory (directory-file-name skewed-gen-yard-dir))
          ".sexp")
  "The articles filename this yard reads -- the yard's own name with a
.sexp extension, so the canonical basilisk yard reads basilisk.sexp.
The file describes a standard ship of the yard's class, and carries the
class name.  A register fork renames its repo and names its articles to
match; articles written for a differently-named yard are NOT read, so a
foreign overlay fails loudly rather than quietly composing.")

(defvar skewed-gen-input-file nil
  "Input articles file. Set before calling generator.")

(defvar skewed-gen-output-dir nil
  "Output directory for generated files. Set before calling generator.")

(defvar skewed-gen-output-prefix ""
  "Prefix for output filenames (e.g. 'betatest-' for overlay configs).")

;;; ============================================================================
;;; Reading and Parsing
;;; ============================================================================

(defun skewed--read-sexp-file (filepath)
  "Read and parse a .sexp file, returning the plist."
  (when (file-exists-p filepath)
    (with-temp-buffer
      (insert-file-contents filepath)
      (goto-char (point-min))
      (read (current-buffer)))))

(defun skewed--get-prop (plist key)
  "Get property KEY from PLIST."
  (plist-get plist key))

(defun skewed--has-mcp-services-p (config)
  "Non-nil if CONFIG's crew has anyone with :cyborg-passengers-allowed?."
  (cl-some (lambda (svc) (skewed--get-prop svc :cyborg-passengers-allowed?))
           (skewed--get-prop config :crew)))

(defun skewed--mcp-approved-tools (_svc)
  "Return the standard tool names that should be pre-approved for an MCP service."
  '("ping_lisp" "http_request" "lisp_eval"))

;;; ============================================================================
;;; skewed_search Config Generation
;;; ============================================================================


;;; ============================================================================
;;; Docker Compose Generation
;;; ============================================================================

(defun skewed--generate-compose-yaml (config)
  "Generate docker-compose.yml content from CONFIG."
  (let* ((defaults (skewed--get-prop config :defaults))
         (services (skewed--get-prop config :crew))
         ;; Fallback NAME only, for a hull fitted out by hand before
         ;; the yard has minted him one: he sails under the class name.
         ;; (Every ./basilisk raise sets DOCKER_NETWORK_NAME from .ship.)
         (network-name (or (skewed--get-prop defaults :network) "basilisk"))
         (lines '()))
    
    ;; Header
    (push "# Copyright © 2026 Gornskew Enterprises" lines)
    (push "#" lines)
    (push "# This program is free software: you can redistribute it and/or modify" lines)
    (push "# it under the terms of the GNU Affero General Public License as" lines)
    (push "# published by the Free Software Foundation, either version 3 of the" lines)
    (push "# License, or (at your option) any later version.  Distributed WITHOUT" lines)
    (push "# ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>." lines)
    (push "" lines)
    (push (format "# DO NOT EDIT - Generated from %s" skewed-gen-articles-filename) lines)
    (push "# Regenerate with: (skewed-generate-all-configs)" lines)
    (push "" lines)
    
    ;; Only include networks block for base config (no prefix)
    (when (string-empty-p skewed-gen-output-prefix)
      (let ((ipv6        (skewed--get-prop defaults :network-ipv6))
            (ipv4-subnet (skewed--get-prop defaults :network-ipv4-subnet))
            (ipv6-subnet (skewed--get-prop defaults :network-ipv6-subnet)))
        ;; The compose-file KEY is the static word `ship' -- the
        ;; docker network IS the ship, and yaml keys cannot carry a
        ;; minted name.  The network's actual NAME comes from .ship
        ;; via DOCKER_NETWORK_NAME: struck and grown anew at each
        ;; raise, same name for the life of the clone.
        (push "networks:" lines)
        (push "  ship:" lines)
        (push (format "    name: ${DOCKER_NETWORK_NAME:-%s}" network-name) lines)
        (push "    driver: bridge" lines)
        (when ipv6
          (push "    enable_ipv6: true" lines)
          (when (or ipv4-subnet ipv6-subnet)
            (push "    ipam:" lines)
            (push "      config:" lines)
            (when ipv4-subnet
              (push (format "        - subnet: \"%s\"" ipv4-subnet) lines))
            (when ipv6-subnet
              (push (format "        - subnet: \"%s\"" ipv6-subnet) lines))))
        (push "" lines)))

    
    (push "services:" lines)
    (push "" lines)
    
    ;; Services
    (dolist (svc services)
      (let* ((name (skewed--get-prop svc :name))
             (image (skewed--get-prop svc :image))
             (ports (skewed--get-prop svc :hailing-frequencies))
             (env (skewed--get-prop svc :space-suit))
             (vols (skewed--get-prop svc :cargo-bays))
             (user (skewed--get-prop svc :user))
             (network-mode (skewed--get-prop svc :network-mode))
             (extra-hosts (skewed--get-prop svc :extra-hosts))
             (group-add (skewed--get-prop svc :group-add))
             (healthcheck (skewed--get-prop svc :healthcheck))
             (env-file (skewed--get-prop svc :env-file))
             (restart (or (skewed--get-prop svc :restart)
                          (skewed--get-prop defaults :restart)
                          "unless-stopped")))
        
        (push (format "  %s:" name) lines)
        (when image
          (push (format "    image: %s" image) lines))
        ;; :pull-policy "never" marks a species grown in the local vat
        ;; only (a trial tag not yet published to any home planet), so
        ;; a --pull raising does not go begging the registries for it.
        (let ((pull-policy (skewed--get-prop svc :pull-policy)))
          (when pull-policy
            (push (format "    pull_policy: %s" pull-policy) lines)))
        ;; ROOMS ARE KNOWN BY THEIR KEEPERS (ruling 2026-08-23).
        ;;
        ;; container_name carries the PRIMARY RESIDENT'S MINTED NAME --
        ;; docker's native name field is the crew name, nothing invented.
        ;; The muster (compose-dev's muster_crew) mints it at up-time,
        ;; persists it in .muster, and exports BASILISK_CREW_<MODULE>;
        ;; the fallback is the module slug, so a bare compose invocation
        ;; still raises an unmustered but working ship.  A recreate under
        ;; a fresh name IS a relief: new face, new name, same room.
        ;; ${BASILISK_PREFIX} still guards the one genuinely daemon-global
        ;; collision between instances.
        ;;
        ;; hostname stays the MODULE SLUG -- the room's own address.
        ;; Service key, hostname and in-network DNS all answer to the
        ;; plain room type (the type-hail: ready-room, bridge,
        ;; museum-chamber), so mcp-exec's --backend-host, probes and the
        ;; chief's standing orders reference rooms, never residents, and
        ;; survive every relief untouched.
        (push (format "    container_name: ${BASILISK_PREFIX:-}${%s:-%s}"
                      (skewed--crew-env-name name) name)
              lines)
        (push (format "    hostname: %s" name) lines)
        ;; DECLARED TAXONOMY, as a label (Dave, 2026-08-16).  A service
        ;; must say which :post it stands.  Emitting it as a label is
        ;; what lets mint_crew_identities and `docker ps -f label=...`
        ;; read the posting instead of pattern-matching a hostname, and
        ;; it is authoritative: the declared label beats the hostname.
        ;;
        ;; THERE IS NO :species LABEL any more (Dave, 2026-08-17).
        ;; Species is the image type -- it is spelled `image:' two lines
        ;; up -- so a second, declarable copy of it could only ever
        ;; disagree with the thing it was describing.  Nothing declared
        ;; :species in any basilisk.sexp when this came out, and nothing
        ;; read the label but the resolution chain that went with it.
        (let* ((raw-post (skewed--get-prop svc :post))
               ;; :post may be a LIST -- one crew member standing
               ;; several posts.  The label carries them all,
               ;; comma-joined.  NO POSTING IS PRIMARY and ordering
               ;; carries no meaning (mixin-like; conflicts get dealt
               ;; with when observed), so consumers must never read
               ;; position as primacy.
               (post (and raw-post
                          (mapconcat (lambda (p)
                                       (if (keywordp p)
                                           (substring (symbol-name p) 1)
                                         (format "%s" p)))
                                     (skewed--ensure-list raw-post) ",")))
               ;; REQUIREMENTS ride as a label so the crew muster can
               ;; verify them at up-time against the species' own
               ;; capability list -- the basilisk.capabilities label
               ;; on the IMAGE manifest, the SSoT for what an image
               ;; can do (Dave, 2026-08-17).  Already unioned with the
               ;; requirements of every stood posting by
               ;; `skewed--resolve-post-requires'.
               (requires (skewed--get-prop svc :requires))
               ;; The MODULE TYPE rides as a label so the muster can
               ;; render "Thweed's ready room" from the container alone,
               ;; and tooling can find a room by type regardless of who
               ;; keeps it this tour (docker ps -f label=basilisk.module=...).
               (module (skewed--get-prop svc :module))
               ;; :unhurried? -- this hand's warm-up does not hold the
               ;; gangway: validation starts him and moves on, leaving
               ;; the slow boot to finish in the background under the
               ;; Doctor's watch (the museum chamber's antique).
               (unhurried (skewed--get-prop svc :unhurried?)))
          (when (or post requires module unhurried)
            (push "    labels:" lines)
            (when post
              (push (format "      basilisk.post: \"%s\"" post) lines))
            (when module
              (push (format "      basilisk.module: \"%s\"" module) lines))
            (when requires
              (push (format "      basilisk.requires: \"%s\""
                            (mapconcat #'identity requires ","))
                    lines))
            (when unhurried
              (push "      basilisk.unhurried: \"true\"" lines))))
        (when user (push (format "    user: %s" user) lines))
        (push (format "    restart: %s" restart) lines)
        ;; :init? t berths docker's own tiny init as PID 1.  For a
        ;; species whose entrypoint is a bare interpreter process (a
        ;; python or node serving as PID 1 gets no default signal
        ;; dispositions from the kernel, so SIGTERM is silently
        ;; ignored), this is what lets the hand answer a stop order
        ;; instead of eating the whole stop_grace_period and taking
        ;; the SIGKILL -- whose late endpoint cleanup then races
        ;; compose's network rm at down (see release_ship in
        ;; compose-dev).
        (when (skewed--get-prop svc :init?)
          (push "    init: true" lines))
        (push "    stdin_open: true" lines)
        (push "    tty: true" lines)
        ;; A filtered hull takes no writes; whatever must stay
        ;; breathable rides tmpfs and is gone at power-down.  (The
        ;; museum chamber's atmospheric filtering -- filtered, not
        ;; sealed: its declared lines still ride the ship's network.)
        ;; :sealed-hull? is the retired name for the same key,
        ;; honored so older articles keep generating.
        (when (or (skewed--get-prop svc :filtered-hull?)
                  (skewed--get-prop svc :sealed-hull?))
          (push "    read_only: true" lines))
        (let ((breathable (skewed--get-prop svc :breathable-volumes)))
          (when breathable
            (push "    tmpfs:" lines)
            (dolist (vol breathable)
              (push (format "      - %s" vol) lines))))
        (when network-mode
          (push (format "    network_mode: %s" network-mode) lines))
        
        ;; Ports
        (unless network-mode
          (let ((ports-with-host (cl-remove-if-not (lambda (p) (skewed--get-prop p :galaxy)) ports)))
            (when ports-with-host
              (push "    ports:" lines)
              (dolist (port ports-with-host)
                (let ((container (skewed--get-prop port :aboard))
                      (host (skewed--get-prop port :galaxy)))
                  (push (format "      - \"%s:%s\"" host container) lines))))))
        
        ;; Environment
        (push "    environment:" lines)
        (dolist (port ports)
          (let ((port-name (upcase (skewed--get-prop port :name)))
                (container (skewed--get-prop port :aboard))
                (host (skewed--get-prop port :galaxy)))
            (when (equal port-name "HTTP")
              (push (format "      - HTTP_PORT=%s" container) lines)
              (when host
                (push (format "      - HTTP_HOST_PORT=%s" host) lines))
              (push "      - START_HTTP=true" lines))
            (when (equal port-name "SWANK")
              (push (format "      - SWANK_PORT=%s" container) lines)
              (when host
                (push (format "      - SWANK_HOST_PORT=%s" host) lines))
              (push "      - START_SWANK=true" lines))))
        (dolist (env-pair env)
          ;; Quote the whole NAME=VALUE as a YAML single-quoted scalar.
          ;; Unquoted values with a trailing colon (e.g. HTTP_HOST=::)
          ;; parse as YAML mappings and break docker compose validation.
          (push (format "      - '%s=%s'"
                        (car env-pair)
                        (replace-regexp-in-string "'" "''"
                                                  (format "%s" (cdr env-pair))))
                lines))
        (push (format "      - TZ=%s" (or (skewed--get-prop defaults :timezone) "${TZ:-Etc/UTC}")) lines)

        ;; env_file (long-form, required:false) -- lets a service read
        ;; secrets from an uncommitted per-host file without breaking
        ;; startup when the file is absent (default-secure).  Each spec is
        ;; a string PATH (required) or a plist (:path P :required BOOL).
        (when env-file
          (push "    env_file:" lines)
          (dolist (spec (cond ((stringp env-file) (list env-file))
                              ((keywordp (car env-file)) (list env-file))
                              (t env-file)))
            (let ((path (if (stringp spec) spec (skewed--get-prop spec :path)))
                  (required (if (stringp spec) t (skewed--get-prop spec :required))))
              (push (format "      - path: %s" path) lines)
              (push (format "        required: %s" (if required "true" "false")) lines))))
        
        ;; Volumes.  A crew entry with :no-default-cargo? takes nothing
        ;; from dockside: the default cargo bays stay ashore (the sealed
        ;; museum chamber -- an airgap alone does not refuse a mount).
        (let ((default-vols (unless (skewed--get-prop svc :no-default-cargo?)
                              (skewed--get-prop defaults :cargo-bays)))
              (svc-vols vols))
          (when (or default-vols svc-vols)
            (push "    volumes:" lines))
          (dolist (vol default-vols)
            (let ((src (skewed--get-prop vol :dockside))
                  (tgt (skewed--get-prop vol :stowed-at)))
              (push "      - type: bind" lines)
              (push (format "        source: %s" src) lines)
              (push (format "        target: %s" tgt) lines)
              (push "        bind:" lines)
              (push "          create_host_path: true" lines)))
          (dolist (vol svc-vols)
            (let ((src (skewed--get-prop vol :dockside))
                  (tgt (skewed--get-prop vol :stowed-at))
                  (mode (skewed--get-prop vol :mode)))
              (if mode
                  (push (format "      - %s:%s:%s" src tgt mode) lines)
                (push (format "      - %s:%s" src tgt) lines)))))
        
        ;; Extra hosts
        (when (and extra-hosts (not network-mode))
          (push "    extra_hosts:" lines)
          (dolist (host-pair extra-hosts)
            (push (format "      - \"%s:%s\"" (car host-pair) (cdr host-pair)) lines)))
        
        ;; Group add
        (when group-add
          (push "    group_add:" lines)
          (dolist (grp group-add)
            (push (format "      - \"%s\"" grp) lines)))
        
        ;; Ulimits
        (let ((ulimits (skewed--get-prop svc :ulimits)))
          (when ulimits
            (push "    ulimits:" lines)
            (dolist (ul ulimits)
              (let* ((resource (let* ((raw (symbol-name (skewed--get-prop ul :resource)))
                       (stripped (if (string-prefix-p ":" raw) (substring raw 1) raw)))
                  (downcase stripped)))
                     (soft (skewed--get-prop ul :soft))
                     (hard (skewed--get-prop ul :hard)))
                (push (format "      %s:" resource) lines)
                (when soft (push (format "        soft: %s" soft) lines))
                (when hard (push (format "        hard: %s" hard) lines))))))

                ;; Networks
        (unless network-mode
          (push "    networks:" lines)
          (let ((alias (skewed--get-prop svc :network-alias)))
            (if alias
                ;; A relieving crew member answers to the relieved
                ;; name as well: everyone who hails the old name
                ;; (cyclops backends, MCP configs, SLIME) reaches the
                ;; same container.
                (progn
                  (push "      ship:" lines)
                  (push "        aliases:" lines)
                  (push (format "          - %s" alias) lines))
              (push "      - ship" lines))))
        
        ;; Healthcheck
        (when healthcheck
          (let ((endpoint (skewed--get-prop healthcheck :endpoint))
                (interval (or (skewed--get-prop healthcheck :interval) "60s"))
                (http-port (skewed--get-prop
                            (cl-find-if (lambda (p) (equal (skewed--get-prop p :name) "http")) ports)
                            :aboard)))
            (push "    healthcheck:" lines)
            (push (format "      test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:%s%s\"]"
                          (or http-port 80) endpoint) lines)
            (push (format "      interval: %s" interval) lines)
            (push "      timeout: 3s" lines)
            (push "      retries: 3" lines)
            (push "      start_period: 15s" lines)))

        (push "" lines)))

    ;; RELIEVED base crew: each name here is stood by a renamed crew
    ;; member above (which carries it as a network alias).  The stub
    ;; assigns a never-activated profile, so compose defines the base
    ;; service but does not start it.
    (dolist (victim (skewed--get-prop config :relieved-names))
      (push (format "  # %s is relieved: the post is stood by a renamed crew member" victim) lines)
      (push (format "  %s:" victim) lines)
      (push "    profiles:" lines)
      (push "      - relieved" lines)
      (push "" lines))

    (string-join (nreverse lines) "\n")))

;;; ============================================================================
;;; MCP Config Generation  
;;; ============================================================================

(defun skewed--generate-mcp-json-container (config)
  "Generate MCP config for in-container usage (claude/gemini CLI)."
  (let* ((mcp-config (skewed--get-prop config :mcp))
         (wrapper-path (skewed--get-prop mcp-config :wrapper-path-container))
         (request-timeout (skewed--get-prop mcp-config :request-timeout-ms))
         (services (skewed--get-prop config :crew))
         (servers '()))

    (dolist (svc services)
      (when (skewed--get-prop svc :cyborg-passengers-allowed?)
        (let* ((name (skewed--get-prop svc :name))
               (ports (skewed--get-prop svc :hailing-frequencies))
               (http-port (skewed--get-prop
                           (cl-find-if (lambda (p) (equal (skewed--get-prop p :name) "http")) ports)
                           :aboard))
               (args (list wrapper-path
                           "--server-name" name
                           "--backend-host" name
                           "--http-port" (number-to-string http-port))))
          (when request-timeout
            (setq args (append args (list "--request-timeout-ms"
                                          (number-to-string request-timeout)))))
          (push (cons name `((command . "node")
                             (args . ,(vconcat args))))
                servers))))

    (let ((json-encoding-pretty-print t))
      (json-encode (list (cons 'mcpServers (nreverse servers)))))))

(defun skewed--generate-mcp-json-windows (config)
  "Generate MCP config for Windows Claude Desktop via WSL.
Uses placeholder ${SKEWED_CLONE_PATH} which gets substituted at merge time."
  (let* ((exec-path "${SKEWED_CLONE_PATH}/mcp/mcp-exec")
         (request-timeout (skewed--get-prop (skewed--get-prop config :mcp) :request-timeout-ms))
         (services (skewed--get-prop config :crew))
         (servers '()))

    (dolist (svc services)
      (when (skewed--get-prop svc :cyborg-passengers-allowed?)
        (let* ((name (skewed--get-prop svc :name))
               (ports (skewed--get-prop svc :hailing-frequencies))
               (http-port (skewed--get-prop
                           (cl-find-if (lambda (p) (equal (skewed--get-prop p :name) "http")) ports)
                           :aboard))
               (args (list exec-path
                           "--server-name" name
                           "--backend-host" name
                           "--http-port" (number-to-string http-port))))
          (when request-timeout
            (setq args (append args (list "--request-timeout-ms"
                                          (number-to-string request-timeout)))))
          (push (cons name `((command . "wsl")
                             (args . ,(vconcat args))))
                servers))))

    (let ((json-encoding-pretty-print t))
      (json-encode (list (cons 'mcpServers (nreverse servers))
                         (cons 'globalShortcut ""))))))

(defun skewed--generate-mcp-toml (config)
  "Generate MCP config in TOML format for Codex and Grok.
Codex also gets nested tool-approval tables; Grok's merge step
filters those out and keeps only top-level [mcp_servers.NAME] tables."
  (let* ((mcp-config (skewed--get-prop config :mcp))
         (wrapper-path (skewed--get-prop mcp-config :wrapper-path-container))
         (request-timeout (skewed--get-prop mcp-config :request-timeout-ms))
         (services (skewed--get-prop config :crew))
         (lines '()))
    
    (dolist (svc services)
      (when (skewed--get-prop svc :cyborg-passengers-allowed?)
        (let* ((name (skewed--get-prop svc :name))
               (ports (skewed--get-prop svc :hailing-frequencies))
               (http-port (skewed--get-prop
                           (cl-find-if (lambda (p) (equal (skewed--get-prop p :name) "http")) ports)
                           :aboard)))
          (push (format "[mcp_servers.%s]" name) lines)
          (push "command = \"node\"" lines)
          (let ((args (list wrapper-path "--server-name" name
                            "--backend-host" name "--http-port" (number-to-string http-port))))
            (when request-timeout
              (setq args (append args (list "--request-timeout-ms"
                                            (number-to-string request-timeout)))))
            (push (format "args = [%s]"
                          (mapconcat (lambda (arg) (format "\"%s\"" arg)) args ", "))
                  lines))
          (dolist (tool-name (skewed--mcp-approved-tools svc))
            (push "" lines)
            (push (format "[mcp_servers.%s.tools.%s__%s]"
                          name name tool-name)
                  lines)
            (push "approval_mode = \"approve\"" lines))
          (push "" lines))))
    
    (string-join (nreverse lines) "\n")))

;;; ============================================================================
;;; Services Discovery (Elisp) Generation
;;; ============================================================================

(defun skewed--generate-elisp (config)
  "Generate services-generated.el for Emacs dashboard."
  (let* ((services (skewed--get-prop config :crew))
         (lines '()))
    
    (push (format ";;; services-generated.el --- Generated from %s -*- lexical-binding: t; -*-"
                  skewed-gen-articles-filename)
          lines)
    ;; The header is EMITTED, not hand-added.  It was hand-added before
    ;; 2026-08-15 and every regeneration silently stripped it again --
    ;; harmless while regenerating was rare, not harmless now that symbolic
    ;; rosters make it routine.  It said "proprietary / trade secret" until
    ;; 2026-08-16, when basilisk got a LICENSE and the banner started
    ;; contradicting it; the emitted notice now matches the repo.
    (push "" lines)
    (push ";; Copyright © 2026 Gornskew Enterprises" lines)
    (push ";;" lines)
    (push ";; This program is free software: you can redistribute it and/or modify" lines)
    (push ";; it under the terms of the GNU Affero General Public License as" lines)
    (push ";; published by the Free Software Foundation, either version 3 of the" lines)
    (push ";; License, or (at your option) any later version.  Distributed WITHOUT" lines)
    (push ";; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>." lines)
    (push "" lines)
    (push ";;; DO NOT EDIT - Regenerate with: (skewed-generate-all-configs)" lines)
    (push "" lines)
    (push "(defvar skewed-generated-services nil)" lines)
    (push "(setq skewed-generated-services" lines)
    (push "  '(" lines)
    
    (dolist (svc services)
      (let* ((name (skewed--get-prop svc :name))
             (type (skewed--get-prop svc :type))
             (lisp-impl (skewed--lisp-impl svc))
             (mcp (skewed--get-prop svc :cyborg-passengers-allowed?))
             (ports (skewed--get-prop svc :hailing-frequencies))
             (http-port (cl-find-if (lambda (p) (equal (skewed--get-prop p :name) "http")) ports))
             (swank-port (cl-find-if (lambda (p) (equal (skewed--get-prop p :name) "swank")) ports)))
        (push (format "    (:name \"%s\"" name) lines)
        (when type
          (push (format "     :type \"%s\"" type) lines))
        (when lisp-impl
          (push (format "     :lisp-impl \"%s\"" lisp-impl) lines))
        (let ((sku (skewed--service-sku svc)))
          (when sku
            (push (format "     :sku \"%s\"" sku) lines)))
        (when mcp
          (push "     :mcp t" lines))
        (when http-port
          (push (format "     :http-host \"%s\"" name) lines)
          (push (format "     :http-port %s" (skewed--get-prop http-port :aboard)) lines)
          (when (skewed--get-prop http-port :galaxy)
            (push (format "     :http-host-port %s" (skewed--get-prop http-port :galaxy)) lines)))
        (when swank-port
          (push (format "     :swank-host \"%s\"" name) lines)
          (push (format "     :swank-port %s" (skewed--get-prop swank-port :aboard)) lines)
          (when (skewed--get-prop swank-port :galaxy)
            (push (format "     :swank-host-port %s" (skewed--get-prop swank-port :galaxy)) lines)))
        (push "    )" lines)))
    
    (push "   ))" lines)
    (push (format ";; Services configuration generated from %s." skewed-gen-articles-filename) lines)
    (push "" lines)
    (push "(provide 'services-generated)" lines)
    (push ";;; services-generated.el ends here" lines)
    
    (string-join (nreverse lines) "\n")))

;;; ============================================================================
;;; Main Entry Points
;;; ============================================================================
;;; Install Script Generation (for overlays only)
;;; ============================================================================

;; Ports generate-env.sh will arrive at on its own.  A pin equal to one of
;; these is worse than no pin: it would also defeat BASILISK_PORT_OFFSET,
;; which exists so several instances can run on one host.  Only a
;; DEVIATION from these is worth pinning.
(defconst skewed--generated-env-port-defaults
  '(("CYCLOPS_HOST_PORT" . "19069")
    ("CYCLOPS_UTILITY_HOST_PORT" . "19191"))
  "Host ports generate-env.sh writes into .env when it inherits nothing.")

(defun skewed--ingress-port-pins (config)
  "Return host.env pin lines for CONFIG's ingress, as KEY=VALUE strings.

A ship whose ingress fronts the public internet declares its own
published ports in basilisk.sexp -- sally and shelly publish :80.  That
declaration reaches compose as `${CYCLOPS_HOST_PORT:-80}', and compose
reads .env FIRST, where generate-env.sh has written the dev port unless
it inherited a value.  So the overlay's own default never gets a chance:
the ingress moves to 19069 and every property behind it goes dark.  That
is the 2026-08-16 outage, and it happened because this generator emitted
an install script that wrote only the image variant into host.env -- the
one channel ./basilisk and basilisk.service both read before generating.

The ingress is found BY PROPERTY (:type \"reverse-proxy\"), never by its
service name: the name is a posting, postings get renamed (pilot ->
transporter-chief), and a name match here would silently drop the :80
pin on the next rename -- re-running the 2026-08-16 outage with a fresh
cause.

Ports matching `skewed--generated-env-port-defaults' yield no pin, so dev
hosts stay offsettable."
  (let ((ingress (cl-find-if (lambda (svc)
                               (equal (skewed--get-prop svc :type) "reverse-proxy"))
                             (skewed--get-prop config :crew)))
        (pins '()))
    (dolist (port (skewed--get-prop ingress :hailing-frequencies))
      (let ((host (format "%s" (or (skewed--get-prop port :galaxy) ""))))
        (when (string-match "\\`\\${\\([A-Z0-9_]+\\):-\\([0-9]+\\)}\\'" host)
          (let ((var (match-string 1 host))
                (val (match-string 2 host)))
            (unless (equal val (cdr (assoc var skewed--generated-env-port-defaults)))
              (push (format "%s=%s" var val) pins))))))
    (nreverse pins)))

(defun skewed--generate-install-script (prefix &optional has-mcp variant port-pins template-files no-pull)
  "Generate install script for overlay or base repository with PREFIX.
When PREFIX is empty, generates a base install (copies docker-compose.yml).
When HAS-MCP is non-nil, include MCP config copy commands.
PORT-PINS is a list of KEY=VALUE strings (see `skewed--ingress-port-pins')
written into host.env alongside the image variant.
TEMPLATE-FILES is a list of (SRC-BASENAME . DEST-BASENAME) copied into
the basilisk clone's templates/ directory, for compose-dev to rewrite
from the crew ledger on the way up.
When NO-PULL is non-nil (the articles' :meta :no-pull?), NO_PULL=1 rides
host.env: a provisioned ship puts to sea on what is already aboard --
boot never contacts a registry, even for a missing image, and it also
outranks a stray PULL_ALWAYS.  Deploys take on stores explicitly with
`basilisk pull' / `up --pull'.
Returns the install script content as a string."
  (let ((lines '())
        (is-base (string-empty-p prefix))
        (label (if (string-empty-p prefix) "base config" 
                 (string-trim-right prefix "-"))))
    (push "#!/bin/bash" lines)
    (push "#" lines)
    (push (format "# Install script for %s" label) lines)
    (push "#" lines)
    (push "# This copies pre-generated configs into the Basilisk checkout." lines)
    (push "# Docker Compose will automatically merge the .yml files." lines)
    (push "# MCP configs are merged automatically by ./basilisk up." lines)
    (push "" lines)
    (push "set -e" lines)
    (push "" lines)
    ;; The yard moved out of skewed-emacs, so overlays install into
    ;; basilisk now.  BASILISK_DIR is overridable for the transition: a
    ;; box still running the stack from a skewed-emacs checkout can say
    ;; BASILISK_DIR=../skewed-emacs ./install without editing this
    ;; GENERATED file -- which is what hand-editing it amounts to, and
    ;; the edit is lost on the next regeneration.
    (push "SCRIPT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"" lines)
    (push "TARGET_DIR=\"${BASILISK_DIR:-$SCRIPT_DIR/../basilisk}\"" lines)
    (push "" lines)
    (push (format "echo \"Installing %s...\"" label) lines)
    (push "echo \"  from: $SCRIPT_DIR\"" lines)
    (push "echo \"  into: $TARGET_DIR\"" lines)
    (push "echo \"\"" lines)
    (push "" lines)
    (push "# Check if target directory exists" lines)
    (push "if [ ! -d \"$TARGET_DIR\" ]; then" lines)
    (push "    echo \"Error: Target directory $TARGET_DIR does not exist\"" lines)
    (push "    echo \"Clone basilisk beside this repo, or set BASILISK_DIR.\"" lines)
    (push "    exit 1" lines)
    (push "fi" lines)
    (push "" lines)

    ;; Compose file copy
    (if is-base
        (progn
          (push "# Copy base compose (replaces skewed-emacs default)" lines)
          (push "echo \"Installing docker-compose.yml (base with networks)...\"" lines)
          (push "cp \"$SCRIPT_DIR/docker-compose.yml\" \"$TARGET_DIR/docker-compose.yml\"" lines))
      (push "# Copy compose overlay" lines)
      (push (format "echo \"Installing %scompose.yml...\"" prefix) lines)
      (push (format "cp \"$SCRIPT_DIR/%scompose.yml\" \"$TARGET_DIR/\"" prefix) lines))
    (push "" lines)

    ;; MCP configs
    (when has-mcp
      (push "# Copy MCP configs" lines)
      (push "echo \"Installing MCP configs...\"" lines)
      (push "mkdir -p \"$TARGET_DIR/mcp\"" lines)
      (if is-base
          (progn
            (push "for f in \"$SCRIPT_DIR/mcp/\"*.json \"$SCRIPT_DIR/mcp/\"*.toml; do" lines)
            (push "    [ -f \"$f\" ] && cp \"$f\" \"$TARGET_DIR/mcp/\"" lines)
            (push "done" lines))
        (push (format "cp \"$SCRIPT_DIR/mcp/%smcp-container.json\" \"$TARGET_DIR/mcp/\"" prefix) lines)
        (push (format "cp \"$SCRIPT_DIR/mcp/%smcp-windows.json\" \"$TARGET_DIR/mcp/\"" prefix) lines)
        (push (format "cp \"$SCRIPT_DIR/mcp/%smcp.toml\" \"$TARGET_DIR/mcp/\"" prefix) lines))
      (push "" lines))

    ;; Services discovery
    (push "# Copy services discovery (dashboard + swank)" lines)
    ;; Services topology is YARD OUTPUT and travels in generated/, never in
    ;; the Captain's dot-files tree.
    (push "echo \"Installing services discovery...\"" lines)
    (push "mkdir -p \"$TARGET_DIR/generated\"" lines)
    (if is-base
        (progn
          (push "for f in \"$SCRIPT_DIR/generated/\"*services-generated.el; do" lines)
          (push "    [ -f \"$f\" ] && cp \"$f\" \"$TARGET_DIR/generated/\"" lines)
          (push "done" lines))
      (push "for svc_file in \"$SCRIPT_DIR/generated/\"*-services-generated.el; do" lines)
      (push "    if [ -f \"$svc_file\" ]; then" lines)
      (push "        cp \"$svc_file\" \"$TARGET_DIR/generated/\"" lines)
      (push "    fi" lines)
      (push "done" lines))
    (push "" lines)

    ;; CREW LEDGER + TEMPLATED FITTINGS.  The chief's standing orders and
    ;; the services-init hooks ride INTO the basilisk clone, so the yard
    ;; never reaches outside its own directory on the way up.  Templates
    ;; are rewritten from the ledger by compose-dev (substitute_templates)
    ;; before any container starts; the rewritten copies land in
    ;; generated/ and are what the articles mount.
    (unless is-base
      ;; The overlay ledger keeps its PREFIXED name in the clone: the
      ;; base generated/crew.env is a tracked yard output, and an
      ;; install that overwrote it left every host's clone permanently
      ;; dirty, blocking every future pull (shelly, 2026-08-17).
      ;; compose-dev layers generated/crew.env + generated/*-crew.env,
      ;; later keys winning.
      (push (format "if [ -f \"$SCRIPT_DIR/generated/%screw.env\" ]; then" prefix) lines)
      (push (format "    echo \"Installing crew ledger (generated/%screw.env)...\"" prefix) lines)
      (push "    mkdir -p \"$TARGET_DIR/generated\"" lines)
      (push (format "    cp \"$SCRIPT_DIR/generated/%screw.env\" \"$TARGET_DIR/generated/%screw.env\""
                    prefix prefix)
            lines)
      (push "fi" lines)
      (push "" lines)
      (when template-files
        (push "echo \"Installing templated fittings...\"" lines)
        (push "mkdir -p \"$TARGET_DIR/templates\"" lines)
        (dolist (tf template-files)
          (push (format "cp \"$SCRIPT_DIR/%s\" \"$TARGET_DIR/templates/%s\""
                        (car tf) (cdr tf))
                lines))
        (push "" lines)))

    ;; SYSTEMD HOST INJECTION.  There is exactly ONE Basilisk unit, and it
    ;; lives in the Basilisk clone.  Until 2026-08-15 every *-stack repo
    ;; carried its own near-identical copy of the service file, and the whole
    ;; difference between all five was the image variant plus a description
    ;; string -- five sources of truth for one value, which is how they
    ;; drift.  So a stack contributes DATA, not a unit: it writes host.env
    ;; into the Basilisk clone and basilisk/systemd/install does the rest.
    ;;
    ;; host.env carries every host pin, not just the variant: an ingress
    ;; that publishes :80 rides here too, because .env would otherwise
    ;; hand it the dev port (see `skewed--ingress-port-pins').
    (unless is-base
      (progn
        (when (or variant port-pins no-pull)
          (push "# --- systemd host injection ------------------------------------" lines)
          (push (format "echo \"Injecting systemd host.env (%s)...\""
                        (string-join
                         (append (when variant (list (format "image variant: %s" variant)))
                                 (mapcar (lambda (pin) (format "pin %s" pin)) port-pins)
                                 (when no-pull (list "no boot-time pulls")))
                         ", "))
                lines)
          (push "mkdir -p \"$TARGET_DIR/systemd\"" lines)
          (push "{" lines)
          (push (format "  echo \"# Generated by %s/install -- do not edit.\"" label) lines)
          (push "  echo \"# Read by basilisk.service via EnvironmentFile.\"" lines)
          (when variant
            (push (format "  echo \"EMACS_IMAGE_VARIANT=%s\"" variant) lines))
          (dolist (pin port-pins)
            (push (format "  echo \"%s\"" pin) lines))
          (when no-pull
            (push "  echo \"# Provisioned ship: boot never contacts a registry.\"" lines)
            (push "  echo \"NO_PULL=1\"" lines))
          (push "} > \"$TARGET_DIR/systemd/host.env\"" lines)
          (push "echo \"  wrote $TARGET_DIR/systemd/host.env\"" lines)
          (push "echo \"  install/refresh the units with: (cd $TARGET_DIR && sh systemd/install)\"" lines)
          (push "" lines))))

    (push "echo \"\"" lines)
    (push "echo \"Installation complete!\"" lines)
    (push "echo \"\"" lines)

    (string-join (nreverse lines) "\n")))

;;; ============================================================================
;;; THE DICTIONARY (glossary.sexp): a FORK's register -> the canonical keys
;;;
;;; The yard's NATIVE TONGUE is the ship register (Dave, 2026-08-17):
;;; this generator reads :crew, :hailing-frequencies, :cargo-bays,
;;; :space-suit, :cyborg-passengers-allowed? and friends directly, and
;;; only its OUTPUTS speak compliant docker/compose (and the other
;;; formats it spits out).  The canonical repo therefore ships NO
;;; glossary -- only a FORK needs one, sitting beside its articles:
;;;
;;;   :terms       fork keys -> the canonical keys this code reads,
;;;                substituted on the config immediately after reading
;;;                (the sample corporate fork's glossary will map
;;;                :services -> :crew, :ports -> :hailing-frequencies,
;;;                and so on).
;;;   :vocabulary  the strings the yard COINS when generating (the
;;;                unassigned-specimen designator, muster titles,
;;;                absence warnings).  Canon's words are the code's
;;;                defaults; a fork's glossary overrides them without
;;;                touching shipped code, via generated/vocabulary.env
;;;                for the shell half.
;;;
;;; The one structural (non-rename) translation is :provenance +
;;; :species -> :image, because docker wants the two halves reunited as
;;; one reference; see `skewed--join-species'.

(defun skewed--load-glossary (services-file)
  "The glossary.sexp beside SERVICES-FILE, as a plist, or nil.
nil -- the canonical case -- means no translation: the articles are
already in the yard's native register."
  (let ((f (expand-file-name "glossary.sexp"
                             (file-name-directory services-file))))
    (when (file-exists-p f)
      (skewed--read-sexp-file f))))

(defun skewed--glossary-terms (glossary)
  "GLOSSARY's :terms section; a legacy flat glossary IS its terms."
  (and glossary (or (plist-get glossary :terms) glossary)))

(defun skewed--glossary-vocab (glossary key)
  "The :vocabulary entry KEY from GLOSSARY, or nil.
Vocabulary is the dictionary's other half: strings the yard COINS when
generating, rather than keys it renames.  A fork's glossary overrides
the canonical words without touching shipped code; nil falls back to
the canon default at each use site."
  (plist-get (plist-get glossary :vocabulary) key))

(defun skewed--translate-register (glossary-or-form &optional glossary)
  "Substitute every keyword in a form that GLOSSARY's terms map.
Called as (skewed--translate-register FORM GLOSSARY).  Terms are a
flat plist (FORK-TERM CANONICAL-KEY ...).  Substitution is
position-blind -- any keyword anywhere in the tree -- which is why the
glossary contract says its terms may be used only as KEYS in the
articles, never as values."
  (let ((form glossary-or-form)
        (terms (skewed--glossary-terms glossary)))
    (if (null terms) form
      (cl-labels ((walk (f)
                    (cond ((keywordp f) (or (plist-get terms f) f))
                          ((consp f) (cons (walk (car f)) (walk (cdr f))))
                          (t f))))
        (walk form)))))

(defun skewed--join-species (config)
  "Fold each service's :provenance + :species pair into docker's :image.
Species is the image type, repo:tag; provenance is the registry and/or
namespace it hails from -- its home planet, stripped from the species
and reattached only here, where docker insists on one reference.  A
service already carrying :image passes through untouched."
  (dolist (svc (skewed--get-prop config :crew))
    (let ((species (plist-get svc :species))
          (provenance (plist-get svc :provenance)))
      (when (and species (not (plist-get svc :image)))
        (plist-put svc :image
                   (if provenance (concat provenance "/" species) species)))))
  config)

(defun skewed--species-repo (species)
  "The repo half of SPECIES: \"redis:7\" -> \"redis\".
Env expansions resolve to their defaults first; any namespace that
rode along in the string is dropped."
  (let* ((s (skewed--resolve-compose-defaults (or species "")))
         (repo (if (string-match "\\`\\([^:]*\\):" s) (match-string 1 s) s)))
    (file-name-nondirectory repo)))

(defun skewed--service-sku (svc)
  "A short display sku for SVC: the species repo, plus the
implementation half of the tag when it carries one
(gendl:devo-ccl -> gendl-ccl; readymax:devo-full -> readymax).  An
articles-level :sku-label on the crew entry overrides -- how a
register fork labels a room whose image still ships under the
upstream sku (a basalt console flying readymax shows readymacs).
Surfaced as :sku in services-generated.el for the dashboard's
backend listings."
  (or (plist-get svc :sku-label)
      (let* ((species (skewed--resolve-compose-defaults
                       (or (plist-get svc :species) (plist-get svc :image) "")))
             (bare (file-name-nondirectory species))
             (repo (if (string-match "\\`\\([^:]*\\):" bare) (match-string 1 bare) bare))
             (tag (and (string-match ":\\(.*\\)\\'" bare) (match-string 1 bare)))
             (impl (and tag (string-match "-\\([a-z0-9]+\\)\\'" tag)
                        (match-string 1 tag))))
        (if (and impl (member impl '("ccl" "sbcl" "acl" "clasp" "ecl"
                                     "abcl" "clisp" "cmucl")))
            (concat repo "-" impl)
          (unless (string-empty-p repo) repo)))))

(defun skewed--derive-names (config &optional glossary)
  "Fill in each crew entry's :name where the articles left it out.
Only :species is required of a service.  An explicit :name wins -- it
is the author's slug, and the license to abbreviate lives there.
Absent one, ROOMS TAKE TYPE SLUGS (ruling 2026-08-23): an entry
declaring its :module takes the slug of its module type -- the
service key, hostname and in-network hail are all the room's plain
type (ready-room, bridge, guild-workshop), while the CONTAINER name
carries the resident's minted personal name via the muster (see the
container_name emission).  An entry with no :module falls back to the
slug of every post it stands (full post names, hyphen-joined; no post
is primary); a species aboard with NO assigned posting takes a
designator prefix on the repo half of its species, so one is obvious
from its slug alone.  The designator is \"stowaway\" -- the yard's
native word -- unless a fork's glossary :vocabulary overrides it
(:stowaway-designator), which changes it without touching shipped
code.  Collisions get -2, -3 ... suffixes: a hull with two guild
workshops carries guild-workshop and guild-workshop-2, in declaration
order."
  (let ((taken (delq nil (mapcar (lambda (s) (plist-get s :name))
                                 (skewed--get-prop config :crew))))
        (designator (or (skewed--glossary-vocab glossary :stowaway-designator)
                        "stowaway")))
    (dolist (svc (skewed--get-prop config :crew))
      (unless (plist-get svc :name)
        (let* ((module (plist-get svc :module))
               (posts (skewed--ensure-list (plist-get svc :post)))
               (stem (cond (module module)
                           (posts
                            (mapconcat (lambda (p) (substring (symbol-name p) 1))
                                       posts "-"))
                           (t
                            (let ((repo (skewed--species-repo
                                         (plist-get svc :species))))
                              (if (string-empty-p repo) ""
                                (concat designator "-" repo))))))
               (name stem)
               (n 1))
          (when (string-empty-p stem)
            (error "Crew entry with no :name, no :module, no :post and no :species -- nothing to derive a name from"))
          (while (member name taken)
            (setq n (1+ n) name (format "%s-%d" stem n)))
          (push name taken)
          (plist-put svc :name name)))))
  config)

(defun skewed--crew-env-name (name)
  "The muster variable for service NAME: BASILISK_CREW_<NAME sanitized>.
Its value is the resident's minted personal name; compose interpolates
it into container_name.  Minting and persistence live in compose-dev's
muster_crew, keyed by these same names."
  (concat "BASILISK_CREW_"
          (upcase (replace-regexp-in-string "[^A-Za-z0-9]" "_" name))))

(defun skewed--read-articles (services-file)
  "Read SERVICES-FILE translated through its own glossary, species
joined, missing names derived.  Every consumer sees the same names."
  (let ((config (skewed--read-sexp-file services-file))
        (glossary (skewed--load-glossary services-file)))
    (when config
      (skewed--derive-names
       (skewed--join-species
        (skewed--translate-register config glossary))
       glossary))))

;;; THE CREW LEDGER (crew.env): posting -> his room, and his ports.
;;;
;;; ROUTINGS NAME A ROOM AND A CREW MEMBER (ruling 2026-08-24):
;;; containers are ROOMS, and the services answering on ports inside
;;; are the CREW.  A rule in a templated fitting (templates/,
;;; substituted by compose-dev on the way up) therefore states both
;;; halves by lookup: ${BASILISK_POST_FIRST_OFFICER_ROOM} resolves to
;;; the room where :first-officer stands (the container hostname),
;;; and ${BASILISK_POST_FIRST_OFFICER_HTTP_PORT} to the aboard port
;;; his http frequency answers on -- "the captain in the ready room"
;;; is port 7080 in the skewed-emacs room.  The articles'
;;; hailing-frequencies are the single source of truth for every
;;; port: fittings look ports up, never restate them.  So the chief's
;;; standing orders survive renames and reliefs untouched.  ONE hand
;;; per posting for now: the first declared wins (base order, then
;;; overlay additions); ships with several of a posting are a known
;;; limitation, deliberately unhandled until the simple case has
;;; sailed.  (The bare ${BASILISK_POST_<P>} key, which yielded the
;;; room under a crew-sounding name, retired with this ruling.)

(defun skewed--posting-env-name (post)
  "BASILISK_POST_<POSTING> environment name for POST keyword."
  (concat "BASILISK_POST_"
          (upcase (replace-regexp-in-string
                   "-" "_" (substring (symbol-name post) 1)))))

(defun skewed--generate-crew-env (crew)
  "KEY=VALUE lines resolving each posting to its first-declared hand.
CREW is the ship's full merged complement.

Besides the posting rows, the ledger carries a MODULE stanza: one
_NAME/_SPECIES pair per room aboard, which is what compose-dev's
muster_crew iterates to mint each room's resident a personal name
(species-flavored pools) before the vat runs.  The species is emitted
with compose defaults resolved -- close enough for name flavor, which
keys on the repo half and broad tag features."
  (let ((seen '()) (lines '()))
    (dolist (svc crew)
      (dolist (p (skewed--ensure-list (plist-get svc :post)))
        (unless (memq p seen)
          (push p seen)
          (let ((base (skewed--posting-env-name p)))
            (push (format "%s_ROOM=%s" base (plist-get svc :name)) lines)
            (dolist (f (plist-get svc :hailing-frequencies))
              (let ((fname (plist-get f :name))
                    (port (plist-get f :aboard)))
                (when (and fname port)
                  (push (format "%s_%s_PORT=%s" base
                                (upcase (replace-regexp-in-string
                                         "-" "_" fname))
                                port)
                        lines))))))))
    ;; The module stanza: every room aboard, for the muster's minting.
    (dolist (svc crew)
      (let* ((name (plist-get svc :name))
             (san (upcase (replace-regexp-in-string "[^A-Za-z0-9]" "_" name)))
             (image (skewed--resolve-compose-defaults
                     (or (plist-get svc :image) ""))))
        (when name
          (push (format "BASILISK_MOD_%s_NAME=%s" san name) lines)
          (push (format "BASILISK_MOD_%s_SPECIES=%s" san image) lines))))
    (mapconcat #'identity (nreverse lines) "\n")))

(defun skewed--generate-vocabulary-env (glossary)
  "KEY='VALUE' lines for the shell half of a FORK's dictionary.
compose-dev speaks the canonical register natively; when a fork's
GLOSSARY carries :vocabulary, this generated file is how the shell
learns the fork's words instead -- changeable by editing the fork's
glossary alone, never shipped basilisk code."
  (let ((vocab (plist-get glossary :vocabulary))
        (lines '()))
    (push "# DO NOT EDIT - Generated from glossary.sexp :vocabulary" lines)
    (push "# Sourced by compose-dev.  Register vocabulary lives in the" lines)
    (push "# glossary, never in shipped code." lines)
    (cl-flet* ((posix-name (sym &optional prefix)
                 ;; Hyphens become underscores: :first-officer must emit
                 ;; a legal POSIX name (BASILISK_VOCAB_TITLE_FIRST_OFFICER),
                 ;; or sourcing vocabulary.env fails at up-time.
                 (format "BASILISK_VOCAB_%s%s" (or prefix "")
                         (upcase (replace-regexp-in-string
                                  "-" "_" (substring (symbol-name sym) 1)))))
               (emit (key val)
                 (when val
                   (push (format "%s='%s'" key
                                 (replace-regexp-in-string "'" "'\\\\''" val))
                         lines))))
      ;; GENERIC EMISSION: every string-valued key in :vocabulary
      ;; becomes BASILISK_VOCAB_<KEY> -- adding a coined string to the
      ;; shell needs only a ${BASILISK_VOCAB_X:-canon default} there
      ;; and a :x entry in the fork's glossary, never another emitter
      ;; edit.  Values may be printf format strings (%s slots); the
      ;; shell side prints them with printf.  :muster-titles is the
      ;; one structured entry, flattened to TITLE_<POSTING> keys.
      (cl-loop for (key val) on vocab by #'cddr
               do (cond ((eq key :muster-titles)
                         (cl-loop for (role title) on val by #'cddr
                                  do (emit (posix-name role "TITLE_") title)))
                        ((stringp val)
                         (emit (posix-name key) val)))))
    (concat (string-join (nreverse lines) "\n") "\n")))

(defun skewed--filter-berthed (config &optional base-names)
  "Withhold VACANT postings from emission; everything else passes.
A crew entry with no :image is one of two things: a DEVIATION on a
post the base articles already berth (its :name is in BASE-NAMES --
emitted as the sparse overlay it is, compose merges it key-wise), or a
VACANT posting -- stated on the books (its :post, :description and
:requires all stand) but invisible to the machinery until a species
that meets its requirements signs on.  Each vacancy is said out loud
once per generation."
  (let* ((all (skewed--get-prop config :crew))
         (aboard-p (lambda (svc) (or (plist-get svc :image)
                                     (member (plist-get svc :name) base-names))))
         (berthed (seq-filter aboard-p all)))
    (dolist (svc all)
      (unless (funcall aboard-p svc)
        (message "  Note: posting %s is stated but VACANT (no species assigned) -- nothing emitted"
                 (or (plist-get svc :post) (plist-get svc :name)))))
    (let ((out (copy-sequence config)))
      (plist-put out :crew berthed))))

(defun skewed--ensure-list (x)
  "X if it is a list, else (X).  :post accepts one keyword or several."
  (if (listp x) x (list x)))

(defun skewed--posting-requires (post tables)
  "The :requires of POST per the first of TABLES that defines it.
Each table is a :postings list -- the posting qualifications: what a
species must be capable of to stand that post.  Requirements only;
this is deliberately NOT a fitting catalogue (no service definitions,
no rosters)."
  (catch 'found
    (dolist (table tables)
      (let ((entry (seq-find (lambda (e) (eq (plist-get e :post) post))
                             table)))
        (when entry (throw 'found (plist-get entry :requires)))))))

(defun skewed--resolve-post-requires (config base-config)
  "Union each crew entry's :requires with those of every post it stands.
:post may be a single keyword or a LIST -- one crew member can stand
several posts (narad's First Officer also stands
:communications-officer, the ability arriving with his services-init
hook at boot or later, not with his species).  Per-post requirements
come from the :postings qualification tables -- this file's own, then
the base articles' -- e.g. :ships-engineer requires \"gendl\",
:guild-engineer requires \"genworks-gdl\".  The muster's manifest
check stays WARNING severity, so a capability that arrives by
arrangement rather than manifest costs a warning and nothing more."
  (let ((tables (delq nil (list (skewed--get-prop config :postings)
                                (and base-config
                                     (skewed--get-prop base-config :postings))))))
    (dolist (svc (skewed--get-prop config :crew))
      (let ((reqs (copy-sequence (plist-get svc :requires))))
        (dolist (p (skewed--ensure-list (plist-get svc :post)))
          (dolist (r (skewed--posting-requires p tables))
            (unless (member r reqs)
              (setq reqs (append reqs (list r))))))
        (when reqs (plist-put svc :requires reqs)))))
  config)

(defun skewed--apply-relieves (config base-config)
  "Resolve :relieves entries: a renamed crew member takes over a base post.
A crew entry naming :relieves \"<base-name>\" is the base entry merged
under the NEW name (its own keys winning), so the articles state only
the deviation.  The relieved base name becomes a NETWORK ALIAS of the
new container -- everyone who hails the old name (cyclops backends,
MCP configs, SLIME) still reaches the same crew member -- and the base
service itself is suppressed via an emitted profiles stub (collected
in :relieved-names) so it does not also come up."
  (let ((base-services (and base-config
                            (skewed--get-prop base-config :crew)))
        (relieved '()))
    (let ((services
           (mapcar
            (lambda (svc)
              (let ((victim (plist-get svc :relieves)))
                (if (not victim)
                    svc
                  (let ((base (seq-find (lambda (b) (equal (plist-get b :name)
                                                           victim))
                                        base-services)))
                    (unless base
                      (error ":relieves %S names no base crew member" victim))
                    (push victim relieved)
                    (let ((merged (skewed--merge-service base svc)))
                      (setq merged (plist-put merged :network-alias victim))
                      ;; :relieves itself is bookkeeping, not config.
                      (plist-put merged :relieves nil)
                      merged)))))
            (skewed--get-prop config :crew))))
      (let ((out (copy-sequence config)))
        (setq out (plist-put out :crew services))
        (plist-put out :relieved-names (nreverse relieved))))))

(defun skewed--resolve-compose-defaults (s)
  "Resolve ${VAR:-default} to default and ${VAR} to \"\" in S.
Good enough for image references, which never nest expansions."
  (let ((out (replace-regexp-in-string
              "\\${[A-Za-z0-9_]+:-\\([^}]*\\)}" "\\1" (or s ""))))
    (replace-regexp-in-string "\\${[A-Za-z0-9_]+}" "" out)))

(defun skewed--lisp-impl (svc)
  "SVC's lisp implementation: declared if present, else derived.
Derived from the species -- the strain (tag half) names the engine
\(devo-ccl, devo-sbcl, devo-enterprise-smp-licensed), so a declared
copy could only ever disagree with the image it describes.  Same
argument that removed the :species label (2026-08-17).  An overlay may
still declare :lisp-impl for a species whose strain says nothing.
Order matters below: non-smp must precede smp, which would otherwise
swallow it."
  (or (skewed--get-prop svc :lisp-impl)
      (let* ((image (skewed--resolve-compose-defaults
                     (or (skewed--get-prop svc :image) "")))
             (tag (if (string-match ":\\([^:/]+\\)\\'" image)
                      (match-string 1 image) ""))
             (type (skewed--get-prop svc :type)))
        (cond ((equal type "emacs-lisp") "Emacs")
              ((string-match-p "non-smp" tag) "AllegroCL-Enterprise")
              ((string-match-p "smp" tag) "AllegroCL-SMP-Enterprise")
              ((string-match-p "ccl" tag) "CCL")
              ((string-match-p "sbcl" tag) "SBCL")
              ((equal type "reverse-proxy") "AllegroCL-Runtime")))))

(defvar skewed-gen-base-articles
  (let ((beside (expand-file-name skewed-gen-articles-filename
                                  skewed-gen-yard-dir)))
    (if (file-exists-p beside) beside "/projects/basilisk/basilisk.sexp"))
  "The base ship's articles: the crew aboard every Basilisk-class ship.
Board probe generation reads these alongside each watched stack's own
overlay, because an overlay declares only its deviation -- the Captain
whose heap a board watches is defined here, not in sally-stack.
Resolved at LOAD TIME beside this file, for the same
two-copies-of-the-yard reason the old fittings path was (see git
history); setq it after loading to point elsewhere.")

(defun skewed--merge-service (base over)
  "Merge service plist OVER onto BASE; OVER's keys win."
  (let ((out (copy-sequence base)))
    (cl-loop for (k v) on over by #'cddr do (setq out (plist-put out k v)))
    out))

;;; EYES ONLY QUARTERS PROBES FROM THE ARTICLES (2026-08-15, reworked
;;; 2026-08-17; register overhaul 2026-09-01)
;;;
;;; The articles are the SSoT for who is aboard, so they are also the
;;; authority on what can be PROBED.  eyes-only's probe list was
;;; hand-maintained per board, which meant a probe could name a crew
;;; member who was never aboard the ship it points at -- and an absent
;;; optional post then presents as a permanently red tile rather than as
;;; nothing at all.  That is exactly shelly's 2026-08-14 symptom.
;;; Deriving the list from each ship's actual crew makes the failure
;;; impossible: no post, no probe, no tile.
;;;
;;; A :probe rides ON the crew entry that publishes it (the fitting
;;; catalogue that used to group these by post retired 2026-08-17).  A
;;; watched ship's crew is its base articles merged with its own overlay
;;; articles, overlay keys winning -- the same key-wise discipline
;;; compose applies to the generated yml.
;;;
;;; Tile grammar (2026-09-01): tiles name QUARTERS -- the room-type
;;; slug plus the galaxy the ship floats in, "<module> <stack>"
;;; ("bridge balaram"), emitted into eyes-only::*quarters-probes*.
;;; The room slug comes straight from the crew entry's :module, so
;;; the old hand-maintained :probe :tile field is retired; the
;;; resident's minted name, sku, and postings are HARVESTED live by
;;; the board (metrics self-reports + the muster roll), never baked
;;; into config.  Tile keys stay stable across raisings by design --
;;; every raising is a new ship, and the board's telemetry history
;;; must survive a relief.

(defun skewed--stack-crew (stack-dir)
  "The full crew of the ship at STACK-DIR: base articles + its overlay.
Overlay entries restating a base :name merge key-wise over the base
entry (so a deviation cannot silently shed the base's :probe).  NIL
when no articles are found at STACK-DIR."
  (let* ((over-file (expand-file-name skewed-gen-articles-filename stack-dir))
         (over-config (and (file-exists-p over-file)
                           (skewed--read-articles over-file)))
         (over (and over-config (skewed--get-prop over-config :crew)))
         (base-config (skewed--read-articles skewed-gen-base-articles))
         (base (and base-config (skewed--get-prop base-config :crew)))
         (out '()))
    (when over-config
      (dolist (svc base)
        (let ((dev (seq-find (lambda (o) (equal (plist-get o :name)
                                                (plist-get svc :name)))
                             over)))
          (push (if dev (skewed--merge-service svc dev) svc) out)))
      (setq out (nreverse out))
      (dolist (o over)
        (unless (seq-find (lambda (svc) (equal (plist-get svc :name)
                                               (plist-get o :name)))
                          out)
          (setq out (append out (list o)))))
      out)))

(defun skewed--heap-probe-entries (config dir)
  "Build the eyes-only *quarters-probes* list for the board declared
in CONFIG.  Tiles are \"<module> <stack>\" -- the quarters' room slug
plus the galaxy.  Returns nil unless CONFIG's :meta carries an
:eyes-only-board.

Each watch entry names a :stack and either :in-stack t (this board's own
ship, sampled over the docker bridge) or an :edge URL prefix reaching that
ship's token-gated metrics.  An optional :watch narrows which posts this
board cares about; it can never widen past what the target's crew
actually carries, which is the guarantee that kills phantom tiles."
  (let* ((meta (skewed--get-prop config :meta))
         (board (plist-get meta :eyes-only-board)))
    (when board
      (let ((root (file-name-directory (directory-file-name dir)))
            (out '()))
        (dolist (w board)
          (let* ((stack (plist-get w :stack))
                 (in-stack (plist-get w :in-stack))
                 (edge (plist-get w :edge))
                 (watch (plist-get w :watch))
                 (sdir (expand-file-name (concat stack "-stack/") root))
                 (crew (skewed--stack-crew sdir)))
            (unless crew
              (error "Board watches %s, but no articles found at %s"
                     stack sdir))
            (dolist (svc crew)
              (let* ((posts (skewed--ensure-list (plist-get svc :post)))
                     (probe (plist-get svc :probe))
                     ;; A probe with no :in-stack form contributes nothing
                     ;; to its own board -- the board self-samples its own
                     ;; image (it rides its ship's bridge, the pocket
                     ;; viewscreen).
                     (spec (and probe (if in-stack
                                          (plist-get probe :in-stack)
                                        (plist-get probe :remote)))))
                (when (and spec (or (null watch)
                                    (seq-some (lambda (p) (memq p watch))
                                              posts)))
                  (unless (or in-stack edge)
                    (error "Board watch for %s is off-ship but declares no :edge"
                           stack))
                  ;; The tile's room slug is the entry's RESOLVED
                  ;; :name (skewed--derive-names): the room-type slug
                  ;; with collision suffixes, the same key the muster
                  ;; uses -- so \"guild-workshop-2 balaram\" and
                  ;; BASILISK_CREW_GUILD_WORKSHOP_2 agree, and the
                  ;; board's muster harvest lands on the same tile.
                  (unless (plist-get svc :name)
                    (error "Crew entry %s carries a :probe but no resolvable name"
                           (plist-get svc :post)))
                  (push (list (format "%s %s" (plist-get svc :name) stack)
                              (plist-get spec :kind)
                              (or (plist-get spec :url)
                                  (concat edge (plist-get spec :path)))
                              (plist-get spec :alert-mb))
                        out))))
            (dolist (post watch)
              (unless (seq-find (lambda (svc)
                                  (memq post (skewed--ensure-list
                                              (plist-get svc :post))))
                                crew)
                (message "  Note (%s): board asks for %s, which is not aboard -- no probe emitted"
                         stack post)))))
        (nreverse out)))))

(defun skewed--generate-quarters-probes-file (config dir)
  "Write eyes-only-probes-generated.lisp for a board stack, if it is one."
  (let ((probes (skewed--heap-probe-entries config dir)))
    (when probes
      (let ((file (expand-file-name "eyes-only-probes-generated.lisp" dir)))
        (with-temp-file file
          (insert ";;; eyes-only-probes-generated.lisp -*- mode: lisp -*-\n")
          (insert ";;; DO NOT EDIT -- generated from the fleet's Basilisk articles by\n")
          (insert ";;; basilisk/generate-configs.el.  Regenerate with:\n")
          (insert (format ";;;   (skewed-generate-configs \"%s\")\n" dir))
          (insert ";;;\n")
          (insert ";;; Every entry here corresponds to a post actually aboard the target\n")
          (insert ";;; ship, so a crew member who is not aboard cannot show up\n")
          (insert ";;; as a permanently red tile.  Tiles name QUARTERS -- the room\n")
          (insert ";;; slug plus the galaxy (\"bridge balaram\"); the resident's minted\n")
          (insert ";;; name, sku, and postings are harvested live by the board, never\n")
          (insert ";;; baked in here.  Change the fleet by editing the\n")
          (insert (format ";;; ships' articles, or this board's :eyes-only-board, in %s.\n\n"
                          skewed-gen-articles-filename))
          (insert "(in-package :gdl-user)\n\n")
          (insert "(setq eyes-only::*quarters-probes*\n      '(")
          (let ((first t))
            (dolist (p probes)
              (if first (setq first nil) (insert "\n        "))
              (insert (format "(%S %s %S %d)"
                              (nth 0 p) (nth 1 p) (nth 2 p) (nth 3 p)))))
          (insert "))\n"))
        (message "Generated: %s (%d probe(s))" file (length probes))
        probes))))

;;; ============================================================================

(defun skewed-generate-configs (&optional dir services-file prefix)
  "Generate all configs for directory DIR using SERVICES-FILE.

Generated files:
  - Compose YAML (docker-compose.yml or PREFIX-compose.yml)
  - MCP configs (container, windows, codex)
  - Emacs services discovery
  - Install script (for overlays only, when prefix is non-empty)  SERVICES-FILE - Path to basilisk.sexp (default: \"basilisk.sexp\" in DIR)
  PREFIX        - Output filename prefix (default: auto-derived from DIR basename)
                  Auto-derived: empty for 'skewed-emacs', 'basename-' for others

Examples:
  (skewed-generate-configs)                          ; Current dir, basilisk.sexp
  (skewed-generate-configs \"/projects/betatest/\")   ; Betatest dir, auto-prefix
  (skewed-generate-configs nil \"/tmp/custom.sexp\") ; Current dir, custom file
  (skewed-generate-configs \"/tmp/foo/\" nil \"bar-\") ; Foo dir, override prefix"
  (let* ((skewed-gen-output-dir (expand-file-name (or dir default-directory)))
         (default-services-file (expand-file-name skewed-gen-articles-filename
                                                  skewed-gen-output-dir))
         (skewed-gen-input-file (expand-file-name (or services-file default-services-file)))
         ;; Auto-derive prefix from directory name if not provided
         ;; The BASE stack generates unprefixed (docker-compose.yml); host
         ;; overlays get "<host>-".  A yard recognizes ITS OWN directory
         ;; name as a base -- a register fork renames the repo and the
         ;; yard follows, zero code edits -- and "skewed-emacs" stays a
         ;; base name for the duration of the move, and outlives it.
         (auto-prefix (let ((basename (file-name-nondirectory
                                       (directory-file-name skewed-gen-output-dir))))
                        (if (member basename
                                    (list (file-name-nondirectory
                                           (directory-file-name skewed-gen-yard-dir))
                                          "skewed-emacs"))
                            ""
                          (concat basename "-"))))
         (skewed-gen-output-prefix (if prefix prefix auto-prefix))
         ;; Read through the register dictionary: the articles may be in
         ;; the ship register (glossary.sexp beside them), and everything
         ;; downstream sees machinery keys either way.  Then: per-post
         ;; requirements resolved from the :postings qualification
         ;; tables, :relieves entries merged over their base crew
         ;; members, and vacant postings (stated, no species, not a
         ;; deviation on a base post) noted and withheld.
         (config (let* ((raw (or (skewed--read-articles skewed-gen-input-file)
                                 (let* ((dir (file-name-directory
                                              skewed-gen-input-file))
                                        (foreign
                                         (mapcar #'file-name-nondirectory
                                                 (cl-remove-if
                                                  (lambda (f)
                                                    (member (file-name-nondirectory f)
                                                            (list skewed-gen-articles-filename
                                                                  "glossary.sexp")))
                                                  (directory-files dir t "\\.sexp\\'")))))
                                   (error "Could not read the ship's articles: %s (this yard reads %s, no other name%s)"
                                          skewed-gen-input-file
                                          skewed-gen-articles-filename
                                          (if foreign
                                              (format "; found %s -- articles named for another yard are not read; rename to %s to sign them over"
                                                      (string-join foreign ", ")
                                                      skewed-gen-articles-filename)
                                            "")))))
                        (base-p (string= (expand-file-name skewed-gen-input-file)
                                         (expand-file-name skewed-gen-base-articles)))
                        (base-config (unless base-p
                                       (skewed--read-articles
                                        skewed-gen-base-articles)))
                        (base-names (mapcar (lambda (s) (plist-get s :name))
                                            (skewed--get-prop base-config :crew))))
                   ;; An overlay against no readable base must not quietly
                   ;; compose baseless: postings would resolve against
                   ;; nothing and :relieves would merge over nobody.
                   (when (and (not base-p) (null base-config))
                     (error "Could not read the base ship's articles: %s (this yard reads %s, no other name)"
                            skewed-gen-base-articles
                            skewed-gen-articles-filename))
                   (skewed--filter-berthed
                    (skewed--apply-relieves
                     (skewed--resolve-post-requires raw base-config)
                     base-config)
                    base-names)))
         (mcp-dir (expand-file-name "mcp/" skewed-gen-output-dir))
         (elisp-dir (expand-file-name "dot-files/emacs.d/etc/" skewed-gen-output-dir)))
    
    (unless config
      (error "The ship's articles at %s read as empty" skewed-gen-input-file))
    
    ;; Ensure directories exist
    (make-directory mcp-dir t)
    (make-directory elisp-dir t)
    
    ;; Generate docker-compose.yml (or overlay yml)
    (let* ((compose-name (if (string-empty-p skewed-gen-output-prefix)
                             "docker-compose.yml"
                           (format "%scompose.yml" skewed-gen-output-prefix)))
           (compose-file (expand-file-name compose-name skewed-gen-output-dir)))
      (with-temp-file compose-file
        (insert (skewed--generate-compose-yaml config)))
      (message "Generated: %s" compose-file))

    ;; The shell's share of a FORK's dictionary (base generation only):
    ;; compose-dev speaks the canonical words natively and sources this
    ;; file, when a glossary emits one, to speak the fork's instead.
    ;; Canon ships no glossary, so canon emits no vocabulary.env.
    (when (string-empty-p skewed-gen-output-prefix)
      (let ((glossary (skewed--load-glossary skewed-gen-input-file))
            (vocab-file (expand-file-name "generated/vocabulary.env"
                                          skewed-gen-output-dir)))
        (when (plist-get glossary :vocabulary)
          (make-directory (file-name-directory vocab-file) t)
          (with-temp-file vocab-file
            (insert (skewed--generate-vocabulary-env glossary)))
          (message "Generated: %s" vocab-file))))

    ;; The crew ledger: the ship's FULL merged complement (base
    ;; articles + this overlay), so a template can name any posting
    ;; aboard regardless of which articles signed the hand on.
    (let ((ledger-crew (skewed--stack-crew skewed-gen-output-dir)))
      (when ledger-crew
        (let ((crew-env (expand-file-name
                         (format "generated/%screw.env" skewed-gen-output-prefix)
                         skewed-gen-output-dir)))
          (make-directory (file-name-directory crew-env) t)
          (with-temp-file crew-env
            (insert (format "# DO NOT EDIT - Generated from %s\n" skewed-gen-articles-filename)
                    "# The crew ledger: posting -> his room (_ROOM) and his aboard ports (_<FREQ>_PORT).\n"
                    "# Routings name a room and a crew member; the articles' hailing-frequencies\n"
                    "# are the single source of truth for ports.\n"
                    "# Consumed by compose-dev's substitute_templates on the way up.\n"
                    (skewed--generate-crew-env ledger-crew)
                    "\n"))
          (message "Generated: %s" crew-env))))
    
    ;; Generate MCP configs (only when services declare :mcp t)
    (when (skewed--has-mcp-services-p config)
      (make-directory mcp-dir t)
      (let ((container-json (expand-file-name 
                             (format "%smcp-container.json" skewed-gen-output-prefix) mcp-dir)))
        (with-temp-file container-json
          (insert (format "// DO NOT EDIT - Generated from %s\n" skewed-gen-articles-filename))
          (insert (skewed--generate-mcp-json-container config)))
        (message "Generated: %s" container-json))
    
      (let ((windows-json (expand-file-name 
                           (format "%smcp-windows.json" skewed-gen-output-prefix) mcp-dir)))
        (with-temp-file windows-json
          (insert (format "// DO NOT EDIT - Generated from %s\n" skewed-gen-articles-filename))
          (insert "// For Windows: merge with base config or copy to %APPDATA%\\Claude\\\n")
          (insert (skewed--generate-mcp-json-windows config)))
        (message "Generated: %s" windows-json))
    
      (let ((codex-toml (expand-file-name 
                         (format "%smcp.toml" skewed-gen-output-prefix) mcp-dir)))
        (with-temp-file codex-toml
          (insert "# Copyright © 2026 Gornskew Enterprises\n")
          (insert "#\n")
          (insert "# This program is free software: you can redistribute it and/or modify\n")
          (insert "# it under the terms of the GNU Affero General Public License as\n")
          (insert "# published by the Free Software Foundation, either version 3 of the\n")
          (insert "# License, or (at your option) any later version.  Distributed WITHOUT\n")
          (insert "# ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.\n\n")
          (insert (format "# DO NOT EDIT - Generated from %s\n\n" skewed-gen-articles-filename))
          (insert (skewed--generate-mcp-toml config)))
        (message "Generated: %s" codex-toml))
    ) ;; end when has-mcp-services

    ;; Generate Elisp services file (base or overlay, using prefix).
    ;;
    ;; Lands in generated/ ONLY.  This is yard output: it describes what the
    ;; stack composes to, is derived entirely from basilisk.sexp, and has no
    ;; business in dot-files/, which is the Captain's Emacs configuration and
    ;; belongs to the skewed-emacs repo.  Keeping the two apart is what let
    ;; the stack machinery be lifted out of that repo cleanly.
    ;;
    ;; It reaches a running container by compose-dev copying it in; the
    ;; consumer, services-discovery.el, is unchanged and still reads it from
    ;; the container's own dot-files tree.
    (let* ((elisp-name (if (string-empty-p skewed-gen-output-prefix)
                           "services-generated.el"
                         (format "%sservices-generated.el" skewed-gen-output-prefix)))
           (generated-dir (expand-file-name "generated/" skewed-gen-output-dir))
           (elisp-file (expand-file-name elisp-name generated-dir)))
      (make-directory generated-dir t)
      (with-temp-file elisp-file
        (insert (skewed--generate-elisp config)))
      (message "Generated: %s" elisp-file))

    ;; Generate install script -- for host OVERLAYS only.  A base repo is
    ;; the thing you run the stack FROM, not something you install into
    ;; another checkout, so the yard's own directory -- whatever a fork
    ;; named it -- is excluded alongside skewed-emacs.
    (unless (member (file-name-nondirectory (directory-file-name skewed-gen-output-dir))
                    (list (file-name-nondirectory
                           (directory-file-name skewed-gen-yard-dir))
                          "skewed-emacs"))
      (let ((install-file (expand-file-name "install" skewed-gen-output-dir))
            ;; Templated fittings this stack carries: the chief's
            ;; standing orders (any cyclops-*.sexp, installed under
            ;; the register-neutral name cyclops.sexp) and the
            ;; services-init hooks.  They ride into basilisk/templates/
            ;; so the yard never reaches outside its own directory on
            ;; the way up.
            (template-files
             (append
              (mapcar (lambda (f) (cons f "cyclops.sexp"))
                      (directory-files skewed-gen-output-dir nil
                                       "\\`cyclops-.*\\.sexp\\'"))
              (mapcar (lambda (f) (cons f f))
                      (directory-files skewed-gen-output-dir nil
                                       "-services-init\\.cl\\'")))))
        (with-temp-file install-file
          (insert (skewed--generate-install-script
                   skewed-gen-output-prefix
                   (skewed--has-mcp-services-p config)
                   (plist-get (skewed--get-prop config :meta) :strain)
                   (skewed--ingress-port-pins config)
                   template-files
                   (plist-get (skewed--get-prop config :meta) :no-pull?))))
        (set-file-modes install-file #o755)
        (message "Generated: %s" install-file)))

    ;; Eyes Only heap probes, for a stack that declares itself a board.
    ;; Reads the OTHER ships' rosters, so it runs last.
    (skewed--generate-quarters-probes-file config skewed-gen-output-dir)

    (message "=== Generation complete ===")))

(defun skewed-generate-all-configs ()
  "Generate all configs from basilisk.sexp in current directory.
This is a convenience wrapper around skewed-generate-configs.
Automatically derives prefix from directory basename (empty for 'skewed-emacs').

For more control, use skewed-generate-configs directly."
  (interactive)
  (skewed-generate-configs))

(provide 'generate-configs)
;;; generate-configs.el ends here
