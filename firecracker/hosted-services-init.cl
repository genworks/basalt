;;; hosted-services-init.cl -- the init of a HOSTED microVM: one Gendl
;;; image carrying the prompt lab's deployed-application runtime and
;;; nothing a visitor could drive.  Installed by the hangar's rootfs
;;; build as /home/gendl-user/gdl-services-init.cl, the hook the image's
;;; run-gendl-services loads once HTTP and lisply are up.
;;;
;;; Everything that varies per VM rides on the kernel command line
;;; (phase0 boot args), read here from /proc/cmdline:
;;;   hosted.gate=<url>   the gate's Messages door (its side doors beside it)
;;;   hosted.lab=<name>   the lab whose deployment this is, as the gate's
;;;                       hosting ledger keys it (monocle:house-lab-name)
;;;   hosted.lock=<text>  a password that shuts every door of the lab's
;;;                       own; the deployed doors are not behind it
;;; The deployment itself is on the data disk at /data/prompt-lab-deployed/.

(in-package :gdl-user)

(load-quicklisp)

(defun hosted-arg (key)
  "The value of KEY=... on the kernel command line, or nil."
  (let* ((cmdline (with-open-file (in "/proc/cmdline" :if-does-not-exist nil)
                    (if in (read-line in nil "") "")))
         (needle (concatenate 'string key "="))
         (start (search needle cmdline)))
    (when start
      (let* ((from (+ start (length needle)))
             (end (or (position #\Space cmdline :start from) (length cmdline)))
             (value (string-trim '(#\Newline #\Return) (subseq cmdline from end))))
        (and (plusp (length value)) value)))))

(dolist (dir '("/opt/hosted/demos/" "/opt/hosted/monocle/"))
  (pushnew dir ql:*local-project-directories* :test #'equalp))
(ql:register-local-projects)
(ql:quickload :prompt-lab)

(ensure-directories-exist "/data/prompt-lab/")
(ensure-directories-exist "/data/prompt-lab-deployed/")

(setf (symbol-value (intern "*WORKSPACE-ROOT*" :prompt-lab)) "/data/prompt-lab/"
      (symbol-value (intern "*ARCHIVE-ROOT*" :prompt-lab)) nil
      (symbol-value (intern "*DEPLOYED-ROOT*" :prompt-lab)) "/data/prompt-lab-deployed/"
      ;; the lab's own doors shut: no sessions, no agent, no browsing
      (symbol-value (intern "*PASSWORD-FILE*" :prompt-lab)) nil
      (symbol-value (intern "*PASSWORD*" :prompt-lab)) (or (hosted-arg "hosted.lock") "hosted")
      (symbol-value (intern "*EXTERNAL-AGENT?*" :prompt-lab)) nil
      (symbol-value (intern "*BROWSING?*" :prompt-lab)) nil
      ;; the gate, where the tolls are paid and the hosting is metered
      (symbol-value (intern "*MESSAGES-URL*" :prompt-lab))
      (or (hosted-arg "hosted.gate") "http://transporter-room/llm/messages")
      (symbol-value (intern "*TOLL-PROVIDER*" :prompt-lab)) :stripe
      (symbol-value (intern "*DEPLOYMENT-PAYMENTS?*" :prompt-lab)) t)

;; The gate's hosting ledger is keyed by the lab's name: this VM reports
;; its compiles and runs under the lab that deployed the application,
;; so the author's allowance and what they bought apply here.
(let ((lab (hosted-arg "hosted.lab")))
  (when lab
    (setf (symbol-function (intern "DEPLOYMENT-LAB-NAME" :prompt-lab))
          (lambda () lab))))

(funcall (intern "PUBLISH-PROMPT-LAB!" :prompt-lab))

(format t "~&[hosted-init] hosted runtime up at ~a; gate ~a; lab ~a; deployments: ~a~%"
        (symbol-value (intern "*URL-PREFIX*" :prompt-lab))
        (symbol-value (intern "*MESSAGES-URL*" :prompt-lab))
        (funcall (intern "DEPLOYMENT-LAB-NAME" :prompt-lab))
        (mapcar (lambda (r) (gethash "name" r))
                (funcall (intern "DEPLOYMENT-RECORDS" :prompt-lab))))
