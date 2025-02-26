/*	$NetBSD: c23.c,v 1.8 2024/01/28 08:17:27 rillig Exp $	*/
# 3 "c23.c"

// Tests for the option -Ac23, which allows features from C23 and all earlier
// ISO standards, but none of the GNU extensions.
//
// See also:
//	c11.c
//	msg_353.c		for empty initializer braces

/* lint1-flags: -Ac23 -w -X 351 */

int
empty_initializer_braces(void)
{
	struct s {
		int member;
	} s;

	// Empty initializer braces were introduced in C23.
	s = (struct s){};
	s = (struct s){s.member};
	return s.member;
}


_Static_assert(1 > 0, "string");
_Static_assert(1 > 0);


// The keyword 'thread_local' was introduced in C23.
thread_local int globally_visible;

// Thread-local functions don't make sense; lint allows them, though.
thread_local void
thread_local_function(void)
{
}

void
function(void)
{
	// Not sure whether it makes sense to have a function-scoped
	// thread-local variable.  Don't warn for now, let the compilers handle
	// this case.
	thread_local int function_scoped_thread_local;
}

// 'thread_local' can be combined with 'extern' and 'static', but with no other
// storage classes.  The other storage classes cannot be combined.
extern thread_local int extern_thread_local_1;
thread_local extern int extern_thread_local_2;
/* expect+1: warning: static variable 'static_thread_local_1' unused [226] */
static thread_local int static_thread_local_1;
/* expect+1: warning: static variable 'static_thread_local_2' unused [226] */
thread_local static int static_thread_local_2;
