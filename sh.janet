(import process)

(defn shell-quote1
  [arg]

  (def buf (buffer/new (* (length arg) 2)))
  (buffer/push-string buf "'")
  (each c arg
    (if (= c (comptime ("'" 0)))
      (buffer/push-string buf "'\\''")
      (buffer/push-byte buf c)))
  (buffer/push-string buf "'")
  (string buf))

(defn shell-quote
  [args]
  (string/join (map shell-quote1 args) " "))

(defn pipeline [commands &opt shell]
  (default shell ["/bin/sh" "-c"])
  (array/concat (array ;shell) (string/join (interpose "|" (map shell-quote commands)) " ")))

# just convenience
(def run process/run)

(defn $ [args &keys k]
  (def exit-code (process/run args ;(flatten (pairs k))))
  (unless (zero? exit-code)
    (error (string "command failed with exit code " exit-code)))
  nil)

(defn $? [args &keys k]
  (zero? (process/run args ;(flatten (pairs k)))))

(defn $$? [args &keys k]
  (def buf (buffer/new 0))
  (def redirects (tuple ;(get k :redirects []) [stdout buf]))
  [buf (zero? (process/run args :redirects redirects ;(flatten (pairs k))))])

(defn $$ [args &keys k]
  (def buf (buffer/new 0))
  (def redirects (tuple ;(get k :redirects []) [stdout buf]))
  (def exit-code (process/run args :redirects redirects ;(flatten (pairs k))))
  (unless (zero? exit-code)
    (error (string "command failed with exit code " exit-code)))
  buf)

(defn $$_ [args &keys k]
  (def buf (buffer/new 0))
  (def redirects (tuple ;(get k :redirects []) [stdout buf]))
  (def exit-code (process/run args :redirects redirects ;(flatten (pairs k))))
  (unless (zero? exit-code)
    (error (string "command failed with exit code " exit-code)))
  
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

  buf)

