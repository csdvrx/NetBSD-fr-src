%{
/*	$NetBSD: scan.l,v 1.35 2024/01/18 04:41:37 thorpej Exp $	*/

/*
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This software was developed by the Computer Systems Engineering group
 * at Lawrence Berkeley Laboratory under DARPA contract BG 91-66 and
 * contributed to Berkeley.
 *
 * All advertising materials mentioning features or use of this software
 * must display the following acknowledgement:
 *	This product includes software developed by the University of
 *	California, Lawrence Berkeley Laboratories.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	from: @(#)scan.l	8.1 (Berkeley) 6/6/93
 */

#include <sys/cdefs.h>
__RCSID("$NetBSD: scan.l,v 1.35 2024/01/18 04:41:37 thorpej Exp $");

#include <sys/param.h>
#include <errno.h>
#include <libgen.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stddef.h>
#include <ctype.h>
#include <util.h>
#undef ECHO
#include "defs.h"
#include "gram.h"

int	yyline;
const char *yyfile;
const char *lastfile;
char curinclpath[PATH_MAX];
uint64_t ifdefstate;
int	 ifdefshift = -1;

/*
 * The state is represented by 3 bits.
 */
#define	IDS_ENABLED	1ll
#define	IDS_MATCH	2ll
#define	IDS_ELIF	4ll
#define	IDS_ELSE	8ll

#define	IDS_BITS	0xf
#define	IDS_SHIFT	4

#define	IDS_ISMATCH(st) (((st) & IDS_MATCH) != 0)
#define	IDS_ISENABLED(st) (((st) & IDS_ENABLED) != 0)
#define	IDS_PARENT_DISABLED \
	(ifdefshift > 0 && !IDS_ISENABLED(ifdefstate >> IDS_SHIFT))
#define IDS_MAX_DEPTH	16 /* 64 / 4 */

#ifdef	IDS_DEBUG
# define IDS_PRINT(s, st, x) \
	do { \
		for (int i = 0; i < ifdefshift + 1; i++) \
			fprintf(stderr, " "); \
		printf("%s%s [%d,%d,%d] %#" PRIx64 "\n", x, # s, \
		    IDS_PARENT_DISABLED, IDS_ISMATCH(st), getcurifdef(), \
		    ifdefstate); \
	} while (0)
#else
# define IDS_PRINT(s, st, x) ((void)0)
#endif

#define	IDS_ENTER(s, st) \
	IDS_PRINT(s, st, ">")
#define	IDS_EXIT(s, st) \
	IDS_PRINT(s, st, "<")

/*
 * Data for returning to previous files from include files.
 */
struct incl {
	struct	incl *in_prev;	/* previous includes in effect, if any */
	YY_BUFFER_STATE in_buf;	/* previous lex state */
	struct where in_where;
	int	in_ateof;	/* token to insert at EOF */
	int	in_interesting;	/* previous value for "interesting" */
	uint64_t	in_ifdefstate;	/* conditional level */
	int	in_ifdefshift;	/* conditional level */
};
static struct incl *incl;
static int endinclude(void);
static int getincludepath(void);
static int getcurifdef(void);

SLIST_HEAD(, prefix)	curdirs;	/* curdir stack */

%}

%option  noyywrap nounput noinput

