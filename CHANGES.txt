Release (HEAD -> master, tag: coast_20150909)
-------------

-   2015-09-09 Marcel Huber

    ChangeLog: added CHANGES.txt describing what changed

    Change-Id: I6990aabb233c9fd1b807852c924809e21542de01



-   2015-09-05 Marcel Huber

    SystemLog: added env var template for timestamped logging

    Change-Id: I5d8a88afec720bbbd9fa8b7e1f1723bf463871e3



-   2015-09-03 Marcel Huber

    getGLIBCVersion: faster implementation using ldd --version

    - in case there is an ldd utility, available on most linux systems,
     we can use it to determine the glibc version
    - the slower fallback version is still present and used whe no ldd is
    detected

    Change-Id: I2a5df4dc8f0cb6412abb4bf6a8143b3ebd0d3ddc



-   2015-09-03 Marcel Huber

    ulimit: simplified/corrected handles and coresize handling

    - keepwds script did not pass handles argument correctly, used -n instead
    of -h
    - simplified passing values across scripts; not using ulimit specific
     option name in passed values anymore
    - also adapted startprf.sh script

    Change-Id: I1246d15ea3f381f623014ddc2fa442540fba3e06


Release (tag: coast_20141003)
-------------

-   2014-10-03 Marcel Huber

    sconsider: require sconsider tooling <0.5

    Change-Id: I94fcd897ebf75e24d22d42cef2412d943e9672cf



-   2014-10-03 Marcel Huber

    gerrit: removed old git-review script, use git-review from PYPI instead

    Change-Id: I3fd2499826dac03c26c6266f2fe77424ccf22778



-   2014-10-03 Marcel Huber

    sysfuncs: do not fail find call

    find sould not fail when a specific /lib directory is not available

    Change-Id: Ic618b664ab0912abbc872d1d2b8960c300a1d4a1



-   2014-10-03 Marcel Huber

    build: using listFiles instead of findFiles to not recurse dirs

    Change-Id: If216dd5002c530b7a9d7953b9cceb14cae6ca285



-   2014-10-03 Marcel Huber

    project: gitreview config file added

    Change-Id: I2fd43b1f4a063da5e531ee80ff575e67d5eedde1



-   2013-03-05 Marcel Huber

    changed sed search separator from - to |

    minus might occur in file or directory names

    Change-Id: I7423badb33e7460174d0c7b0dfe6fa7319aa3177



-   2012-07-27 Marcel Huber

    asking for upload topic was wrong for non master branches

    Change-Id: I9178902375bc001523986b8e43d46cfd44aaba1f



-   2012-06-26 Marcel Huber

    added isLocalBranchAheadOfRemote

    check if local branch is ahead of remote

    Change-Id: Ia256ccd96c2c0b878f56c79f5a05dcd5ca156bb9



-   2012-06-13 Marcel Huber

    simplified push options handling

    Change-Id: I330b94bca8c5316698e6682d23e7d7503c3a4a05



-   2012-06-13 Marcel Huber

    asking for additional gerrit push options like --reviewer= or --cc=

    Change-Id: I9a0a89895acfd9946da1ae79d0ef026c86d37c45



-   2012-06-13 Marcel Huber

    better handling of return code when using temporary directory for
    filter-branch

    enhanced git-review script

    Change-Id: Ib43ad80e6f607d0fdbbf39668fbac8976fdb583c



-   2012-06-07 Marcel Huber

    removed comments within inline shell script

    Change-Id: I40a3a5fd43e4f8eeff125fb48de0d1f5ed3fd5c6



-   2012-06-07 Marcel Huber

    changed to using temporary directory when calling filter-branch

    Change-Id: Ia9b3898580fee073c1e15b2ff202ad83397b4944



