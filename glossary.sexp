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
;;; basalt.sexp, never as values.
;;;
;;; :vocabulary is the dictionary's other half: the strings the
;;; generator and startup COIN (roster prefixes, startup titles,
;;; absence warnings).  Entries here override the upstream defaults
;;; via generated/vocabulary.env; anything omitted falls back.

(
 :terms
 (:services      :crew
  :mcp           :cyborg-passengers-allowed?
  :mcp-wrapper   :mcp
  :environment   :space-suit
  :volumes       :cargo-bays
  :source        :dockside
  :target        :stowed-at
  :ports         :hailing-frequencies
  :container     :aboard
  :host          :galaxy
  :image-variant :strain
  :image         :species
  ;; The role system.  Substitution is position-blind, so these carry
  ;; role NAMES (value position) as well as the table keys.  A term
  ;; must therefore never be reused elsewhere in basalt.sexp with a
  ;; different meaning.
  :roles         :postings
  :role          :post
  :console       :captain
  :front-line    :1st-officer
  :engineering   :ships-engineer
  :ingress       :transporter-chief
  :dashboard     :communications-officer
  :monitor       :medic)

 :vocabulary
 (:stowaway-designator "unassigned"
  :muster-titles (:captain  "Console"
                  :pilot    "Ingress"
                  :engineer "Engine"
                  :comm     "Dashboard"
                  :doctor   "Monitor"
                  :stowaway "Unassigned"
                  :crew     "Service")
  :no-ingress-warning "no ingress service configured: nothing fronts HTTP; ports publish directly"))
