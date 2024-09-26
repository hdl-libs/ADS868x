
VVP_INCLUDEDIR=
VVP_INCLUDEDIR+=-I ./src
VVP_INCLUDEDIR+=-I ./sim

VVP_CFLAGS=
VVP_CFLAGS+=-g2005-sv

VVP_SRCS=

VVP_SRCS+= D:/ProgramFiles/modelsim_dlx64_10.6c/vivado2018.3_lib/sim_comm/apb_task.v
VVP_SRCS+= ./src/ads8684_conf.v
VVP_SRCS+= ./src/ads8684_conf_wrapper.v
VVP_SRCS+= ./src/ads8684_scan.v
VVP_SRCS+= ./src/ads8684_scan_wrapper.v
VVP_SRCS+= ./src/ads8684_wrapper.v
VVP_SRCS+= ./src/round_arb.v
VVP_SRCS+= ./src/spi_master.v
VVP_SRCS+= ./src/ads8688_ui.v
VVP_SRCS+= ./src/sample_core.v

VVP_SRCS+= ./sim/ads8684_wrapper_tb.v
