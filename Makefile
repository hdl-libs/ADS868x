CC_IVERILOG :=iverilog
CC_VVP :=vvp

VPATH := src:sim
BPATH := ./sim

include Makefile_srcs.mk

######################################################
# iverilog compile
######################################################
VVP_TARGET_NAME:=test_tb.vvp
VVP_TARGET_FILE:=${BPATH}/${VVP_TARGET_NAME}

${VVP_TARGET_NAME} : ${VVP_SRCS} ./Makefile ./Makefile_srcs.mk
	${CC_IVERILOG} -o ${VVP_TARGET_FILE} ${VVP_CFLAGS} ${VVP_INCLUDEDIR} ${VVP_SRCS}

######################################################
# vvp compile
######################################################
VCD_TARGET_NAME:=test_tb.vcd
VCD_TARGET_FILE:=${BPATH}/${VCD_TARGET_NAME}

VCD_CFLAGS=
VCD_CFLAGS+=-n

VCD_EXTRA_CFLAGS=
VCD_EXTRA_CFLAGS+=-vcd

VCD_SRCS=
VCD_SRCS+= ./sim/test_tb.vvp

${VCD_TARGET_NAME} : ${VVP_TARGET_NAME}
	${CC_VVP} ${VCD_CFLAGS} ${VCD_SRCS} ${VCD_EXTRA_CFLAGS}

all: ${VCD_TARGET_NAME}

show: ${VCD_TARGET_NAME}
	gtkwave ${VCD_TARGET_FILE} &

clean:
	rm ${VVP_TARGET_FILE}
	rm ${VCD_TARGET_FILE}

.PHONY: all clean