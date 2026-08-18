;;; services-generated.el --- Generated from basalt.sexp -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;; DO NOT EDIT - Regenerate with: (skewed-generate-all-configs)

(defvar skewed-generated-services nil)
(setq skewed-generated-services
  '(
    (:name "captain"
     :type "emacs-lisp"
     :lisp-impl "Emacs"
     :mcp t
     :http-host "captain"
     :http-port 7080
    )
    (:name "jr-eng-human"
     :type "common-lisp"
     :lisp-impl "CCL"
     :mcp t
     :http-host "jr-eng-human"
     :http-port 9080
     :http-host-port ${GENDL_CCL_HOST_PORT:-19080}
     :swank-host "jr-eng-human"
     :swank-port 4200
    )
    (:name "jr-eng-cyborg"
     :type "common-lisp"
     :lisp-impl "SBCL"
     :mcp t
     :http-host "jr-eng-cyborg"
     :http-port 9090
     :http-host-port ${GENDL_SBCL_HOST_PORT:-29080}
     :swank-host "jr-eng-cyborg"
     :swank-port 4210
    )
    (:name "medic"
     :type "utility"
    )
   ))
;; Services configuration generated from basalt.sexp.

(provide 'services-generated)
;;; services-generated.el ends here