-   2012-06-03 Marcel Huber

    major script refactoring to use /bin/sh interpreter only

    improved backward compatibility

    commit 256530c249abe531c46cd572124ef8ae614f598d Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Tue May 29 22:57:43 2012 +0200

        fixed curious behavior when restarting server

        it happened that the currently running server did not properly
    terminate

        improved responsiveness when sending signals to sleeping script by
    using wait on backgrounded sleep

    commit 7283d39052f3051559dcd0b480235c08d757c9fa Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Tue May 29 22:57:22 2012 +0200

        corrected finding gnu (gdb) executable

    commit eb13a348cdc24bce8f6b8c05966387f2b7416fe9 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Tue May 29 22:55:49 2012 +0200

        fixed server pid retrieval in case it was started from within gdb

        need to execute gdb within eval to account for potential
    LD_LIBRARY_PATH prefix

    commit 8872201decdda3e0c828dc84050947ded4b828cc Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Tue May 29 22:15:36 2012 +0200

        corrected variable expansion error

    commit ddf5624980b143095c0c7d164f28641575e6c6eb Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Tue Mar 13 22:59:17 2012 +0100

        removed SoftRestart script from list of defined variables

    commit 431a23bd336ed67abb850bb2193ff6bbdaf52b51 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Mon Mar 12 21:55:01 2012 +0100

        soft-/restart scripts replaced by bootScript.sh restart|reload

    commit b0cb4ca2d08ce0903431f6dc530ec5561b8ba688 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Fri Mar 9 23:37:37 2012 +0100

        also unsetting alias when trying to search real location of binary

    commit 5a1ff2131eed5d9aef80458be99b100ba0568dcd Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Fri Mar 9 23:37:01 2012 +0100

        printing message when requested gdb can not be detected

    commit 0a64836efcac3e9704cb719a4a06e03783b3b0dc Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Fri Mar 9 23:35:23 2012 +0100

        removed duplicate semicolon

        fixed WD_PATH definition

    commit fd70bff41836c824b53c03e30014c774f40c1eb1 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Fri Mar 9 23:34:34 2012 +0100

        chown'ing .RunUser file when started as root

    commit b6f52df92955c125accf8b437b56f04627335323 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Fri Mar 9 23:33:21 2012 +0100

        optmized SetupLDPath to use binaries from arguments and to filter out
    duplicates

    commit 2b7d6127cc017d922b0f68ceb77dd3aecaea5d87 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Fri Mar 9 23:31:58 2012 +0100

        optimized GetBindir to pass all path parameters directly into find's
    search path

    commit edb468591d857fb987394ff2c0cd79f42224886f Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Fri Mar 9 23:29:38 2012 +0100

        removed definition of TEST_EXE

    commit 638ae6291f9e50612a4a07da187b9de1742cedb8 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Fri Mar 9 23:25:59 2012 +0100

        re-enabled possibility to use bootScript with absolute path if config
    directory can be found below

        fixed case with path expanded by shell

    commit ee7697cd21e6e91b6ada21cb62a7f1510646820d Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Fri Mar 9 23:22:11 2012 +0100

        not searching/defining (AWK|DIFF|FIND)EXE in sysfuncs anymore

    commit 82434516a7fec8d918a59f2f74276fc55c6c2cca Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Fri Mar 9 00:25:37 2012 +0100

        improved findFirstValidTool again

    commit 9eb088dee54b1c3aa1826a475529a4dde1eceede Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Thu Mar 8 23:01:42 2012 +0100

        better naming for pre and post start scripts

    commit 4f211eb0bf0031486d32a22abe38896f19069b29 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Thu Mar 8 22:55:51 2012 +0100

        extended default binary search path for (gnu) executable searching

    commit 3a005fb7ebe2b33d2f0d826845d34a447e0363d2 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Thu Mar 8 22:41:31 2012 +0100

        minor fixes

    commit 756c970fe5ab4e6ee07a9864bdbe5eb3c4cb4d29 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Thu Mar 8 22:41:06 2012 +0100

        corrected shutdown in keepwds

    commit 062674965cb24bfe38977471ec456547891b30b6 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Thu Mar 8 22:40:17 2012 +0100

        removed wrong continue at line ending

    commit 25032e87f37c7ef55cbd153ea76c6eada0ca1799 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Thu Mar 8 22:39:08 2012 +0100

        added getUid function to correctly get a user id

    commit 5efb16db5f361a052a1f05f5cc8300b7370643f5 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Thu Mar 8 22:37:28 2012 +0100

        corrected initialization of IS_GNU* variables

    commit b4b075eee26579d052f3a8d9a27068f048678c87 Author: Marcel Huber
    <marcelhuberfoo@gmail.com> Date:   Mon Mar 5 14:21:35 2012 +0100

        changed to using sh style shell syntax only

        refactored many common parts into either sysfuncs or serverfuncs

        starting scripts more similar to each other

        refactored logging messages

        changed to using killserver functions instead of calling other script
    to do so

        iterating in /proc to find matching process with name as using ps is
    not safe to use with very long executable names

    Change-Id: I6a8836b5cb400ba002c908d7521f07e321dd3198



