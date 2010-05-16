#!/usr/bin/env perl

print <<'WHOAH';
************************************************************************
* WHOA THERE!!!                                                        *
*                                                                      *
* This is *NOT* how you should build perl. Stop this script right now  *
* and use ./Configure. See the INSTALL file for more info.             *
*                                                                      *
* This is *only* here as a thin wrapper around Configure for automated *
* smoke testing.                                                       *
*                                                                      *
*                       Sleeping for 10 seconds and then continuing... *
************************************************************************
WHOAH

sleep 10;

system $^X => qw[./Configure -Dusedevel -Dusethreads -d -e -s];