PATH	[A-Za-z_0-9]*[./][-A-Za-z_0-9./]*
QCHARS	\"(\\.|[^\\"])*\" 
WORD	[A-Za-z_][-A-Za-z_0-9]*
FILENAME	({PATH}|{QCHARS})
RESTOFLINE	[ \t]*(#[^\n]*)?\n
WS	^[ \t]*

%x	IGNORED

%%
		/* Local variables for yylex() */
		int tok;

and		return AND;
at		return AT;
attach		return ATTACH;
block		return BLOCK;
build		return BUILD;
char		return CHAR;
compile-with	return COMPILE_WITH;
config		return CONFIG;
deffs		return DEFFS;
define		return DEFINE;
defflag		return DEFFLAG;
defopt		return DEFOPT;
defparam	return DEFPARAM;
defpseudo	return DEFPSEUDO;
defpseudodev	return DEFPSEUDODEV;
devclass	return DEVCLASS;
device		return DEVICE;
device-major	return DEVICE_MAJOR;
dumps		return DUMPS;
file		return XFILE;
file-system	return FILE_SYSTEM;
flags		return FLAGS;
ident		return IDENT;
ioconf		return IOCONF;
linkzero	return LINKZERO;
machine		return XMACHINE;
major		return MAJOR;
makeoptions	return MAKEOPTIONS;
mkflagvar	return MKFLAGVAR;
maxpartitions	return MAXPARTITIONS;
maxusers	return MAXUSERS;
minor		return MINOR;
needs-count	return NEEDS_COUNT;
needs-flag	return NEEDS_FLAG;
no		return NO;
-no		return CNO;
object		return XOBJECT;
obsolete	return OBSOLETE;
on		return ON;
options		return OPTIONS;
prefix		return PREFIX;
buildprefix	return BUILDPREFIX;
pseudo-device	return PSEUDO_DEVICE;
pseudo-root	return PSEUDO_ROOT;
root		return ROOT;
select		return SELECT;
single		return SINGLE;
source		return SOURCE;
type		return TYPE;
vector 		return VECTOR;
version 	return VERSION;
with		return WITH;

\+=		return PLUSEQ;
:=		return COLONEQ;

<*>{WS}ifdef[ \t]+{WORD}{RESTOFLINE} {
		ifdefstate <<= IDS_SHIFT;
		if (++ifdefshift >= IDS_MAX_DEPTH) {
			yyerror("too many levels of conditional");
		}
		IDS_ENTER(ifdef, 0);
		if (IDS_PARENT_DISABLED || !getcurifdef()) {
			ifdefstate &= (uint64_t)~IDS_ENABLED;
			BEGIN(IGNORED);
		} else {
			ifdefstate |= IDS_MATCH|IDS_ENABLED;
			BEGIN(INITIAL);
		}
		IDS_EXIT(ifdef, 0);
		yyline++;
	}

<*>{WS}ifndef[ \t]+{WORD}{RESTOFLINE} {
		ifdefstate <<= IDS_SHIFT;
		if (++ifdefshift >= IDS_MAX_DEPTH) {
			yyerror("too many levels of conditional");
		}
		IDS_ENTER(ifndef, 0);
		if (IDS_PARENT_DISABLED || getcurifdef()) {
			ifdefstate &= (uint64_t)~IDS_ENABLED;
			BEGIN(IGNORED);
		} else {
			ifdefstate |= IDS_MATCH|IDS_ENABLED;
			BEGIN(INITIAL);
		}
		IDS_EXIT(ifndef, 0);
		yyline++;
	}


<*>{WS}elifdef[ \t]+{WORD}{RESTOFLINE} {
		int st = ifdefstate & IDS_BITS;
		IDS_ENTER(elifdef, st);
		if (ifdefshift == -1 || (st & IDS_ELSE) != 0) {
			yyerror("mismatched elifdef");
		}
		if (IDS_PARENT_DISABLED || IDS_ISMATCH(st) || !getcurifdef()) {
			ifdefstate &= (uint64_t)~IDS_ENABLED;
			BEGIN(IGNORED);
		} else {
			ifdefstate |= IDS_MATCH|IDS_ENABLED;
			BEGIN(INITIAL);
		}
		ifdefstate |= IDS_ELIF;
		IDS_EXIT(elifdef, st);
		yyline++;
	}

<*>{WS}elifndef[ \t]+{WORD}{RESTOFLINE} {
		int st = ifdefstate & IDS_BITS;
		IDS_ENTER(elifndef, st);
		if (ifdefshift == -1 || (st & IDS_ELSE) != 0) {
			yyerror("mismatched elifndef");
		}
		if (IDS_PARENT_DISABLED || IDS_ISMATCH(st) || getcurifdef()) {
			ifdefstate &= (uint64_t)~IDS_ENABLED;
			BEGIN(IGNORED);
		} else {
			ifdefstate |= IDS_MATCH|IDS_ENABLED;
			BEGIN(INITIAL);
		}
		ifdefstate |= IDS_ELIF;
		IDS_EXIT(elifndef, st);
		yyline++;
	}

<*>{WS}else{RESTOFLINE} {
		int st = ifdefstate & IDS_BITS;
		IDS_ENTER(else, st);
		if (ifdefshift == -1 || (st & IDS_ELSE) != 0) {
			yyerror("mismatched else");
		}
		if (IDS_PARENT_DISABLED || IDS_ISMATCH(st)) {
			ifdefstate &= (uint64_t)~IDS_ENABLED;
			BEGIN(IGNORED);
		} else {
			ifdefstate |= IDS_MATCH|IDS_ENABLED;
			BEGIN(INITIAL);
		}
		ifdefstate |= IDS_ELSE;
		IDS_ENTER(else, st);
		yyline++;
	}

<*>{WS}endif{RESTOFLINE} {
		IDS_ENTER(endif, 0);
		if (ifdefshift == -1) {
			yyerror("mismatched endif");
		}
		if (!IDS_PARENT_DISABLED) {
			BEGIN(INITIAL);
		}
		IDS_EXIT(endif, 0);
		ifdefshift--;
		ifdefstate >>= IDS_SHIFT;
		yyline++;
	}

<IGNORED>\n		{
		yyline++;
	}

<IGNORED>.	/* ignore */

include[ \t]+{FILENAME}{RESTOFLINE}	{
		yyline++;
		if (getincludepath()) {
			include(curinclpath, 0, 0, 1);
		} else {
			yyerror("bad include path-name");
		}
	}

cinclude[ \t]+{FILENAME}{RESTOFLINE}	{
		yyline++;
		if (getincludepath()) {
			include(curinclpath, 0, 1, 1);
		} else {
			yyerror("bad cinclude path-name");
		}
	}

package[ \t]+{FILENAME}{RESTOFLINE}	{
		yyline++;
		if (!oktopackage) {
			yyerror("package not allowed here");
		} else if (getincludepath()) {
			package(curinclpath);
		} else {
			yyerror("bad package path-name");
		}
	}

{PATH}	{
		yylval.str = intern(yytext);
		return PATHNAME;
	}

{WORD}	{
		yylval.str = intern(yytext);
		return WORD;
	}

\"\" {
		yylval.str = intern("");
		return EMPTYSTRING;
	}