-   2012-02-01 Marcel Huber

    extract and supply product version from Version.any

    Change-Id: Ib81f86b1ed2274b387f0518c2aaf78cc2b91b5c0



-   2012-01-11 Marcel Huber

    pure sh'ified shell code

    $((..)) does not work on suns /bin/sh

    sed scripts also needed some escapes within REs

    Change-Id: I1f985dc95e4f11170c6e08c548301d38b57b2fd1



-   2011-12-12 Marcel Huber

    git/gerrit helper to simplify gerrit usage

    Change-Id: I47219d736822fff455a8182c44d1499121fd3810



-   2011-10-04 Marcel Huber

    corrected option default and removed obsoleted token



-   2011-09-14 Marcel Huber

    improved detection of available libc on the system by adding more default
    locations to check



-   2011-01-28 Marcel Huber

    these files are not needed anymore as we do not use EXPORTDECL tokens
    anymore



-   2011-01-28 Marcel Huber

    finally removed config switching code



-   2011-01-28 Marcel Huber

    changed from /bin/ksh to /bin/sh to ensure compatibility with other systems


Release (tag: coast_2010_1.2)
-------------

-   2010-11-05 Marcel Huber

    changed to coast



-   2010-10-26 Marcel Huber

    more prefix WD_ to COAST_ changes



-   2010-10-23 Marcel Huber

    replaced WD_ prefixes with COAST_



-   2010-08-31 Michael Rüegg

    merged git-submodule tag create and update scripts



-   2010-08-31 Marcel Huber

    adjusted cross ref hash list by filtering duplicate entries and using the
    'newer' hash



-   2010-08-30 Marcel Huber

    added useful post-rewrite template

    added xref update script to modify hashes in referencing module



-   2010-08-27 Marcel Huber

    added dry-run option to test before doing



-   2010-08-27 Marcel Huber

    script to create cross referencing tags in a submodule and its referencing
    repository -> these tags can later - after history rewriting - be used to
    correct commit hashes in referencing repository



-   2010-08-27 Marcel Huber

    removed scripts not needed for building and creating packages



-   2010-08-27 Marcel Huber

    added dtrace analyer script small changes to reduce verbosity in case of
    failures



-   2010-08-27 Marcel Huber

    added sconsider build file with a minimal set of server control scripts
    moved _cfgSwitch relevant parts into if checked blocks this allows delivery
    of a minimal package of scripts not relying on config switching stuff


Release (tag: coast_2010_1.1)
-------------

-   2010-08-27 Marcel Huber

    added revision option to limit range of replacement

    improved help text



-   2010-08-27 Marcel Huber

    adjusted help message and revision param



-   2010-08-27 Marcel Huber

    helper script to remove a commit added



-   2010-08-27 Marcel Huber

    small adjustments/corrections



-   2010-08-27 Marcel Huber

    using git-sh-setup delivered with git

    changed reflog deletion



-   2010-08-27 Marcel Huber

    improved usability of git helper scripts



-   2010-08-27 Marcel Huber

    updated filter-branch options to rewrite tags



-   2010-08-27 Marcel Huber

    renamed helper script



-   2010-08-27 Marcel Huber

    added script to move directories



-   2010-08-27 Marcel Huber

    improved filter-branch command to only commit non-empty commits

    improved history cleaning command



