project_open MediaPlayer -revision MediaPlayer
create_timing_netlist
read_sdc
update_timing_netlist
set resultdir /home/vash/mister-builds/entry681/results
foreach instance {transform b_transform} {
    foreach weight {iq_intra_weight iq_non_intra_weight} {
        set pattern "*|mpeg2_h262_p_non_intra_transform:${instance}|${weight}*"
        set regs [get_registers $pattern]
        set n [get_collection_size $regs]
        puts "WEIGHT_REGISTERS $instance $weight count=$n"
        if {$n < 8} {error "weight register boundary missing: $pattern"}
        foreach_in_collection reg $regs {puts "WEIGHT_REGISTER [get_register_info -name $reg]"}
        report_timing -setup -to $regs -npaths 2 -detail full_path -file $resultdir/${instance}_${weight}_input.rpt
        report_timing -setup -from $regs -npaths 2 -detail full_path -file $resultdir/${instance}_${weight}_output.rpt
    }
}
puts WEIGHT_REGISTER_AUDIT_PASS
foreach pattern {
    {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|progressive_chroma_mem}
    {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|progressive_chroma_r1}
    {*|mpeg2_h262_native_field_order:*|film_mode*}
    {*|mpeg2_new_film_mode_video_sync[0]}
    {*|mpeg2_video_output_timing:*|native_field}
    {*|mpeg2_video_output_timing:*|native_active*}
    {*|mpeg2_new_native_field_sync[0]}
} {
    set n [get_collection_size [get_keepers $pattern]]
    puts "FILM_CDC_ENDPOINT $pattern count=$n"
    if {$n == 0} {error "missing film CDC endpoint: $pattern"}
}
report_timing -setup -from [get_keepers {*|mpeg2_new_film_mode_video_sync[0] *|mpeg2_new_native_field_sync[0] *|progressive_chroma_r1}] -npaths 10 -detail summary -file $resultdir/film_later_stages.rpt
puts FILM_CDC_AUDIT_PASS
report_timing -setup -npaths 15 -detail full_path -file $resultdir/setup_paths.rpt
report_timing -hold -npaths 5 -detail full_path -file $resultdir/hold_paths.rpt
delete_timing_netlist
project_close