{QCHARS}	{
		size_t l = strlen(yytext);
		if (l > 1 && yytext[l - 1] == '"')
			yytext[l - 1] = '\0';

		yylval.str = intern(yytext + 1);
		return QSTRING;
	}
0[0-7]*	{
		yylval.num.fmt = 8;
		yylval.num.val = strtoll(yytext, NULL, 8);
		return NUMBER;
	}
0[xX][0-9a-fA-F]+ {
		yylval.num.fmt = 16;
		yylval.num.val = (long long)strtoull(yytext + 2, NULL, 16);
		return NUMBER;
	}
[1-9][0-9]* {
		yylval.num.fmt = 10;
		yylval.num.val = strtoll(yytext, NULL, 10);
		return NUMBER;
	}
\n[ \t] {
		/*
		 * Note: newline followed by whitespace is always a
		 * continuation of the previous line, so do NOT
		 * return a token in this case.
		 */
		yyline++;
	}
\n	{
		yyline++;
		return '\n';
	}
\00	{
		/* Detect NUL characters in the config file and
		 * error out.
		 */
		cfgerror("NUL character detected at line %i", yyline);
	}
#.*	{ /* ignored (comment) */; }
[ \t]+	{ /* ignored (white space) */; }
.	{ return yytext[0]; }
<*><<EOF>> {
		if (ifdefshift > (incl == NULL ? -1 : incl->in_ifdefshift)) {
			yyerror("reached EOF while looking for endif");
		}
		if (incl == NULL)
			return YY_NULL;
		tok = endinclude();
		if (tok)
			return tok;
		/* otherwise continue scanning */
	}

%%

int interesting = 1;

static int
curdir_push(const char *fname)
{
	struct prefix *pf;
	char *p, *d, *f;

	/* Set up the initial "current directory" for include directives. */
	d = dirname(f = estrdup(fname));
	if (*d == '/')
		p = estrdup(d);
	else {
		char *cwd, buf[PATH_MAX];

		if ((cwd = getcwd(buf, sizeof(buf))) == NULL) {
			free(f);
			return (-1);
		}
		easprintf(&p, "%s/%s", cwd, d);
	}
	free(f);
	pf = ecalloc(1, sizeof(*pf));
	pf->pf_prefix = p;
	SLIST_INSERT_HEAD(&curdirs, pf, pf_next);

	return (0);
}

static void
curdir_pop(void)
{
	struct prefix *pf;

	pf = SLIST_FIRST(&curdirs);
	SLIST_REMOVE_HEAD(&curdirs, pf_next);
	if (SLIST_EMPTY(&curdirs))
		panic("curdirs is empty");
	/* LINTED cast away const (pf_prefix is malloc'd for curdirs) */
	free((void *)__UNCONST(pf->pf_prefix));
	free(pf);
}

/*
 * Open the "main" file (conffile).
 */
int
firstfile(const char *fname)
{

#if defined(__NetBSD__)
	if ((yyin = fopen(fname, "rf")) == NULL)
#else
	if ((yyin = fopen(fname, "r")) == NULL)
#endif
		return (-1);

	if (curdir_push(fname) == -1)
		return (-1);

	yyfile = conffile = fname;
	yyline = 1;
	return (0);
}

/*
 * Add a "package" to the configuration.  This is essentially
 * syntactic sugar around the sequence:
 *
 *	prefix ../some/directory
 *	include "files.package"
 *	prefix
 */
void
package(const char *fname)
{
	char *fname1 = estrdup(fname);
	char *fname2 = estrdup(fname);
	char *dir = dirname(fname1);
	char *file = basename(fname2);

	/*
	 * Push the prefix on to the prefix stack and process the include
	 * file.  When we reach the end of the include file, inserting
	 * the PREFIX token into the input stream will pop the prefix off
	 * of the prefix stack.
	 */
	prefix_push(dir);
	(void) include(file, PREFIX, 0, 1);

	free(fname1);
	free(fname2);
}

