BEGIN {
  push @INC, './lib';
  require 'regen_lib.pl';
}
use strict;
my %alias_to = (
    U32 => [qw(line_t)],
    PADOFFSET => [qw(STRLEN SSize_t)],
    U16 => [qw(OPCODE short)],
    U8  => [qw(char)],
);

my (%alias_from, $from, $tos);
while (($from, $tos) = each %alias_to) {
    map { $alias_from{$_} = $from } @$tos;
}

my $c_header = <<'EOT';
/* -*- buffer-read-only: t -*-
 *
 *      Copyright (c) 1996-1999 Malcolm Beattie
 *
 *      You may distribute under the terms of either the GNU General Public
 *      License or the Artistic License, as specified in the README file.
 *
 */
/*
 * This file is autogenerated from bytecode.pl. Changes made here will be lost.
 */
EOT

my $perl_header;
($perl_header = $c_header) =~ s{[/ ]?\*/?}{#}g;

safer_unlink "ext/B/B/Asmdata.pm";

#
# Start with boilerplate for Asmdata.pm
#
open(ASMDATA_PM, ">ext/B/B/Asmdata.pm") or die "ext/B/B/Asmdata.pm: $!";
binmode ASMDATA_PM;
print ASMDATA_PM $perl_header, <<'EOT';
package B::Asmdata;

our $VERSION = '1.02';

use Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(%insn_data @insn_name @optype @specialsv_name);
our(%insn_data, @insn_name);

use B qw(@optype @specialsv_name);
EOT
print ASMDATA_PM <<"EOT";

# XXX insn_data is initialised this way because with a large
# %insn_data = (foo => [...], bar => [...], ...) initialiser
# I get a hard-to-track-down stack underflow and segfault.
EOT

my (@insn_name, $insn_num, $insn, $lvalue, $argtype, $flags, $fundtype);

while (<DATA>) {
    if (/^\s*#/) {
	next;
    }
    chop;
    next unless length;
    if (/^%number\s+(.*)/) {
	$insn_num = $1;
	next;
    } elsif (/%enum\s+(.*?)\s+(.*)/) {
	create_enum($1, $2);	# must come before instructions
	next;
    }
    ($insn, $lvalue, $argtype, $flags) = split;
    my $rvalcast = '';
    if ($argtype =~ m:(.+)/(.+):) {
	($rvalcast, $argtype) = ("($1)", $2);
    }
    $insn_name[$insn_num] = $insn;
    $fundtype = $alias_from{$argtype} || $argtype;

    #
    # Add the initialiser line for %insn_data in Asmdata.pm
    #
    print ASMDATA_PM <<"EOT";
\$insn_data{$insn} = [$insn_num, \\&PUT_$fundtype, "GET_$fundtype"];
EOT

    # Find the next unused instruction number
    do { $insn_num++ } while $insn_name[$insn_num];
}

#
# Finish off insn_data and create array initialisers in Asmdata.pm
#
print ASMDATA_PM <<'EOT';

my ($insn_name, $insn_data);
while (($insn_name, $insn_data) = each %insn_data) {
    $insn_name[$insn_data->[0]] = $insn_name;
}
# Fill in any gaps
@insn_name = map($_ || "unused", @insn_name);

1;

__END__

=head1 NAME

B::Asmdata - Autogenerated data about Perl ops

=head1 SYNOPSIS

	use B::Asmdata qw(%insn_data @insn_name @optype @specialsv_name);

=head1 DESCRIPTION

Provides information about Perl ops in order to generate bytecode via
a bunch of exported variables.  Its mostly used by B::Assembler and
B::Disassembler.

=over 4

=item %insn_data

  my($bytecode_num, $put_sub, $get_meth) = @$insn_data{$op_name};

For a given $op_name (for example, 'cop_label', 'sv_flags', etc...) 
you get an array ref containing the bytecode number of the op, a
reference to the subroutine used to 'PUT', and the name of the method
used to 'GET'.

=for _private
Add more detail about what $put_sub and $get_meth are and how to use them.

=item @insn_name

  my $op_name = $insn_name[$bytecode_num];

A simple mapping of the bytecode number to the name of the op.
Suitable for using with %insn_data like so:

  my $op_info = $insn_data{$insn_name[$bytecode_num]};

=item @optype

  my $op_type = $optype[$op_type_num];

A simple mapping of the op type number to its type (like 'COP' or 'BINOP').

=item @specialsv_name

  my $sv_name = $specialsv_name[$sv_index];

Certain SV types are considered 'special'.  They're represented by
B::SPECIAL and are referred to by a number from the specialsv_list.
This array maps that number back to the name of the SV (like 'Nullsv'
or '&PL_sv_undef').

=back

=head1 AUTHOR

Malcolm Beattie, C<mbeattie@sable.ox.ac.uk>

=cut

# ex: set ro:
EOT


close ASMDATA_PM or die "Error closing ASMDATA_PM: $!";

__END__
# First set instruction ord("#") to read comment to end-of-line (sneaky)
%number 35
comment		arg			comment_t
# Then make ord("\n") into a no-op
%number 10
nop		none			none

# Now for the rest of the ordinary ones, beginning with \0 which is
# ret so that \0-terminated strings can be read properly as bytecode.
%number 0
#
# The argtype is either a single type or "rightvaluecast/argtype".
#
#opcode		lvalue					argtype		flags	
#
ret		none					none		x
ldsv		bstate->bs_sv				svindex
ldop		PL_op					opindex
stsv		bstate->bs_sv				U32		s
stop		PL_op					U32		s
stpv		bstate->bs_pv.pvx			U32		x
ldspecsv	bstate->bs_sv				U8		x
ldspecsvx	bstate->bs_sv				U8		x
newsv		bstate->bs_sv				svtype		x
newsvx		bstate->bs_sv				svtype		x
newop		PL_op					U8		x
newopx		PL_op					U16		x
newopn		PL_op					U8		x
newpv		none					PV
pv_cur		bstate->bs_pv.xpv.xpv_cur		STRLEN
pv_free		bstate->bs_pv.pvx			none		x
sv_upgrade	bstate->bs_sv				svtype		x
sv_refcnt	SvREFCNT(bstate->bs_sv)			U32
sv_refcnt_add	SvREFCNT(bstate->bs_sv)			I32		x
sv_flags	SvFLAGS(bstate->bs_sv)			U32
xrv		bstate->bs_sv				svindex		x
xpv		bstate->bs_sv				none		x
xpv_cur		bstate->bs_sv	 			STRLEN		x
xpv_len		bstate->bs_sv				STRLEN		x
xiv		bstate->bs_sv				IV		x
xnv		bstate->bs_sv				NV		x
xlv_targoff	LvTARGOFF(bstate->bs_sv)		STRLEN
xlv_targlen	LvTARGLEN(bstate->bs_sv)		STRLEN
xlv_targ	LvTARG(bstate->bs_sv)			svindex
xlv_type	LvTYPE(bstate->bs_sv)			char
xbm_useful	BmUSEFUL(bstate->bs_sv)			I32
xbm_previous	BmPREVIOUS(bstate->bs_sv)		U16
xbm_rare	BmRARE(bstate->bs_sv)			U8
xfm_lines	FmLINES(bstate->bs_sv)			IV
xio_lines	IoLINES(bstate->bs_sv)			IV
xio_page	IoPAGE(bstate->bs_sv)			IV
xio_page_len	IoPAGE_LEN(bstate->bs_sv)		IV
xio_lines_left	IoLINES_LEFT(bstate->bs_sv)	       	IV
xio_top_name	IoTOP_NAME(bstate->bs_sv)		pvindex
xio_top_gv	*(SV**)&IoTOP_GV(bstate->bs_sv)		svindex
xio_fmt_name	IoFMT_NAME(bstate->bs_sv)		pvindex
xio_fmt_gv	*(SV**)&IoFMT_GV(bstate->bs_sv)		svindex
xio_bottom_name	IoBOTTOM_NAME(bstate->bs_sv)		pvindex
xio_bottom_gv	*(SV**)&IoBOTTOM_GV(bstate->bs_sv)	svindex
xio_subprocess	IoSUBPROCESS(bstate->bs_sv)		short
xio_type	IoTYPE(bstate->bs_sv)			char
xio_flags	IoFLAGS(bstate->bs_sv)			char
xcv_xsubany	*(SV**)&CvXSUBANY(bstate->bs_sv).any_ptr	svindex
xcv_stash	*(SV**)&CvSTASH(bstate->bs_sv)		svindex
xcv_start	CvSTART(bstate->bs_sv)			opindex
xcv_root	CvROOT(bstate->bs_sv)			opindex
xcv_gv		*(SV**)&CvGV(bstate->bs_sv)		svindex
xcv_file	CvFILE(bstate->bs_sv)			pvindex
xcv_depth	CvDEPTH(bstate->bs_sv)			long
xcv_padlist	*(SV**)&CvPADLIST(bstate->bs_sv)	svindex
xcv_outside	*(SV**)&CvOUTSIDE(bstate->bs_sv)	svindex
xcv_outside_seq	CvOUTSIDE_SEQ(bstate->bs_sv)		U32
xcv_flags	CvFLAGS(bstate->bs_sv)			U16
av_extend	bstate->bs_sv				SSize_t		x
av_pushx	bstate->bs_sv				svindex		x
av_push		bstate->bs_sv				svindex		x
xav_fill	AvFILLp(bstate->bs_sv)			SSize_t
xav_max		AvMAX(bstate->bs_sv)			SSize_t
xhv_riter	HvRITER(bstate->bs_sv)			I32
xhv_name	bstate->bs_sv				pvindex		x
hv_store	bstate->bs_sv				svindex		x
sv_magic	bstate->bs_sv				char		x
mg_obj		SvMAGIC(bstate->bs_sv)->mg_obj		svindex
mg_private	SvMAGIC(bstate->bs_sv)->mg_private	U16
mg_flags	SvMAGIC(bstate->bs_sv)->mg_flags	U8
mg_name		SvMAGIC(bstate->bs_sv)			pvcontents	x
mg_namex	SvMAGIC(bstate->bs_sv)			svindex		x
xmg_stash	bstate->bs_sv				svindex		x
gv_fetchpv	bstate->bs_sv				strconst	x
gv_fetchpvx	bstate->bs_sv				strconst	x
gv_stashpv	bstate->bs_sv				strconst	x
gv_stashpvx	bstate->bs_sv				strconst	x
gp_sv		GvSV(bstate->bs_sv)			svindex
gp_refcnt	GvREFCNT(bstate->bs_sv)			U32
gp_refcnt_add	GvREFCNT(bstate->bs_sv)			I32		x
gp_av		*(SV**)&GvAV(bstate->bs_sv)		svindex
gp_hv		*(SV**)&GvHV(bstate->bs_sv)		svindex
gp_cv		*(SV**)&GvCV(bstate->bs_sv)		svindex
gp_file		bstate->bs_sv				pvindex		x
gp_io		*(SV**)&GvIOp(bstate->bs_sv)		svindex
gp_form		*(SV**)&GvFORM(bstate->bs_sv)		svindex
gp_cvgen	GvCVGEN(bstate->bs_sv)			U32
gp_line		GvLINE(bstate->bs_sv)			line_t
gp_share	bstate->bs_sv				svindex		x
xgv_flags	GvFLAGS(bstate->bs_sv)			U8
op_next		PL_op->op_next				opindex
op_sibling	PL_op->op_sibling			opindex
op_ppaddr	PL_op->op_ppaddr			strconst	x
op_targ		PL_op->op_targ				PADOFFSET
op_type		PL_op					OPCODE		x
op_opt		PL_op->op_opt				U8
op_static	PL_op->op_static			U8
op_flags	PL_op->op_flags				U8
op_private	PL_op->op_private			U8
op_first	cUNOP->op_first				opindex
op_last		cBINOP->op_last				opindex
op_other	cLOGOP->op_other			opindex
op_pmreplroot	cPMOP->op_pmreplroot			opindex
op_pmreplstart	cPMOP->op_pmreplstart			opindex
op_pmnext	*(OP**)&cPMOP->op_pmnext		opindex
#ifdef USE_ITHREADS
op_pmstashpv	cPMOP					pvindex		x
op_pmreplrootpo	cPMOP->op_pmreplroot			OP*/PADOFFSET
#else
op_pmstash	*(SV**)&cPMOP->op_pmstash		svindex
op_pmreplrootgv	*(SV**)&cPMOP->op_pmreplroot		svindex
#endif
pregcomp	PL_op					pvcontents	x
op_pmflags	cPMOP->op_pmflags			U16
op_sv		cSVOP->op_sv				svindex
op_padix	cPADOP->op_padix			PADOFFSET
op_pv		cPVOP->op_pv				pvcontents
op_pv_tr	cPVOP->op_pv				op_tr_array
op_redoop	cLOOP->op_redoop			opindex
op_nextop	cLOOP->op_nextop			opindex
op_lastop	cLOOP->op_lastop			opindex
cop_label	cCOP->cop_label				pvindex
#ifdef USE_ITHREADS
cop_stashpv	cCOP					pvindex		x
cop_file	cCOP					pvindex		x
#else
cop_stash	cCOP					svindex		x
cop_filegv	cCOP					svindex		x
#endif
cop_seq		cCOP->cop_seq				U32
cop_arybase	cCOP					I32		x
cop_line	cCOP->cop_line				line_t
cop_warnings	cCOP					svindex		x
main_start	PL_main_start				opindex
main_root	PL_main_root				opindex
main_cv		*(SV**)&PL_main_cv			svindex
curpad		PL_curpad				svindex		x
push_begin	PL_beginav				svindex		x
push_init	PL_initav				svindex		x
push_end	PL_endav				svindex		x
curstash	*(SV**)&PL_curstash			svindex
defstash	*(SV**)&PL_defstash			svindex
data		none					U8		x
incav		*(SV**)&GvAV(PL_incgv)			svindex
load_glob	none					svindex		x
#ifdef USE_ITHREADS
regex_padav	*(SV**)&PL_regex_padav			svindex
#endif
dowarn		PL_dowarn				U8
comppad_name	*(SV**)&PL_comppad_name			svindex
xgv_stash	*(SV**)&GvSTASH(bstate->bs_sv)		svindex
signal		bstate->bs_sv				strconst	x
# to be removed
formfeed	PL_formfeed				svindex
