CONNECTALDIR ?= /opt/connectal
S2H_INTERFACES = \
	ConnectalProcRequest:ConnectalWrapper.connectProc\
	ConnectalMemoryInitialization:ConnectalWrapper.initProc
H2S_INTERFACES = \
	ConnectalWrapper:ConnectalProcIndication
BSVFILES += \
	src/includes/Ifc.bsv
BSVPATH += / \
	src/ \
	src/includes \
	$(CONNECTALDIR)/bsv
CPPFILES += \
	main.cpp\
	Platform.cpp

#CONNECTALFLAGS += --mainclockperiod=20
#CONNECTALFLAGS += --verilog=ddr3_v2_0/
SOFTWARE_SOCKET_NAME=/tmp/connectal$(USER)
export SOFTWARE_SOCKET_NAME
CONNECTALFLAGS += -D $(VPROC) 
CONNECTALFLAGS += --bscflags " -D $(VPROC) -steps-max-intervals 50 +RTS -K256M -RTS"
CONNECTALFLAGS += --bscflags " -show-schedule"
#CONNECTALFLAGS += --cxxflags="-g -std=gnu++11"

include $(CONNECTALDIR)/Makefile.connectal


clean:
	rm -rf bluesim

simple_compile:
	mkdir -p buildDir
	bsc -u -sim -show-schedule -sched-dot -bdir buildDir -info-dir buildDir -simdir buildDir -vdir buildDir -p +:src/includes/ -aggressive-conditions -keep-fires src/ExcepProc.bsv
	# bsc -sim -e mkProc -bdir buildDir -info-dir buildDir -simdir buildDir -o buildDir/simProc 