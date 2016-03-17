#include <EXTERN.h>
#include <perl.h>

EXTERN_C void xs_init (pTHX);

EXTERN_C void boot_DynaLoader (pTHX_ CV* cv);

EXTERN_C void
xs_init(pTHX)
{
        char *file = __FILE__;
        dXSUB_SYS;

        /* DynaLoader is a special case */
        newXS("DynaLoader::boot_DynaLoader", boot_DynaLoader, file);
}

static PerlInterpreter *my_perl;

int main(int argc, char **argv, char **env) {
    char *cmd[argc+1];
    int i;

    cmd[0] = "";
    cmd[1] = "/usr/local/lib/vmprobe/main.pl";
    for(i = 1; i < argc; i++) {
        cmd[i+1] = argv[i];
    }

    PERL_SYS_INIT3(&argc,&argv,&env);
    my_perl = perl_alloc();
    perl_construct(my_perl);

    perl_parse(my_perl, xs_init, argc+1, cmd, (char **)NULL);
    PL_exit_flags |= PERL_EXIT_DESTRUCT_END;
    perl_run(my_perl);

    perl_destruct(my_perl);
    perl_free(my_perl);
    PERL_SYS_TERM();
}
