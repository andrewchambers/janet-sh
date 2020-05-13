#include <janet.h>
#include <unistd.h>
#include <glob.h>
#include <errno.h>

static Janet glob_(int32_t argc, Janet *argv) {
    glob_t g;

    janet_arity(argc, 1, 2);

    const char *pattern = janet_getcstring(argv, 0);

    int glob_flags = GLOB_ERR|GLOB_NOCHECK;

    if (argc == 2) {
        uint64_t jflags = janet_getflags(argv, 1, "edxn");
        if (jflags & (1<<0)) glob_flags &= ~GLOB_ERR;
        if (jflags & (1<<1)) glob_flags |= GLOB_MARK;
        if (jflags & (1<<2)) glob_flags &= ~GLOB_NOCHECK;
        if (jflags & (1<<3)) glob_flags |= GLOB_NOESCAPE;
    }

    int rc = glob(pattern, glob_flags, NULL, &g);

    if (rc == GLOB_NOMATCH && !(glob_flags & GLOB_NOCHECK)) {
        return janet_wrap_array(janet_array(0));
    }

    if (rc != 0)
        janet_panicf("glob: %s", strerror(errno));

    char **p = g.gl_pathv;
    JanetArray *a = janet_array(g.gl_pathc);

    for (size_t i = 0; i < g.gl_pathc; i++)
        janet_array_push(a, janet_cstringv(p[i]));

    globfree(&g);

    return janet_wrap_array(a);
}

static const JanetReg cfuns[] = {
    // Unistd / Libc
    {   "glob", glob_,
        "(glob pattern &opt flags)\n\n"
        "Return an array of paths resulting from globbing.\n"
        "flags is a keyword with the following flag characters:\n\n"
        "e - Ignore permission errors while globbing.\n"
        "d - Add / to returned directory entries.\n"
        "x - If the glob matches nothing, return an empty list instead of the glob.\n"
        "n - Don't use backslash as an escape character.\n"
    },
    {NULL, NULL, NULL},
};

JANET_MODULE_ENTRY(JanetTable *env) {
    janet_cfuns(env, "sh", cfuns);
}
