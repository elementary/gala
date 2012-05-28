namespace Gala {

    const string VERSION = "0.1";

    const OptionEntry[] OPTIONS = {
        { "version", 0, OptionFlags.NO_ARG, OptionArg.CALLBACK, (void*) print_version, "Print version", null },
        { null }
    };

    void print_version () {
        stdout.printf ("Gala %s\n", Gala.VERSION);
        Meta.exit (Meta.ExitCode.SUCCESS);
    }


}