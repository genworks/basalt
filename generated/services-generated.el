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
    (:name "console"
     :type "emacs-lisp"
     :lisp-impl "Emacs"
     :sku "readymacs"
     :mcp t
     :http-host "console"
     :http-port 7080
    )
    (:name "engine-ccl"
     :type "common-lisp"
     :lisp-impl "CCL"
     :sku "gendl-ccl"
     :mcp t
     :http-host "engine-ccl"
     :http-port 9080
     :http-host-port ${GENDL_CCL_HOST_PORT:-19080}
     :swank-host "engine-ccl"
     :swank-port 4200
    )
    (:name "engine-sbcl"
     :type "common-lisp"
     :lisp-impl "SBCL"
     :sku "gendl-sbcl"
     :mcp t
     :http-host "engine-sbcl"
     :http-port 9090
     :http-host-port ${GENDL_SBCL_HOST_PORT:-29080}
     :swank-host "engine-sbcl"
     :swank-port 4210
    )
    (:name "monitor"
     :type "utility"
     :sku "autoheal"
    )
   ))
;; Services configuration generated from basalt.sexp.

(provide 'services-generated)
;;; services-generated.el ends here