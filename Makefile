
# Quick start, install stack
# ( https://github.com/commercialhaskell/stack/blob/master/doc/install_and_upgrade.md )
#
# then use:
#
# make test
#
# this will build the library and run the tests.
#
# To build everything:
#
# make really-all

# you can use stack commands directly, but be aware that just using
# stack without the Makefile won't regenerate the AstInternal.hs from
# the .ag files automatically (you only need this if you alter the .ag
# files or if you are working on the pre/processing code for the
# AstInternal.hs

# build tested with ghc 7.10.2 on 181115
# also tested recently with 7.8.4
# probably needs a few simple tweaks to get working with 7.6.3

##############################################################################

# the default target
# the main use of this target is to check everything still compiles
# successfully

.PHONY : all
.DEFAULT : all
all : examples test

# the test target can be used when working on hssqlppp and also
# doesn't need postgres client drivers

.PHONY : test
test : hssqlppp
	stack test hssqlppp hssqlppp-th

# if you need some other combination of targets please add them to the
# makefile

# this does everything, make sure you've done all the sandbox targets
.PHONY : really-all
really-all : test #website
	stack build

##############################################################################

# building the components

# the project is separated into several separate cabal projects. Some
# of these are intended to end up on hackage: hssqlppp, hssqlppp-th
# and hssqlppp-pg, and the others are just for developing hssqlppp
# itself

.PHONY : hssqlppp
hssqlppp : hssqlppp/src/Database/HsSqlPpp/Internals/AstInternal.hs
	stack build hssqlppp

.PHONY : hssqlppp-th
hssqlppp-th : hssqlppp
	stack build hssqlppp-th

.PHONY : hssqlppp-pg
hssqlppp-pg : hssqlppp-th
	stack build hssqlppp-pg

.PHONY : examples
examples : hssqlppp
	stack build hssqlppp-examples

##############################################################################

# generated files

# hssqlppp/src/Database/HsSqlPpp/Internals/AstInternal.hs
# generated from the .ag files under hssqlppp/src/Database/HsSqlPpp/Internals/

# specific rules for generated file astinternal.hs
AG_FILES = $(shell find hssqlppp/src -iname '*ag')

hssqlppp/src/Database/HsSqlPpp/Internals/AstInternal.hs : $(AG_FILES)
	stack exec uuagc -- -dcfspwm \
	        -P hssqlppp/src/Database/HsSqlPpp/Internals/ \
		--lckeywords --doublecolons --genlinepragmas \
		hssqlppp/src/Database/HsSqlPpp/Internals/AstInternal.ag
	stack build hssqlppp-postprocess-uuagc:PostprocessUuagc
	stack exec PostprocessUuagc
	# prefix all the generated stuff with _
	# so we don't get loads of unused function warnings
	sed -r -i -e "s/([a-zA-Z0-9_]*_(Inh|Syn)_[a-zA-Z0-9_]*)/_\1/g" -e "s/((sem|wrap)_[a-zA-Z0-9_]*)/_\1/g" hssqlppp/src/Database/HsSqlPpp/Internals/AstInternal.hs
#	sed -r -i -e "s/\b([^ ]*_(Inh|Syn)_[^ ]*)\b/_\1/" -e "s/\b((Inh|Syn|sem|wrap)_[^ ]*)/_\1/" hssqlppp/src/Database/HsSqlPpp/Internals/AstInternal.hs

# hssqlppp/src/Database/HsSqlPpp/Dialects/GeneratedPostgres.lhs
# don't want to automatically keep this up to date, only regenerate it
# manually

.PHONY : generatePostgresCatalog
generatePostgresCatalog :
	stack build hssqlppp-build-extras:GeneratePostgresCatalog
	stack exec GeneratePostgresCatalog > \
		hssqlppp/src/Database/HsSqlPpp/Dialects/GeneratedPostgres.lhs_new
	mv hssqlppp/src/Database/HsSqlPpp/Dialects/GeneratedPostgres.lhs_new \
		hssqlppp/src/Database/HsSqlPpp/Dialects/GeneratedPostgres.lhs