-   2010-08-27 Marcel Huber

    corrected expire flag

    only redirecting stdout



-   2010-08-27 Marcel Huber

    added helper script to remove directories from a repository



-   2010-08-27 Marcel Huber

    export native LD_LIBRARY_PATH to shield from differences between 3rdparty
    libs and OS installed libs made evaluation of path to script that will be
    sourced more reliable



-   2010-08-27 Marcel Huber

    added reasonable default value for MYNAME variable to eliminate dirname
    error message under certain circumstances



-   2010-08-27 Marcel Huber

    Added -P option (long path to executable)



-   2009-03-05 Marcel Huber

    Added comments.



-   2010-08-27 Marcel Huber

    Changes to enable 2 instances of the same server to run in the same
    machine.



-   2010-08-27 Marcel Huber

    filtering pstack output using c++filt if available



-   2010-08-27 Marcel Huber

    added shell script to create submodule from repo path



-   2010-08-27 Marcel Huber

    * added -P option which shows full path of started application   when doing
    a ps -ef



-   2010-08-27 Marcel Huber

    corrected adding .ld-search-path to currently tested binary directory



-   2010-08-27 Marcel Huber

    introduced OSREL_MAJOR and OSREL_MINOR variables


Release (tag: wd_scripts_1_12, tag: wd_scripts_1_11_1)
-------------

-   2010-08-27 Marcel Huber

    * passing waitcount to stopscript when it is not controlled by keepwds.sh



-   2010-08-27 Marcel Huber

    * passing waitcount to stopscript when using restart



-   2010-08-27 Marcel Huber

    * corrected handling of space separated strings  - changed due to new bash
    behavior



-   2010-08-27 Marcel Huber

    * removed dos-like line break



-   2010-08-27 Marcel Huber

    * removed echo



-   2010-08-27 Marcel Huber

    * added option to unset vars if needed



-   2010-08-27 Marcel Huber

    creating WD_LIBDIR if it was not existing already



-   2010-08-27 Marcel Huber

    * evaluation of runtest arguments postponed



-   2010-08-27 Marcel Huber

    * corrected prependPath flipping order of segments



-   2010-08-27 Marcel Huber

    * not all options were correctly passed to subscript



-   2010-08-27 Marcel Huber

    * append/prependPath allow adding multiple segments at once



-   2010-08-27 Marcel Huber

    * changed from using param 1 as DEV-Env to specifying it as -E option *
    factored out variable cleaning into sysfuncs.sh



-   2008-05-23 Marcel Huber

    ignoring output of cd



-   2010-08-27 Marcel Huber

    * corrected extending LD_LIBRARY_PATH when running test executable



-   2010-08-27 Marcel Huber

    * corrected MYNAME setting



-   2010-08-27 Marcel Huber

    * corrected settings when using wdenv.sh



-   2010-08-27 Marcel Huber

    * re-enabled global var



-   2010-08-27 Marcel Huber

    * made some variables local, not to fill env with temporaries



-   2010-08-27 Marcel Huber

    * added new function to select gnu compiler to use prior to selecting
    working environment * added function to insert segments into path like
    variables sorted by string



-   2008-05-22 Marcel Huber

    added shell funtion to make a given path absolute



-   2010-08-27 Marcel Huber

    * not aborting script when RUN_USER or USER env var is empty



-   2010-08-27 Marcel Huber

    * added function to extend LD_LIBRARY_PATH using .ld-search-path if
    available  - this is needed when using non standard locations of libraries
    supplied by compiler



-   2010-08-27 Marcel Huber

    * corrected server stopping by adding some printf lines...


Release (tag: wd_scripts_1_9)
-------------

-   2010-08-27 Marcel Huber

    * changed back to using relative application name when starting
    server/application  - reduces risk of not finding application in ps list
    due to string truncation after 80 characters



-   2010-08-27 Marcel Huber

    * corrected application string to check for  - added SERVERNAME after wdapp
    to find correct application


Release (tag: wd_scripts_1_8)
-------------

-   2010-08-27 Marcel Huber

    * changed to using absolute binary filename when starting wdserver



