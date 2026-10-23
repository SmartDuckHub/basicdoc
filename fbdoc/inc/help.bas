'' =====================================================================
''  fbdoc - Hulptekst (--help)
'' =====================================================================

Sub ShowHelp()
    Say Tr3("%1 %2 (build %3) - documentation generator for FreeBASIC", APP_NAME, APP_VERSION, APP_BUILD)
    Say ""
    Say Tr1("Usage:  %1 [options] <path> [path2 ...]", APP_NAME)
    Say ""
    Say Tr("Paths may be folders or individual files.")
    Say ""
    Say Tr("Options:")
    Say Tr("  -o, --output <file>      write output to file (otherwise stdout)")
    Say Tr("  -f, --format <fmt>       text | md | html | json | dot | mermaid | tree")
    Say Tr("                           (default text)")
    Say Tr("  -l, --lang <code|.po>    language of all texts (default en); loads")
    Say Tr("                           lang/<code>.po next to the program, or the")
    Say Tr("                           given .po file. FBDOC_LANG sets the default.")
    Say Tr("  -n, --name <name>        project name in the report header")
    Say Tr("  -e, --ext <list>         extensions, comma separated (default .bas,.bi)")
    Say Tr("  -x, --exclude <pattern>  exclude path pattern (may be repeated)")
    Say Tr("  -p, --private            include private functions (default on)")
    Say Tr("      --no-private         document public functions only")
    Say Tr("  -R, --no-recursive       do not scan recursively")
    Say Tr("  -G, --no-generate        do not generate descriptions for missing")
    Say Tr("                           comments (leave empty)")
    Say Tr("  -u, --undocumented       show only elements without comments")
    Say Tr("  -c, --coverage           print a coverage summary")
    Say Tr("      --fail-under <pct>   exit code 1 if coverage is below pct (CI)")
    Say Tr("  -q, --quiet              no progress messages")
    Say Tr("  -v, --verbose            messages per file")
    Say Tr("  -d, --debug              show what Dir() returns per folder/file")
    Say Tr("      --log <file>         also write all messages to this file")
    Say ""
    Say Tr("Call graph (formats dot, mermaid, tree):")
    Say Tr("      --follow             follow #include references and read those")
    Say Tr("                           files as reference")
    Say Tr("  -i, --include <folder>   search path for #include (may be repeated)")
    Say Tr("      --follow-depth <n>   how deep to follow transitively (default 2)")
    Say Tr("      --refs <path>        read an extra path to resolve calls into other")
    Say Tr("                           projects; that code is not documented, only")
    Say Tr("                           used in the diagram")
    Say Tr("                           (may be repeated)")
    Say Tr("      --ref-depth <n>      how many steps of reference code in the diagram")
    Say Tr("                           (default 1: only what your code calls")
    Say Tr("                           directly; 0 = none)")
    Say Tr("      --extern             also show unresolved calls")
    Say Tr("      --depth <n>          maximum depth of the text tree (default 12)")
    Say Tr("  -h, --help               this help")
    Say Tr("      --version            version")
    Say ""
    Say Tr("Default exclusions: /.git/  /.svn/  /obj/")
    Say ""
    Say Tr("Examples:")
    Say "  " & APP_NAME & " -f html -o api.html -n " & Chr(34) & Tr("My project") & Chr(34) & " ./src"
    Say "  " & APP_NAME & " -f md -o API.md ./src"
    Say "  " & APP_NAME & " -l nl -f html -o api.html ./src"
    Say "  " & APP_NAME & " -u -c --fail-under 60 ./src"
    Say "  " & APP_NAME & " -f json -o fbdoc.json -p ./src"
    Say "  " & APP_NAME & " -f tree -o calls.txt ./src"
    Say "  " & APP_NAME & " -f dot -o calls.dot ./src"
    Say "  " & APP_NAME & " -f html --split -o docs --follow -i inc ./src"
    Say Tr("     and then:  dot -Tsvg calls.dot -o calls.svg")
End Sub
