

##    run: run the program
##         pass parameters to software via 'make RUN_ARGS= run'
RUN_ARGS?=

export DTOP=/bsc-work/6.175/lab5/bluesim
CONNECTALDIR=/opt/connectal
BSVPATH = /bsc-work/6.175/lab5/src/includes:/opt/connectal/bsv:/bsc-work/6.175/lab5/bluesim/generatedbsv:/bsc-work/6.175/lab5:/:/bsc-work/6.175/lab5/src:/opt/connectal/lib/bsv:/opt/connectal/generated/xilinx:/opt/connectal/generated/altera

BOARD=bluesim
PROJECTDIR=/bsc-work/6.175/lab5/bluesim
MKTOP=mkXsimTop
OS=ubuntu
TOOLCHAIN?=
DUT=mkxsimtop

export INTERFACES = MemServerRequest MMURequest MemServerIndication MMUIndication XsimMsgRequest XsimMsgIndication ConnectalProcRequest ConnectalProcIndication
BSVFILES = /bsc-work/6.175/lab5/src/includes/Ifc.bsv /opt/connectal/bsv/ConnectalMemory.bsv /opt/connectal/bsv/XsimIF.bsv /bsc-work/6.175/lab5/bluesim/generatedbsv/IfcNames.bsv /opt/connectal/bsv/DisplayInd.bsv
XCIFILES = 

BSCFLAGS_PROJECT =  -D ONECYCLE -steps-max-intervals 50 +RTS -K256M -RTS  -show-schedule
SIM_CXX_PROJECT = 
VERILATOR_PROJECT_ARGS = 
CFLAGS_PROJECT = 
CXXFLAGS_PROJECT = 
XELABFLAGS = 
XSIMFLAGS  = -R
AWSFLAGS   = 
TOPBSVFILE = /opt/connectal/bsv/XsimTop.bsv
BSVDEFINES =  -D ONECYCLE -D ConnectalVersion=22.05.23b -D NumberOfMasters=1 -D PinType=Empty -D PinTypeInclude=Misc -D NumberOfUserTiles=1 -D SlaveDataBusWidth=32 -D SlaveControlAddrWidth=5 -D BurstLenSize=10 -D project_dir=$(DTOP) -D MainClockPeriod=20 -D DerivedClockPeriod=10.000000 -D CnocTop -D XsimHostInterface -D PhysAddrWidth=40 -D SIMULATION -D CONNECTAL_BITS_DEPENDENCES=bsim -D BOARD_bluesim
QTUSED = 
export BSVDEFINES_LIST = ONECYCLE ConnectalVersion=22.05.23b NumberOfMasters=1 PinType=Empty PinTypeInclude=Misc NumberOfUserTiles=1 SlaveDataBusWidth=32 SlaveControlAddrWidth=5 BurstLenSize=10 project_dir=$(DTOP) MainClockPeriod=20 DerivedClockPeriod=10.000000 CnocTop XsimHostInterface PhysAddrWidth=40 SIMULATION CONNECTAL_BITS_DEPENDENCES=bsim BOARD_bluesim
export DUT_NAME = mkXsimTop





ONECYCLE=ONECYCLE
ConnectalVersion=22.05.23b
NumberOfMasters=1
PinType=Empty
PinTypeInclude=Misc
NumberOfUserTiles=1
SlaveDataBusWidth=32
SlaveControlAddrWidth=5
BurstLenSize=10
project_dir=$(DTOP)
MainClockPeriod=20
DerivedClockPeriod=10.000000
CnocTop=CnocTop
XsimHostInterface=XsimHostInterface
PhysAddrWidth=40
SIMULATION=SIMULATION
CONNECTAL_BITS_DEPENDENCES=bsim
BOARD_bluesim=BOARD_bluesim


include $(CONNECTALDIR)/scripts/Makefile.connectal.build


export VERILOG_PATH=verilog /opt/connectal/verilog $(BLUESPEC_VERILOG)
MODELSIM_FILES= 
FPGAMAKE=$(CONNECTALDIR)/../fpgamake/fpgamake
fpgamake.mk: $(VFILE) Makefile prepare_bin_target
	$(Q)if [ -f ../synth-ip.tcl ]; then vivado -mode batch -source ../synth-ip.tcl; fi
	$(Q)$(FPGAMAKE) $(FPGAMAKE_VERBOSE) -o fpgamake.mk --board=bluesim --part=xc7z020clg484-1  --floorplan=      -t $(MKTOP)   -b hw/mkTop.bit   $(VERILOG_PATH)

synth.%:fpgamake.mk
	$(MAKE) -f fpgamake.mk Synth/$*/$*-synth.dcp

hw/mkTop.bit: prepare_bin_target  fpgamake.mk
	$(Q)mkdir -p hw
	$(Q)$(MAKE) -f fpgamake.mk
ifneq ($(XILINX),)
	$(Q)rsync -rav --include="*/" --include="*.rpt" --exclude="*" Impl/ bin
else ifneq ($(ALTERA),)
	$(Q)cp -f $(MKTOP).sof bin
endif




