(import ../sh)

(def out-buf @"")

(assert 
  (all zero?
    (sh/run* 
      ["cat" :< [stdin "hello"] :> [stdout out-buf]])))
(assert (deep= @"hello" out-buf))

(assert 
  (all zero?
    (sh/run*
      ["echo" "-n" "a" :^ "b" :^ 123 :> [stdout out-buf]])))
(assert (deep= @"ab123" out-buf))

(assert 
  (all zero?
    (sh/run* 
      ["cat" :< "hello" :> out-buf])))
(assert (deep= @"hello" out-buf))

(assert 
  (all zero?
    (sh/run* 
      ["cat" :< [stdin @"abc"]]
      ["cat"]
      ["rev" :> [stdout out-buf]])))
(assert (deep= @"cba" out-buf))

(assert 
  (all zero?
    (sh/run* 
      ["cat" :< [stdin @"abc"]]
      ["rev"]
      ["rev" :> [stdout out-buf]])))
(assert (deep= @"abc" out-buf))

(assert 
  (all zero?
    (sh/run* 
      ["echo" "-n" "foo" :> [stdout out-buf]])))
(assert 
  (all zero?
    (sh/run* 
      ["echo" "-n" "foo" :>> [stdout out-buf]])))

(assert (deep= @"foofoo" out-buf))

(buffer/clear out-buf)
(assert 
  (all zero?
    (sh/run* 
      ["echo" "hello" :> [stdout :null]])))
(assert (deep= @"" out-buf))

(buffer/clear out-buf)
(assert 
  (all zero?
    (sh/run* 
      ["sh" "-c" "echo abc >&2" :>> [stderr out-buf]]
      ["sh" "-c" "echo def >&2" :>> [stderr out-buf]])))
(assert (= (length out-buf) 8))

(assert 
  (all zero?
    (sh/run* 
      ["sh" "-c" "echo abc >&2" :> [stderr out-buf]]
      ["sh" "-c" "echo def >&2" :>> [stderr out-buf]])))
(assert (= (length out-buf) 8))


(sh/$ echo hello > ,out-buf)
(assert (deep= out-buf @"hello\n"))

(assert (= (sh/$$ echo hello)
           "hello\n"))

(assert (= (sh/$$_ echo hello)
           "hello"))

(assert (sh/$? true))
(assert (not (sh/$? false)))

(assert (= (sh/$$_ echo ;[1 2 3])
           "1 2 3"))
