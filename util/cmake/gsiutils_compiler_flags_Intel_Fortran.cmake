####################################################################
# FLAGS COMMON TO ALL BUILD TYPES
####################################################################

set(CMAKE_Fortran_FLAGS_DEBUG "${CMAKE_Fortran_FLAGS} -g -traceback -implicitnone")

####################################################################
# RELEASE FLAGS
####################################################################

set(CMAKE_Fortran_FLAGS_RELEASE "-O3")

####################################################################
# DEBUG FLAGS
####################################################################

set(CMAKE_Fortran_FLAGS_DEBUG "-O0 -fp-model source -debug -ftrapuv -warn all,nointerfaces -check all,noarg_temp_created -fp-stack-check -fstack-protector")

####################################################################
# LINK FLAGS
####################################################################

set(CMAKE_Fortran_LINK_FLAGS "")

####################################################################
# FLAGS FOR AUTOPROFILING
####################################################################

set(Fortran_AUTOPROFILING_FLAGS "-finstrument-functions")

####################################################################

# Meaning of flags
# ----------------
# todo