int includedepth;

/*
 * Open the named file for inclusion at the current point.  Returns 0 on
 * success (file opened and previous state pushed), nonzero on failure
 * (fopen failed, complaint made).  The `ateof' parameter controls the
 * token to be inserted at the end of the include file (i.e. ENDFILE).
 * If ateof == 0 then nothing is inserted.
 */
int
include(const char *fname, int ateof, int conditional, int direct)
{
	FILE *fp;
	struct incl *in;
	char *s;
	static int havedirs;
	extern int vflag;

	if (havedirs == 0) {
		havedirs = 1;
		setupdirs();
	}

	if (fname[0] == '/')
		s = estrdup(fname);
	else if (fname[0] == '.' && fname[1] == '/') {
		struct prefix *pf = SLIST_FIRST(&curdirs);
		easprintf(&s, "%s/%s", pf->pf_prefix, fname + 2);
	} else
		s = sourcepath(fname);
	if ((fp = fopen(s, "r")) == NULL) {
		if (conditional == 0)
			cfgerror("cannot open %s for reading: %s", s,
			    strerror(errno));
		else if (vflag)
			cfgwarn("cannot open conditional include file %s: %s",
			     s, strerror(errno));
		free(s);
		return (-1);
	}
	if (curdir_push(s) == -1) {
		cfgerror("cannot record current working directory for %s", s);
		fclose(fp);
		free(s);
		return (-1);
	}
	in = ecalloc(1, sizeof *in);
	in->in_prev = incl;
	in->in_buf = YY_CURRENT_BUFFER;
	in->in_where.w_srcfile = yyfile;
	in->in_where.w_srcline = (u_short)yyline;
	in->in_ateof = ateof;
	in->in_interesting = interesting;
	in->in_ifdefstate = ifdefstate;
	in->in_ifdefshift = ifdefshift;
	interesting = direct & interesting;
	if (interesting)
		logconfig_include(fp, fname);
	incl = in;
	CFGDBG(1, "include `%s'", fname);
	yy_switch_to_buffer(yy_create_buffer(fp, YY_BUF_SIZE));
	yyfile = intern(s);
	yyline = 1;
	free(s);
	includedepth++;
	return (0);
}

/*
 * Extract the pathname from a include/cinclude/package into curinclpath
 */
static int
getincludepath(void)
{
	const char *p = yytext;
	ptrdiff_t len;
	const char *e;

	while (*p && isascii((unsigned int)*p) && !isspace((unsigned int)*p))
		p++;
	while (*p && isascii((unsigned int)*p) && isspace((unsigned int)*p))
		p++;
	if (!*p)
		return 0;
	if (*p == '"') {
		p++;
		e = strchr(p, '"');
		if (!e) return 0;
	} else {
		e = p;
		while (*e && isascii((unsigned int)*e)
		    && !isspace((unsigned int)*e))
			e++;
	}

	len = e-p;
	if (len > (ptrdiff_t)sizeof(curinclpath)-1)
		len = sizeof(curinclpath)-1;
	strncpy(curinclpath, p, sizeof(curinclpath));
	curinclpath[len] = '\0';

	return 1;
}

/*
 * Terminate the most recent inclusion.
 */
static int
endinclude(void)
{
	struct incl *in;
	int ateof;

	curdir_pop();
	if ((in = incl) == NULL)
		panic("endinclude");
	incl = in->in_prev;
	lastfile = yyfile;
	yy_delete_buffer(YY_CURRENT_BUFFER);
	(void)fclose(yyin);
	yy_switch_to_buffer(in->in_buf);
	yyfile = in->in_where.w_srcfile;
	yyline = in->in_where.w_srcline;
	ateof  = in->in_ateof;
	interesting = in->in_interesting;
	ifdefstate = in->in_ifdefstate;
	ifdefshift = in->in_ifdefshift;
	free(in);

	includedepth--;

	return (ateof);
}

/*
 * Return the current line number.  If yacc has looked ahead and caused
 * us to consume a newline, we have to subtract one.  yychar is yacc's
 * token lookahead, so we can tell.
 */
u_short
currentline(void)
{
	extern int yychar;

	return (u_short)(yyline - (yychar == '\n'));
}

static int
getcurifdef(void)
{
	char *p = yytext, *q;

	while (*p && isascii((unsigned int)*p) && !isspace((unsigned int)*p))
		p++;
	while (*p && isascii((unsigned int)*p) && isspace((unsigned int)*p))
		p++;
	q = p;
	while (*q && isascii((unsigned int)*q) && !isspace((unsigned int)*q))
		q++;
	*q = '\0';

	return ht_lookup(attrtab, intern(p)) != NULL;
}
