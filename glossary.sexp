;;; glossary.sexp - the Basalt register dictionary
;;; -*- mode: lisp-data; -*-

;; Copyright © 2026 Genworks International
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;; A LIVING DOCUMENT.  This fork writes its configuration in the
;;; Basalt register; the generator upstream reads its own keys
;;; natively.  :terms maps this register's keys onto the ones the
;;; generator reads -- substituted immediately after reading, so no
;;; shipped code changes.  Terms may be used only as KEYS in
;;; basalt.sexp, never as values.  (String values -- hostnames, image
;;; references, :requires tokens -- pass through untranslated.)
;;;
;;; :vocabulary is the dictionary's other half: the strings the
;;; generator and startup COIN (roster prefixes, startup titles,
;;; absence warnings, the shell hailing-call names).  Entries here
;;; override the upstream defaults via generated/vocabulary.env;
;;; anything omitted falls back.

(
 :terms
 (:services           :crew
  :mcp                :cyborg-passengers-allowed?
  :mcp-wrapper        :mcp
  :environment        :space-suit
  :volumes            :cargo-bays
  :source             :dockside
  :target             :stowed-at
  :ports              :hailing-frequencies
  :container          :aboard
  :host               :galaxy
  :hostname           :module
  :registry-namespace :provenance
  :image-variant      :strain
  :image              :species
  ;; The role system.  Substitution is position-blind, so these carry
  ;; role NAMES (value position) as well as the table keys.  A term
  ;; must therefore never be reused elsewhere in basalt.sexp with a
  ;; different meaning.
  :roles              :postings
  :role               :post
  :console            :captain
  :engine-ccl         :first-officer
  :engine-sbcl        :ships-engineer
  :ingress            :transporter-chief
  :dashboard          :communications-officer
  :monitor            :doctor)

 ;; Every string-valued key here emits as BASILISK_VOCAB_<KEY> in
 ;; generated/vocabulary.env, and the startup scripts read those in
 ;; place of their upstream defaults.  Values may be printf formats
 ;; (%s slots must match the upstream default's).  The :nocap-* group
 ;; lands inside a single-quoted printf format via sed, so those
 ;; values must avoid single quotes, `|' and `&'.
 ;;
 ;; The register here is deliberately NEUTRAL, PRECISE IT/computer
 ;; terminology -- serving an open-source Lisp/Linux hacker and a
 ;; corporate IT professional alike (the user, 2026-09-02).
 :vocabulary
 (:stowaway-designator "unassigned"
  :muster-titles (:captain       "Console"
                  :first-officer "Engine (CCL)"
                  :engineer      "Engine (SBCL)"
                  :pilot         "Ingress"
                  :comm          "Dashboard"
                  :doctor        "Monitor"
                  :stowaway      "Unassigned"
                  :crew          "Service")
  :no-ingress-warning "no ingress service configured: nothing fronts HTTP; ports publish directly"
  ;; The shell convenience commands for reaching the containerized
  ;; Emacs (the upstream words are rmax/grmax).
  :hail-term "rmacs"
  :hail-gui  "grmacs"

  ;; Deployment naming (generate-env.sh)
  :ship-minted "Generated deployment name: %s (recorded in %s)"
  :ship-buried "Previous deployment name %s retired to the deployment log (%s)"

  ;; Startup lock and lifecycle
  :slipway-busy "another start or stop holds the startup lock; waiting (up to 120s)..."
  :slipway-timeout "could not acquire the startup lock after 120s -- is another start wedged? (lock: %s)"
  :slipway-take "Starting deployment %s"
  :rouse "Starting services on the standing deployment%s: %s"
  :old-ship-retires "Stopping the standing deployment '%s' before the new start"
  :old-ship-protest "the previous deployment did not stop cleanly (see generated/last-stand-down.log)"
  :stand-down "Stopping deployment %s"
  :net-released "Deployment network '%s' was left in use by down; released it (try %s)"
  :net-held "Deployment network '%s' is still in use after down%s"

  ;; Instance naming
  :muster-head "Assigning container instance names:"
  :muster-stands "%s stays in place as the %s"
  :muster-relieves "%s replaces %s as the %s"
  :muster-joins "%s starts as the %s"
  :crew-by-net "(containers found by network lookup instead)"
  :no-ledger "no service ledger in generated/; services start without instance names (service-slug container names)"
  :oath "records its identity"
  :oath-to "with deployment %s"

  ;; Ledger-driven templates
  :templates-no-ledger "templates/ present but no service ledger in generated/; templates NOT rewritten"
  :template-rewrote "Rewrote %s -> generated/%s from the service ledger"

  ;; Health validation
  :validate-head "Health validation: polling each service every %ss (%ss budget and %s restarts allowed each)"
  :validated-all "All services validated in %ss; the deployment is up"
  :unhurried "warming up in the background (start-on-demand; not gating startup)"
  :cap-missing "%s: fills a role requiring \"%s\" but image %s does not list it (provided at runtime?)"
  :empty-head "DEPLOYMENT IS EMPTY: compose reports NO running containers."
  :empty-why1 "Either nothing started (check the compose output and the journal"
  :empty-why2 "above) or it is deliberately running with no services."
  :empty-validate "Nothing to validate; reporting success on an EMPTY deployment."

  ;; Image pulls
  :pull-all "Pulling every image fresh (PULL_ALWAYS set)"
  :pull-none "All images already present; nothing to pull"
  :pull-some "Pulling: %s"

  ;; MCP client configuration
  :mcp-open "Generating MCP client configurations (JSON + TOML)..."
  :mcp-posted "MCP client configurations written for container CLI, Windows, Codex, and Grok"
  :roster-head "Service roster:"
  :no-keeper-up "no container found for the %s -- is the deployment up?"
  :no-keeper-merge "no container found for the %s; skipping MCP config merge"
  :no-keeper-refresh "no container for the %s; skipping Emacs service refresh"

  ;; The welcome block and the generated shell helpers
  :welcome "Services are up."
  :welcome-head "Shell commands for this Basalt deployment"
  :hail-term-desc "terminal emacsclient into the console (attach here)"
  :hail-instance-desc "reach another deployment on this box"
  :hail-aliases "(eskew/egskew remain as aliases)"
  :welcome-note1 "(The next bare 'up' creates a NEW deployment under a fresh name;"
  :welcome-note2 "the old name is retired to the deployment log, containers and all.)"
  :nocap-no-docker "%s: docker not found on this host -- no way to reach the console."
  :nocap-not-running "%s: the console is present but not running (container \"%s\" is stopped)."
  :nocap-start "  Start it:  docker start %s"
  :nocap-absent "%s: no console container on this deployment (no \"%s\" container)."
  :nocap-bring-up "  Create one:  ./basalt up"
  :nocap-instance "  Another deployment on this box?  %s @<instance>"))
