#     PREREQ_PM => { base=>q[0], List::Util=>q[0], Scalar::Util=>q[0], strict=>q[0], Test::More=>q[0], warnings=>q[0], File::Spec=>q[0], strict=>q[0], warnings=>q[0], Symbol=>q[0], Carp=>q[0] }

all : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1
realclean : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 realclean
	/usr/bin/perl -e '1 while unlink $$ARGV[0]' Makefile

force_do_it :
	@ true
build : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 build
clean : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 clean
code : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 code
config_data : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 config_data
diff : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 diff
dist : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 dist
distcheck : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 distcheck
distclean : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 distclean
distdir : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 distdir
distmeta : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 distmeta
distruntest : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 distruntest
distsign : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 distsign
disttest : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 disttest
docs : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 docs
fakeinstall : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 fakeinstall
help : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 help
html : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 html
install : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 install
manifest : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 manifest
manpages : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 manpages
pardist : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 pardist
ppd : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 ppd
ppmdist : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 ppmdist
prereq_report : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 prereq_report
pure_install : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 pure_install
retest : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 retest
runtest : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 runtest
skipcheck : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 skipcheck
tags : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 tags
test : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 test
testall : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 testall
testcover : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 testcover
testdb : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 testdb
testpod : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 testpod
testpodcoverage : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 testpodcoverage
versioninstall : force_do_it
	/usr/bin/perl Build --makefile_env_macros 1 versioninstall

.EXPORT : INC INSTALLSITELIB DESTDIR PREFIX VERBINST INSTALLDIRS TEST_VERBOSE INSTALLPERLLIB UNINST INSTALL_BASE POLLUTE INSTALLVENDORLIB