-   2010-08-27 Marcel Huber

    * increased wait count when stopping server



-   2010-08-27 Marcel Huber

    * added another param to SearchJoinedDir funtion



-   2008-05-13 Marcel Huber

    prepending content of .ld-search-path to LD_LIBRARY_PATH if available
    ensures taking correct libraries first



-   2010-08-27 Marcel Huber

    * quieting cd -



-   2010-08-27 Marcel Huber

    * added test if directory pattern to test is an existing one before
    selecting it



-   2010-08-27 Marcel Huber

    * changed way how to find config directory * removed FINDOPT vars * when
    testing for gnu tool, testing both names for being a gnu tool



-   2010-08-27 Marcel Huber

    * corrected code to find valid config directory  - find is not the best
    choice to search a local directory based on wildcards because it might
    descend and find a good match first


Release (tag: wd_scripts_1_7)
-------------

-   2008-03-03 Marcel Huber

    * added option to let application run in foreground within gdb  - run needs
    to be typed manually though



-   2010-08-27 Marcel Huber

    * extended generation of gdb command file to allow use by startwda.sh *
    corrected run command to not supply app and args as already defined


Release (tag: wd_scripts_1_6)
-------------

-   2008-01-28 Marcel Huber

    initializing replace string to emptyness



-   2010-08-27 Marcel Huber

    * WD_OUTDIR path changed  - a unique path for every user will now being
    generated at a level where it should not interfer with other users base
    level directory permissions



-   2010-08-27 Marcel Huber

    * added missing TRACE_STORAGE description for level 3



-   2010-08-27 Marcel Huber

    * corrected passing of server arguments to generating gdb commands file



-   2007-04-27 Marcel Huber

    corrected gdb parameters


Release (tag: wd_scripts_1_4)
-------------

-   2010-08-27 Marcel Huber

    * added another default entry to be used when a server should be run under
    control of gdb  - this is useful if the server crashes unexpectedly and can
    not be started using startwds.sh -d



-   2010-08-27 Marcel Huber

    * added evalutation of RUN_ATTACHED_TO_GDB variable  - this flag can be
    specified within prjconfig.sh instead of specifying the -d option


Release (tag: wd_scripts_1_3)
-------------

-   2010-08-27 Marcel Huber

    * added default flag entries for MMAP stream control and Storage tracing


Release (tag: wd_scripts_1_2)
-------------

-   2010-08-27 Marcel Huber

    * improved output messages when not executing script due to RUN_SERVICE=0
    setting



-   2007-03-07 Marcel Huber

    added shell function to get out the value of an environment variable being
    set from within a script file



-   2007-03-06 Marcel Huber

    removed setting of LD_RUN_PATH to reduce 'hardcoded' references to
    directories



-   2010-08-27 Marcel Huber

    * removed LD_ASSUME_KERNEL because it does not solve the GLIBC problem on
    all Linux systems  - instead, you need a set of 'old' glibc libraries to
    use for starting these non-conforming applications  -> see sniff_wrapper
    script to see how it is done



-   2006-09-27 Marcel Huber

    changed to using InitFinisManager functions optical improvement



-   2010-08-27 Marcel Huber

    * added setting of LD_RUN_PATH  - prevents libraries to get loaded from the
    wrong path


Release (tag: wd_scripts_1_1)
-------------

-   2010-08-27 Marcel Huber

    * improved relative start handling again



-   2010-08-27 Marcel Huber

    * adjusted setting of relative pathname



-   2010-08-27 Marcel Huber

    * corrected project path setting when we start relative



-   2010-08-27 Marcel Huber

    * made creation of log/rotate directory dependant on cfg_doLog flag



-   2006-08-08 Marcel Huber

    apply path cleaning on config directory



-   2010-08-27 Marcel Huber

    * only calling preare/run/cleanup test functions if checkTestExe returned 1



-   2010-08-27 Marcel Huber

    * changed -e and -s options to take logging level parameter  - see help or
    SysLog.h



-   2010-08-27 Marcel Huber

    * removed WD_LOGONCERR setting



