ifndef AMUSE_DIR
    AMUSE_DIR=../../../..
endif

CODE_GENERATOR = $(AMUSE_DIR)/build.py

CXXFLAGS = -Wall -g -DTOOLBOX  $(MUSE_INCLUDE_DIR)
LDFLAGS = -lm $(MUSE_LD_FLAGS)

OBJS = src/main_code.o src/ODE_system.o src/helper_routines.o src/tidal_friction_parameters.o src/cvode/cvode.o src/cvode/cvode_dense.o src/cvode/cvode_direct.o src/cvode/cvode_io.o src/cvode/cvode_diag.o src/cvode/cvode_spils.o src/cvode/cvode_spgmr.o src/cvode/cvode_spbcgs.o src/cvode/cvode_sptfqmr.o src/cvode/nvector_serial.o src/cvode/sundials_dense.o src/cvode/sundials_direct.o src/cvode/sundials_math.o src/cvode/sundials_nvector.o src/cvode/sundials_spgmr.o src/cvode/sundials_iterative.o src/cvode/sundials_spbcgs.o src/cvode/sundials_sptfqmr.o


all: worker_code

cleanall: clean
	$(RM) worker_code *

clean:
	rm -f *.so *.o *.pyc worker_code.cc src/*.o*

worker_code.cc: interface.py
	$(CODE_GENERATOR) --type=c interface.py SecularTripleInterface -o $@

worker_code: worker_code.cc $(OBJS)
	mpicxx $@.cc $(OBJS) -o $@

.cc.o: $<
	g++ $(CXXFLAGS) -c -o $@ $<

.c.o: $<
	g++ $(CXXFLAGS) -c -o $@ $<
