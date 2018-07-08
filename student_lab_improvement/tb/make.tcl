proc do_compile {} { 
  exec rm -rf work/
  
  vlib work
  
  vlog -sv ../des.v 
  vlog -sv ../deserializer.sv 
  vlog -sv ../deserializer_improved.sv 
  
  vlog -sv tb.sv 
}

proc start_sim {} {
  vsim -novopt tb 

  add wave -r -hex sim:/tb/*

  run -all 
}

proc run_test {} {
  do_compile
  start_sim
}

proc help {} {
  echo "help                - show this message"
  echo "do_compile          - compile all"
  echo "start_sim           - start simulation"
  echo "run_test            - do_compile & start_sim"
}

help
