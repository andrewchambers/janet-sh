(import process)

(defn- shell-quote1
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
  ```
  Concatenate a list of strings into shell quoted string (STR)
  such that (sh/run ["sh" "-c" STR]) will treat
  each list argument as a command argument.

  Example Usage:

  > (sh/shell-quote ["hello" "there ' \""])
  "'hello' 'there '\\'' \"'"
  ```
  [args]
  (string/join (map shell-quote1 args) " "))

(defn pipeline
  ```
  Turn a list of commands into a shell command that
  pipe the output of a command to the next command.
  Each command is a list of strings.

  Example Usage:

  > (sh/pipeline [["tar" "-C" dir "-cf" "-" "."] ["gzip"]])
  @["/bin/sh" "-c" "'tar' '-C' 'dir' '-cf' '-' '.' | 'gzip'"]

  > (sh/$$ (sh/pipeline [["tar" "-C" dir "-cf" "-" "."] ["gzip"]]))
  ```
  [commands &opt shell]
  (default shell ["/bin/sh" "-c"])
  (array/concat (array ;shell)
                (string/join (interpose "|" (map shell-quote commands)) " ")))

(def run
  "This is the same as process/run. This exists for convenience."
  process/run)

(defn $
  ```
  $ takes the same arguments that process/run takes and executes a command.
  It throws an error if exit code is non-zero.
  ```
  [args &keys k]
  (def exit-code (process/run args ;(flatten (pairs k))))
  (unless (zero? exit-code)
    (error (string "command failed with exit code " exit-code)))
  nil)

(defn $?
  ```
  $? takes the same arguments that process/run takes and executes a command.
  If the exit code is zero, return true.
  If the exit code is not zero, return false.

  Example usage:

  > (when (sh/$? ["rm" dir]) (print "success"))
  ```
  [args &keys k]
  (zero? (process/run args ;(flatten (pairs k)))))

(defn $$?
  ```
  $$? takes the same arguments that process/run takes and executes a command.
  It returns [buf true] if the exit code is 0.
  It returns [buf false] if the exit code is not 0.
  buf is a buffer that contains stdout of the launched process.
  ```
  [args &keys k]
  (def buf (buffer/new 0))
  (def redirects (tuple ;(get k :redirects []) [stdout buf]))
  [buf (zero? (process/run args :redirects redirects ;(flatten (pairs k))))])

(defn $$
  ```
  $$ takes the same arguments that process/run takes and executes a command.
  If the exit code is not 0, it throws an error.
  If the exit code is 0, it returns a buffer that contains
  stdout of the launched process.
  ```
  [args &keys k]
  (def buf (buffer/new 0))
  (def redirects (tuple ;(get k :redirects []) [stdout buf]))
  (def exit-code (process/run args :redirects redirects ;(flatten (pairs k))))
  (unless (zero? exit-code)
    (error (string "command failed with exit code " exit-code)))
  buf)

(defn $$_
  ```
  $$_ takes the same arguments that proces/run takes and executes a command.
  If the exit code is not 0, it throws an error.
  If the exit code is 0, it returns a buffer that contains
  stdout of the launched process with trailing whitespaces removed.

  A newline (\n), a carrige return (\r), and a space are considered as
  a whitespace.
  ```
  [args &keys k]
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

