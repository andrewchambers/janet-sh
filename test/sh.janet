(import "../sh" :as sh)

(defmacro fail [] '(error "fail"))

(unless (first (protect (sh/$ ["true"])))
  (fail))

(when (first (protect (sh/$ ["false"])))
  (fail))

(unless (= (string (sh/$$ ["echo" "hello world!"])) "hello world!\n")
  (fail))

(unless (= (string (sh/$$_ ["echo" "hello world!"])) "hello world!")
  (fail))

(unless (= (string (sh/$$_ ["echo" "hello world!   "])) "hello world!")
  (fail))

(unless (= (string (sh/$$_ ["echo" "   "])) "")
  (fail))

(unless (sh/$? ["true"])
  (fail))

(unless (= ["foo\n" true] (freeze (sh/$$? ["echo" "foo"])))
  (fail))

(unless (= (string (sh/$$ (sh/pipeline [["echo" "foo\nbar\nbar"] ["sort" "-u"]]))) "bar\nfoo\n")
  (fail))