##############################################################################

# building the tarballs for hackage. Maybe there should be more
# support here, for automated checking and uploading, to document the
# process and make it more difficult to miss a step?

# todo: use stack here

# .PHONY : sdists
# sdists :
# 	cd hssqlppp; cabal sdist
# 	cd hssqlppp-th; cabal sdist
# 	cd hssqlppp-pg; cabal sdist

# .PHONY : check-sdists
# check-sdists : sdists
# 	-rm -Rf /tmp/hssqlppp*
# 	cd hssqlppp; sh ~/.cabal/share/cabal-scripts-0.1/cabal-test \
#           dist/hssqlppp-0.5.16.tar.gz
# 	cd hssqlppp-th; sh ~/.cabal/share/cabal-scripts-0.1/cabal-test \
#           dist/hssqlppp-th-0.5.16.tar.gz
# 	cd hssqlppp-pg; sh ~/.cabal/share/cabal-scripts-0.1/cabal-test \
#           dist/hssqlppp-pg-0.5.16.tar.gz


##############################################################################

# cleaning targets

.PHONY : clean
clean :
	stack clean
	rm -Rf build


##############################################################################

# rebuilding the website. You probably won't need to use this

#.PHONY : website-all
#website-all : website-static website-generated website-haddock

#.PHONY : website-static

#.PHONY : make-website/dist/build/MakeWebsite/MakeWebsite
#make-website/dist/build/MakeWebsite/MakeWebsite :
#	cd make-website && cabal build -j

# make the website

# .PHONY : website
# website : #make-website/dist/build/MakeWebsite/MakeWebsite \
#   #build/website/main.css
# 	mkdir -p build/website
# 	asciidoctor website-source/index.asciidoc -o - | runhaskell website-source/AddLinks.lhs > build/website/index.html
# 	asciidoctor website-source/examples.asciidoc -o - | runhaskell website-source/AddLinks.lhs > build/website/examples.html
# 	#make-website/dist/build/MakeWebsite/MakeWebsite
# 	#asciidoctor build/website/ParserTests.asciidoc -o build/website/ParserTests.html
# 	#asciidoctor build/website/TypeCheckTests.asciidoc -o build/website/TypeCheckTests.html
# 	#asciidoctor build/website/QuasiQuoteTests.asciidoc -o build/website/QuasiQuoteTests.html

# 	#mv build/website/index.txt.html build/website/index.html

# DIAGRAM_SRC_FILES=$(shell ls hssqlppp/src/Database/HsSqlPpp/*.lhs)

# build/website/hssqlppp-src.svg : $(DIAGRAM_SRC_FILES)
# 	mkdir -p build/website
# 	graphmod -i ~/wd/hssqlppp/master/hssqlppp/src $(DIAGRAM_SRC_FILES) \
# 	    -a -R Text -R Control -R Data -r Prelude \
# 	    > build/website/hssqlppp-src.dot
# 	dot -Tsvg build/website/hssqlppp-src.dot -o build/website/hssqlppp-src.svg

# build/website/main.css : website-source/main.css
# 	-mkdir -p build/website/
# 	cp website-source/main.css build/website/main.css

# make the haddock and put in the correct place in the generated
# website

# to build the full website you need the 'website' and the
# 'website-haddock' targets. These are kept separate so that when
# editing the website and rebuilding to check, you don't need to keep
# redoing the haddock as well which slows down the cycle.

# todo: fix the website targets (website, website-haddock, other
# smaller targets to do partial rebuilds when developing)

# .PHONY : website-haddock
# website-haddock :
# 	cd hssqlppp && cabal haddock
# 	-mkdir -p build/website
# 	-rm -Rf build/website/haddock
# 	cp -R hssqlppp/dist/doc/html/hssqlppp build/website/haddock