-   2010-08-27 Marcel Huber

    * arithmetic expressions using $(( )) does not work in regular shell  -
    replaced using expr program



-   2010-08-27 Marcel Huber

    * corrected test expression * added function to wait on server termination



-   2010-08-27 Marcel Huber

    changed from find to shell expansion to find directories matching a pattern


Release (tag: wd_scripts_1_0)
-------------

-   2006-03-14 Marcel Huber

    modified and added files



-   2005-01-01 Marcel Huber

    Initial hsr commit



-   2002-10-15 Marcel Huber

    * added setting of mypath variable



-   2002-10-15 Marcel Huber

    * corrected find using scripts



-   2002-10-15 Marcel Huber

    * new way of using 'correct' find



-   2002-10-15 Marcel Huber

    * using predefined mypath variable



-   2002-10-14 Marcel Huber

    * template for preDoallFunc added



-   2002-10-14 Marcel Huber

    * added support for external preDoallFunc  - function can be used to
    increment a build number for example



-   2002-10-14 Marcel Huber

    * sourcing bugfix  - when script was sourced from within another script the
    path was not set correctly



-   2002-09-30 Marcel Huber

    * removed misplaced local definitions



-   2002-09-25 Marcel Huber

    * adjusted directory and filename creation



-   2002-09-25 Marcel Huber

    * corrected base path for directory creation



-   2002-09-25 Marcel Huber

    * correction for CvsLog.sh



-   2002-09-23 Marcel Huber

    * bugfix: file-loading error  - sourced scripts was not able to load
    /home/scripts/sysfuncs.sh because    it was located in
    /home/webdisplay/scripts  - now it checks the value of the SCRIPTS_DIR
    variable for the directory    and uses /home/scripts only as fallback



-   2002-09-16 Marcel Huber

    * bugfix: due to some renaming in install.sh the   variables
    INSTALLDIRABS/REL were not defined anymore



-   2002-09-11 Marcel Huber

    * trailing whitespace cleanup



-   2002-09-04 Marcel Huber

    * bugfix: pattern for matching config token corrected



-   2002-09-04 Marcel Huber

    * added switch to define config directory to work with  - results in
    setting WD_PATH internally



-   2002-08-28 Marcel Huber

    * move setting of mypath before showhelp function * not switching scripts
    directory anymore



-   2002-08-28 Marcel Huber

    * corrected creation of log/rotate, using LOGDIR value now



-   2002-08-28 Marcel Huber

    * move setting of mypath before showhelp function



-   2002-08-28 Marcel Huber

    * corrected setting of WD_PATH when it was empty



-   2002-08-27 Marcel Huber

    * latest itopia changes



-   2002-08-08 Marcel Huber

    * corrected DOS line endings...



-   2002-08-08 Marcel Huber

    * latest changes from itopia merged in



-   2002-07-17 ham

    * Switch zwischen den Instanzen mit Authentisierung



-   2002-07-11 ham

    *** empty log message ***



-   2002-07-11 Marcel Huber

    * corrected recursive loop when PERFTESTDIR is empty



-   2002-07-11 Marcel Huber

    * newest script files



-   2002-07-02 zar

    * sorry kurt



-   2002-06-27 zar

    *** empty log message ***



-   2002-06-27 euk

    - kleine hilfe für Tomi



-   2002-06-26 euk

    script um zwischen den Konfigs zu wechseln



-   2002-05-13 ham

    * 3.9 zeugs entfernt



-   2002-02-21 Marcel Huber

    * lot of optimizing project and file structures



-   2001-08-20 Marcel Huber

    removed creation of log directory



-   2001-07-26 Marcel Huber

    added text on which files we act



-   2001-07-26 Marcel Huber

    added text to which configuration we switch to



-   2001-07-26 Marcel Huber

    added more signal handlers



-   2001-07-25 Marcel Huber

    added support for WD_LIBDIR



-   2001-07-25 Marcel Huber

    added DEV_HOME variant to automatically build a project



-   2001-04-05 Marcel Huber

    Initial revision

