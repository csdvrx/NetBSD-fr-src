/* $NetBSD: namespace.h,v 1.18 2024/01/21 18:53:18 christos Exp $ */

#define atan2 _atan2
#define atan2f _atan2f
#define atan2l _atan2l
#define hypot _hypot
#define hypotf _hypotf
#define hypotl _hypotl

#define exp _exp
#define expf _expf
#define expl _expl
#define expm1l _expm1l
#define log _log
#define logf _logf
#define logl _logl

#if 0 /* not yet - need to review use in machdep code first */
#define sin _sin
#define sinf _sinf
#define cos _cos
#define cosf _cosf
#define finite _finite
#define finitef _finitef
#endif /* notyet */

#define sincos _sincos
#define sincosf _sincosf
#define sincosl _sincosl
#define sinh _sinh
#define sinhf _sinhf
#define sinhl _sinhl
#define cosh _cosh
#define coshf _coshf
#define coshl _coshl
#define asin _asin
#define asinf _asinf
#define asinl _asinl

#define casin _casin
#define casinf _casinf
#define casinl _casinl
#define catan _catan
#define catanf _catanf
#define catanl _catanl

#define scalbn _scalbn
#define scalbnf _scalbnf
#define scalbnl _scalbnl
#define scalbln _scalbln
#define scalblnf _scalblnf
#define scalblnl _scalblnl

#define copysignl _copysignl
#define sqrtl _sqrtl
#define cbrtl _cbrtl
#define ceill _ceill
#define floorl _floorl
#define roundl _roundl
#define fmodl _fmodl
#define modfl _modfl
#define truncl _truncl

#define exp2l _exp2l
#define cosl _cosl
#define sinl _sinl
#define tanl _tanl
#define powl _powl
#define coshl _coshl
#define sinhl _sinhl
#define acosl _acosl
#define atanl _atanl
#define asinhl _asinhl
#define acoshl _acoshl
#define tanhl _tanhl
#define atanhl _atanhl
#define log10l _log10l
#define log1pl _log1pl
#define log2l _log2l

#define cospi _cospi
#define cospif _cospif
#define cospil _cospil

#define sinpi _sinpi
#define sinpif _sinpif
#define sinpil _sinpil

#define tanpi _tanpi
#define tanpif _tanpif
#define tanpil _tanpil

#define erfl _erfl
#define erfcl _erfcl

#define lgammal _lgammal
#define lgammal_r _lgammal_r
#define tgammal _tgammal

#define feclearexcept _feclearexcept
#define fegetenv _fegetenv
#define fegetexceptflag _fegetexceptflag
#define fegetround _fegetround
#define feholdexcept _feholdexcept
#define feraiseexcept _feraiseexcept
#define fesetenv _fesetenv
#define fesetexceptflag _fesetexceptflag
#define fesetround _fesetround
#define fetestexcept _fetestexcept
#define feupdateenv _feupdateenv

#define fedisableexcept _fedisableexcept
#define feenableexcept _feenableexcept
#define fegetexcept _fegetexcept
