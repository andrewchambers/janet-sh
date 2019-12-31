(declare-project
  :name "sh"
  :author "Andrew Chambers"
  :license "MIT"
  :url "https://github.com/andrewchambers/janet-sh"
  :repo "git+https://github.com/andrewchambers/janet-sh.git"
  :dependencies [
    "https://github.com/andrewchambers/janet-process.git"
   ])

(declare-source
  :name "sh"
  :source ["sh.janet"])

