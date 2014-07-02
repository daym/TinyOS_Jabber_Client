#
# Microcontroller VL
#
# Makefile for generating the lab protocol
#
# Author: Bettina Weiss
#
# Date:         16.06.2006
#
# TU Vienna, Embedded Computing Systems Group
#
# Targets:
#	(default)	generates .dvi, .ps, .pdf files
#	protocol	generates .dvi, .ps, .pdf files
#	print		prints the title page (you need to sign it!)
#
#	help		lists all possible targets
#	clean		removes intermediate files
#

#!/bin/bash


PROJECT = Protocol

all: Protocol.pdf

#------------------------------------------------------------------------------
Protocol.pdf: ExerciseMacros.tex  loudness.tex  ProtocolHeader.tex Protocol.tex loudness.pdf
#------------------------------------------------------------------------------
	pdflatex $(PROJECT)
	pdflatex $(PROJECT)

loudness.pdf: loudness.eps
	epstopdf --outfile=$@ $<
	
loudness.eps loudness.tex: loudness.plot
	gnuplot $<

#------------------------------------------------------------------------------
print: protocol
#------------------------------------------------------------------------------
	psselect -p1 $(PROJECT).ps | lpr


#------------------------------------------------------------------------------
help:
#------------------------------------------------------------------------------
	@echo -e "\n>>> the following targets are available <<<"
	@echo -e "\t(default) \t generates .pdf file"
	@echo -e "\tprotocol \t generates .pdf file"
	@echo -e "\tprint \t\t print the title page (you need to sign it!)"
	@echo -e "\n\thelp \t\t list this text"
	@echo -e "\tclean \t\t remove temporary files"

#------------------------------------------------------------------------------
clean:
#------------------------------------------------------------------------------
	rm -f -- *.aux *.log *.toc loudness.tex loudness.eps

distclean: clean
