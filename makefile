vsim_variable_length_decoder=work/variable_length_decoder
vsim_variable_length_decoder_tb=work/variable_length_decoder_tb
vsim_argument_decoder=work/argument_decoder
vsim_argument_decoder_tb=work/argument_decoder_tb
vsim_asymmetric_fifo = work/asymmetric_fifo
vsim_asymmetric_distributed_ram = work/asymmetric_distributed_ram
vsim_stream_decoder = work/stream_decoder
vsim_stream_decoder_tb = work/stream_decoder_tb
vsim_sparse_matrix_decoder = work/sparse_matrix_decoder
vsim_sparse_matrix_decoder_tb = work/sparse_matrix_decoder_tb
vsim_linked_list_fifo = work/linked_list_fifo
vsim_std_fifo = work/std_fifo

$(vsim_variable_length_decoder): variable_length_decoder.v
	vlog variable_length_decoder.v +incdir+../common

$(vsim_variable_length_decoder_tb): variable_length_decoder_tb.v
	vlog variable_length_decoder_tb.v +incdir+../common

$(vsim_argument_decoder): argument_decoder.v work
	vlog argument_decoder.v +incdir+../common

$(vsim_argument_decoder_tb): argument_decoder_tb.v work
	vlog argument_decoder_tb.v +incdir+../common

$(vsim_asymmetric_fifo): work ../asymmetric_fifo/asymmetric_fifo.v
	vlog ../asymmetric_fifo/asymmetric_fifo.v +incdir+../common

$(vsim_asymmetric_distributed_ram): work ../ram/asymmetric_distributed_ram.v
	vlog ../ram/asymmetric_distributed_ram.v +incdir+../common

$(vsim_stream_decoder): work stream_decoder.v
	vlog stream_decoder.v +incdir+../common

$(vsim_stream_decoder_tb): work stream_decoder_tb.v
	vlog stream_decoder_tb.v +incdir+../common

$(vsim_sparse_matrix_decoder): work sparse_matrix_decoder.v
	vlog sparse_matrix_decoder.v +incdir+../common

$(vsim_sparse_matrix_decoder_tb): work sparse_matrix_decoder_tb.v
	vlog sparse_matrix_decoder_tb.v +incdir+../common

$(vsim_linked_list_fifo): work ../linked_list_fifo/linked_list_fifo.v
	vlog ../linked_list_fifo/linked_list_fifo.v +incdir+../common

$(vsim_std_fifo): work ../std_fifo/std_fifo.v
	vlog ../std_fifo/std_fifo.v +incdir+../common

example.hex: ../../src/example.hex
	cp ../../src/example.hex .

work:
	vlib work

sparse_matrix_decoder_sim: work $(vsim_sparse_matrix_decoder_tb) $(vsim_sparse_matrix_decoder) $(vsim_variable_length_decoder) $(vsim_argument_decoder) $(vsim_asymmetric_fifo) $(vsim_asymmetric_distributed_ram) $(vsim_stream_decoder) example.hex $(vsim_linked_list_fifo) $(vsim_std_fifo)
	echo -e "vsim work.sparse_matrix_decoder_tb\nrun -all" | vsim

vld_sim: work $(vsim_variable_length_decoder) $(vsim_variable_length_decoder_tb)
	echo -e "vsim work.variable_length_decoder_tb\nrun -all" | vsim

argument_decoder_sim: work $(vsim_argument_decoder) $(vsim_argument_decoder_tb) $(vsim_variable_length_decoder) $(vsim_asymmetric_fifo) $(vsim_asymmetric_distributed_ram)
	echo -e "vsim work.argument_decoder_tb\nrun -all" | vsim

stream_decoder_sim: work $(vsim_stream_decoder) $(vsim_stream_decoder_tb) $(vsim_argument_decoder) $(vsim_variable_length_decoder) $(vsim_asymmetric_fifo) $(vsim_asymmetric_distributed_ram)
	echo -e "vsim work.stream_decoder_tb\nrun -all" | vsim

sim: sparse_matrix_decoder_sim

stream_decoder.prj:
	echo -e "verilog work variable_length_decoder.v\nverilog work ../ram/asymmetric_distributed_ram.v\nverilog work ../asymmetric_fifo/asymmetric_fifo.v\nverilog work argument_decoder.v\nverilog work stream_decoder.v" > stream_decoder.prj

xst_stream_decoder: stream_decoder.prj
	echo "run -ifn stream_decoder.prj -ifmt mixed -top stream_decoder -ofn stream_decoder.ngc -ofmt NGC -p xc5vlx330-2 -opt_mode Speed -opt_level 1 -vlgincdir ../common" | xst

argument_decoder.prj:
	echo -e "verilog work variable_length_decoder.v\nverilog work ../ram/asymmetric_distributed_ram.v\nverilog work ../asymmetric_fifo/asymmetric_fifo.v\nverilog work argument_decoder.v" > argument_decoder.prj

xst_argument_decoder: argument_decoder.prj
	echo "run -ifn argument_decoder.prj -ifmt mixed -top argument_decoder -ofn argument_decoder.ngc -ofmt NGC -p xc5vlx330-2 -opt_mode Speed -opt_level 1 -generics {INTERMEDIATE_WIDTH=8} -vlgincdir ../common" | xst

xst: xst_argument_decoder

clean:
	rm -rf work

vim:
	vim -p makefile ../std_fifo/std_fifo.v ../../src/smac/spMatrixHelp/spm.hpp sparse_matrix_decoder.v sparse_matrix_decoder_tb.v spmv_opcodes.vh stream_decoder.v stream_decoder_tb.v argument_decoder.v argument_decoder_tb.v ../ram/asymmetric_distributed_ram.v ../asymmetric_fifo/asymmetric_fifo.v variable_length_decoder.v variable_length_decoder_tb.v
