(import posix-spawn)
(import _sh :prefix "" :export true)

(defn run*
  ``
  A function version of `run` that accepts a tuple or array of strings.

  Returns an array with exit code.

  Example: `(sh/run* ["ls" "-lh"])`
  ``
  [& specs]
  # All procs in pipeline
  (def procs @[])
  # List of functions run after spawn calls.
  (def post-spawn @[])
  # List of functions run, even on error.
  (def finish @[])
  (def buf-mapping @{})

  (defn buf-to-out-file
    [buf-mapping buf]
    (if-let [tmpf (get buf-mapping buf)]
      tmpf
      (do
        (def tmpf (file/temp))
        (put buf-mapping buf tmpf)
        (array/push finish
          (fn []
            (file/seek tmpf :set 0)
            (file/read tmpf :all buf)
            (file/close tmpf)))
        tmpf)))

  (defn coerce-file [op f]
    (cond
      (buffer? f)
        (case op
          :>
            (do
              (buffer/clear f)
              (buf-to-out-file buf-mapping f))
          :>>
            (buf-to-out-file buf-mapping f)
          :<
            (do
              (def tmpf (file/temp))
              (file/write tmpf f)
              (file/flush tmpf)
              (file/seek tmpf :set 0)
              (def closef |(file/close tmpf))
              (array/push post-spawn closef)
              (array/push finish closef)
              tmpf)
          (error (string/format "unsupported redirect %p %p" op (type f))))
      (string? f)
        (case op
          :<
            (do
              (def tmpf (file/temp))
              (file/write tmpf f)
              (file/flush tmpf)
              (file/seek tmpf :set 0)
              (def closef |(file/close tmpf))
              (array/push post-spawn closef)
              (array/push finish closef)
              tmpf)
          (error (string/format "unsupported redirect %p %p" op (type f))))
      (= f :null)
        (do
          (def nullf (file/open "/dev/null" :wb+))
          (def closef |(file/close nullf))
          (array/push post-spawn closef)
          (array/push finish closef)
          nullf)
      f))

  (defn add-redirect [file-actions op a b]
    (def a (or a (if (= op :<) stdin stdout)))
    (case op
      :>
        (array/push file-actions [:dup2 (coerce-file :> b) a])
      :>>
        (array/push file-actions [:dup2 (coerce-file :>> b) a])
      :<
        (array/push file-actions [:dup2 (coerce-file :< b) a])
      (error (string/format "unsupported redirect %p" op))))

  (defn pipe []
    (def pipes (posix-spawn/pipe))
    (array/push finish |(each p pipes (file/close p)))
    pipes)

  (defn parse-spec
    [spec]
    (var cur-op nil)
    (def args @[])
    (def file-actions @[])
    (var state :start)
    (def q (reverse spec))
    (while (not (empty? q))
      (case state
        :start
          (match (array/pop q)
            (arg (or (string? arg) (symbol? arg)))
              (array/push args arg)
            (arg (or (number? arg) (boolean? arg)))
              (array/push args (string arg))
            (rop (or (= rop :>) (= rop :>>) (= rop :<)))
              (do
                (set cur-op rop)
                (set state :redir))
            :^
             (do
               (set state :concat))
            a
              (error (string/format "unsupported argument %m" a)))
        :redir
          (do
            (match (array/pop q)
              [a b]
                (add-redirect file-actions cur-op a b)
              [b]
                (add-redirect file-actions cur-op nil b)
              b
                (add-redirect file-actions cur-op nil b)
              (error "redirects requires one or two targets"))
            (set state :start))
        :concat
          (match (array/pop q)
            (arg (or (string? arg) (symbol? arg) (number? arg)))
              (do
                # It may be worth batching them up to do the concat all at once.
                (array/push args (string (array/pop args) arg))
                (set state :start))
            a
              (error (string/format "can only concatinate strings symbols or numbers, not %v" a)))
        (error nil)))
    (cond state
      :start
        nil
      :concat
        (error "concat without right hand side")
      :redir
        (error "redirect without targets")
      (error "command parse in unexpected state"))
    [args file-actions])

  (defn spawn-spec
    [spec]
    (def [args file-actions] (parse-spec spec))
    (array/push procs (posix-spawn/spawn2 args {:file-actions file-actions})))

  (defer (each f finish (f))
    (edefer (each p procs (posix-spawn/close p))
      (if (= (length specs) 1)
        (spawn-spec (first specs))
        (do
          (var [rp wp] (pipe))

          # Start of pipeline
          (spawn-spec (tuple ;(first specs) :> [stdout wp]))
          (file/close wp)

          # Pipeline middle
          (loop [i :range [1 (dec (length specs))]]
            (def [new-rp new-wp] (pipe))
            (def spec (specs i))
            (spawn-spec (tuple ;(specs i) :< [stdin rp] :> [stdout new-wp]))
            (file/close rp)
            (file/close new-wp)
            (set rp new-rp))

          # Pipeline end.
          (spawn-spec (tuple ;(last specs) :< [stdin rp]))
          (file/close rp)))

      (each f post-spawn (f))
      (map posix-spawn/wait procs))))

