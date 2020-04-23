(import sh)

(defmacro fail [] '(error "fail"))

(unless (first (protect (sh/$ ["true"])))
  (fail))

(when (first (protect (sh/$ ["false"])))
  (fail))

(unless (= (sh/$$ ["echo" "hello world!"]) "hello world!\n")
  (fail))

(unless (= (sh/$$_ ["echo" "hello world!"]) "hello world!")
  (fail))

(unless (= (sh/$$_ ["echo" "hello world!   "]) "hello world!")
  (fail))

(unless (= (sh/$$_ ["echo" "   "]) "")
  (fail))

(unless (sh/$? ["true"])
  (fail))

(unless (= (sh/$$ ["echo" "foo\nbar\nbar"] : ["sort" "-u"]) "bar\nfoo\n")
  (fail))

(def out @"")
(sh/run ["janet" "-e"
         "(print `hello`)
          (file/flush stdout)
          (eprint `world`)"]
        :redirects [[stdout out] [stderr out]])
(unless (= (string out) "hello\nworld\n")
  (fail))

(match (sh/run ["yes"] : ["cat"] : ["head" "-n5"] :redirects [[stdout :null]])
  [129 129 0] nil
  _ (fail))

# At least run some of the error path code, even though its hard to test.
(protect 
  (sh/run ["yes"] : ["cat"] : ["cat"] : [123] : ["head" "-n5"]))

# Globbing.

(unless (= ["project.janet"] (tuple ;(sh/glob "project.jan*")))
  (fail))

(unless (= ["notexists*"] (tuple ;(sh/glob "notexists*")))
  (fail))

(unless (= [] (tuple ;(sh/glob "notexists*" :x)))
  (fail))