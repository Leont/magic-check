#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

static SV* S_call_validate(pTHX_ SV* sv, SV* validator) {
	dSP;
	PUSHSTACKi(PERLSI_MAGIC);

	PUSHMARK(SP);
	EXTEND(SP, 2);
	PUSHs(validator);
	PUSHs(sv);
	PUTBACK;
	call_method("validate", G_SCALAR);
	SPAGAIN;
	SV* result = POPs;

	POPSTACK;

	return result;
}
#define call_validate(sv, validator) S_call_validate(aTHX_ sv, validator)

#define validate(sv, validator, thrower) do {\
	SV* result = call_validate(sv, validator);\
	if (SvOK(result))\
		thrower(result);\
	} while (0)

static int croak_set(pTHX_ SV* sv, MAGIC* magic) {
	SV* result = call_validate(sv, magic->mg_obj);

	if (SvOK(result)) {
		sv_setsv(sv, (SV*)magic->mg_ptr);
		croak_sv(result);
	} else
		sv_setsv((SV*)magic->mg_ptr, sv);

	return 0;
}

static const MGVTBL croak_table = { NULL, croak_set };

static int warn_set(pTHX_ SV* sv, MAGIC* magic) {
	validate(sv, magic->mg_obj, warn_sv);
	return 0;
}

static const MGVTBL warn_table = { NULL, warn_set };

MODULE = Magic::Check				PACKAGE = Magic::Check

PROTOTYPES: DISABLED

void check_variable(SV* variable, SV* checker, bool non_fatal = FALSE)
	CODE:
	if (non_fatal) {
		validate(variable, checker, warn_sv);
		sv_magicext(variable, checker, PERL_MAGIC_ext, &warn_table, NULL, 0);
	} else {
		validate(variable, checker, die_sv);
		sv_magicext(variable, checker, PERL_MAGIC_ext, &croak_table, (char*)newSVsv(variable), HEf_SVKEY);
	}