(defn- collect-proc-specs
  [forms]
  (def specs @[@[]])
  (def q (reverse forms))
  (while (not (empty? q))
    (def f (array/pop q))
    (cond
      (tuple? f)
        (case (f 0)
          'unquote
            (array/push (last specs) (f 1))
          'short-fn
            (do
              (array/push specs @[])
              (array/push q (f 1)))
          (array/push (last specs) f))
      (or (= f '>) (= f '>>) (= f '<) (= f '^))
        (array/push (last specs) (keyword f))
      (symbol? f)
        (array/push (last specs) (tuple 'quote f))
      (or (number? f) (boolean? f))
        (array/push (last specs) (string f))
      (array/push (last specs) f)))
  specs)

(defmacro run
  ``
  Run a process and get its exit code.

  Returns an array with exit code.

  Example: `(sh/run "ls" "-lh")`
  ``
  [& args]
  (def specs (collect-proc-specs args))
  (tuple run* ;specs))

(defn $?*
  ``
  A function version of `$?` that accepts a tuple or an array of strings.

  Returns a boolean indicating success or failure.

  Example: `(sh/$?* ["ls" "-lh"])`
  ``
  [& specs]
  (def exit (run* ;specs))
  (all zero? exit))

(defmacro $?
  ``
  Run a process and determine whether it succeeded.

  Returns a boolean indicating success or failure.

  Example: `(sh/$? "ls" "-lh")`
  ``
  [& args]
  (def specs (collect-proc-specs args))
  (tuple $?* ;specs))

(def- emsg "command(s) %p failed, exit code(s) %j")

(defn $*
  ``
  A function version of `$` that accepts a tuple or an array of strings.

  Returns nil for success, aborts on error.

  Example: `(sh/$* ["ls" "-lh"])`
  ``
  [& specs]
  (def exit (run* ;specs))
  (unless (all zero? exit)
    (error (string/format emsg specs exit)))
  nil)

(defmacro $
  ``
  Run a process and abort on error.

  Returns nil for success, aborts on error.

  Example: `(sh/$ "ls" "-lh")`
  ``
  [& args]
  (def specs (collect-proc-specs args))
  (tuple $* ;specs))

(defn $<*
  ``
  A function version of `$<` that accepts a tuple or an array of strings.

  Returns a string.

  Example: `(sh/$<* ["ls" "-lh"])`
  ``
  [& specs]
  (def out @"")
  (def exit (run* ;(tuple/slice specs 0 -2) (tuple :> out ;(last specs))))
  (unless (all zero? exit)
    (error (string/format emsg specs exit)))
  (string out))

(defmacro $<
  ``
  Run a process with output as a string.

  Returns a string.

  Example: `(sh/$< "ls" "-lh")`
  ``
  [& args]
  (def specs (collect-proc-specs args))
  (tuple $<* ;specs))

(defn $<_*
  ``
  A function version of `$<_` that accepts a tuple or an array of strings.

  Returns a string.

  Example: `(sh/$<_* ["ls" "-lh"])`
  ``
  [& specs]
  (def out @"")
  (def exit (run* ;(tuple/slice specs 0 -2) (tuple :> out ;(last specs))))
  (unless (all zero? exit)
    (error (string/format emsg specs exit)))
  (defn should-trim? [c]
    (or (= c 32)
        (= c 13)
        (= c 10)))
  (var c 10)
  (while (and (not (zero? (length out))) (should-trim? c))
    (set c (out (dec (length out))))
    (buffer/popn out 1))
  (when (not (should-trim? c))
    (buffer/push-byte out c))
  (string out))

(defmacro $<_
  ``
  Run a process with output as a string with any trailing newlines trimmed.

  Returns a string.

  Example: `(sh/$<_ "ls" "-lh")`
  ``
  [& args]
  (def specs (collect-proc-specs args))
  (tuple $<_* ;specs))
