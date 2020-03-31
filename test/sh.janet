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

(unless (= ["foo\n" true] (sh/$$? ["echo" "foo"]))
  (fail))

(unless (= (sh/$$ (sh/pipeline [["echo" "foo\nbar\nbar"] ["sort" "-u"]])) "bar\nfoo\n")
  (fail))

(unless (= ["project.janet"] (tuple ;(sh/glob "project.jan*")))
  (fail))

(unless (= ["notexists*"] (tuple ;(sh/glob "notexists*")))
  (fail))

(unless (= [] (tuple ;(sh/glob "notexists*" :x)))
  (fail))