char_null  :=
char_space := $(char_null) #
char_comma := ,
ad_dn       = $(subst $(char_space),$(char_comma),$(addprefix dc=, $(subst ., ,$(1))))
