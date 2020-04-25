(import process)
(import _process) # A bit naughty to take the private functions from process
                  # but the projects are developed in lockstep.
(import _sh :prefix "" :export true)

(defn- run-pipeline
  [input-specs &opt extra-redirects]

  (default extra-redirects [])
  
  (unless (indexed? (first input-specs))
    (error (string/format "expected arguments to be array or tuple, got %v" (first input-specs))))

  (def specs @[@[(first input-specs)]])
  (loop [i :range [1 (length input-specs)]]
    (match (in input-specs i)
     :
        (array/push specs @[])
      next
        (array/push (last specs) next)))

  (def procs @[])
  (var error-cleanup-files @[])
  (def finish @[])
  (def buf-mapping @{})

  (defn coerce-file [f]
    (cond 
      (buffer? f)
        (if-let [tmpf (get buf-mapping f)]
          (_process/dup tmpf)
          (do
            (def tmpf (file/temp))
            (put buf-mapping f tmpf)
            (array/push finish
              (fn []
                (file/seek tmpf :set 0)
                (file/read tmpf :all f)
                (file/close tmpf)))
            tmpf))
      f))

  (defn coerce-redirect [[f1 f2]]
    (cond
      (= f1 stdin)
      [f1 f2] # It seems wrong to handle stdin specially,
              # but I'm not sure of a way around the issue that 
              # if we redirect stdout/stderr to a buffer we want to append to the buffer.
              # if we redirect stdin to a buffer, we want to write the buffer.
      [(coerce-file f1) (coerce-file f2)]))

  (defn adjust-redirects
    [proc-spec new-redirects]
    (def proc-args (get proc-spec 0))
    (def proc-kwargs ((fn [_ &keys k] k) ;proc-spec))
    (def redirects
      (if-let [redirects (proc-kwargs :redirects)]
        (array/concat @[] redirects new-redirects)
        new-redirects))
    [proc-args ;(kvs (merge proc-kwargs {:redirects (map coerce-redirect redirects)}))])

  (defn pipe []
    (def pipes (process/pipe))
    (array/concat error-cleanup-files pipes)
    pipes)
  
  (defer (each f finish (f))
  (edefer (do
            (each p error-cleanup-files (file/close p))
            (each p procs (:close p)))
    (if (= (length specs) 1)
      (array/push procs (process/spawn ;(adjust-redirects (specs 0) extra-redirects)))
      (do
        (var [rp wp] (pipe))
        
        (def first-spec (adjust-redirects (first specs) [[stdout wp]]))
        (array/push procs (process/spawn ;first-spec))
        (file/close wp)

        (loop [i :range [1 (dec (length specs))]]
          (def [new-rp new-wp] (pipe))
          (def cur-spec (adjust-redirects (specs i) [[stdin rp] [stdout new-wp]]))
          (array/push procs (process/spawn ;cur-spec))
          (file/close rp)
          (file/close new-wp)
          (set rp new-rp))

        (def last-spec (adjust-redirects (last specs) [[stdin rp] ;extra-redirects]))
        (array/push procs (process/spawn ;last-spec))
        (file/close rp)))
    
    (map process/wait procs))))

(defn run
  ```
  Take a set of process specs, separated by : and form
  A shell pipeline. Returns a tuple of exit codes.


  : Is used as the pipe operator as | is reserved in janet for
  short-fn forms.

  Example usage:

    (sh/run ~[tar -cvpf .] : ~[sort -u])
    (sh/run ~[ls] :start-dir "/tmp")
    (match (sh/run ["yes"] : ["head" "-n5"])
      [_ 0]
        (print "success!")
      (error "failed!"))
  ```
  [& specs]
  (run-pipeline specs))

(defn $
  ```
  Shorthand for sh/run and raise an error if any commands failed. Similar
  to bash -e -o pipefail for those familiar.
  ```
  [& specs]
  (def exit-codes (run-pipeline specs))
  (unless (all zero? exit-codes)
    (error (string/format "command(s) failed with exit codes %j" exit-codes)))
  nil)

(defn $?
  ```
  $? takes the same arguments that sh/run takes and executes the pipeline.
  Returns true if all commands in the pipeline succeeded, false otherwise.

  Example usage:

  > (when (sh/$? ["rm" ;(sh/glob "*")]) (print "success"))
  ```
  [& specs]
  (all zero? (run-pipeline specs)))

(defn $$
  ```
  $$ takes the same arguments that sh/run takes and executes a pipeline.
  If the exit code is 0, it returns a string that contains
  stdout of the launched process. Otherwise raises an error.
  ```
  [& specs]
  (def buf @"")
  (def extra-redirects [[stdout buf]])
  (def exit-codes (run-pipeline specs extra-redirects))
  (unless (all zero? exit-codes)
    (error (string/format "command(s) failed with exit codes %j" exit-codes)))

  (string buf))

(defn $$_
  ```
  Like sh/$$, but trims trailing whitespace, this is what /bin/sh often does by default.
  ```
  [& specs]
  (def buf @"")
  (def extra-redirects [[stdout buf]])
  (def exit-codes (run-pipeline specs extra-redirects))
  (unless (all zero? exit-codes)
    (error (string/format "command(s) failed with exit codes %j" exit-codes)))

  # trim trailing whitespace
  (defn should-trim? [c]
    (or (= c 32)
        (= c 13)
        (= c 10)))

  (var c 10)
  (while (and (not (zero? (length buf))) (should-trim? c))
    (set c (buf (dec (length buf))))
    (buffer/popn buf 1))
  (when (not (should-trim? c))
    (buffer/push-byte buf c))

  (string buf))

