    begin: playback_test
        reg seeking=0;
        reg [34:0] target=0;
        wire done,rebase,fast;
        wire [34:0] elapsed;
        wire [32:0] seek_elapsed;
        integer at_q=792792,delay_cycles=0;
        integer landed_swaps=0,landed_audio=0;
        media_playback_control control(
            .clk(clk),.reset(reset),.paused(1'b0),.seek_active(seeking),
            .seek_target_q(target),.frame_rate_code(4'd4),
            .swap_reset_count(framebuffer_swap_reset_count),
            .first_picture_complete(picture_complete),.swap_window(swap_window_pulse),
            .drained(sequence_end_seen && !frame_waiting &&
                !scheduler.scheduled_frame_valid && !scheduler.pending_frame_valid &&
                !scheduler.reorder_active && !presentation_hold && !destination_ownership_hold),
            .fatal(probe_error||pred_error||writer_error||presentation_error),
            .display_pts_valid(replay_display_valid),.display_pts(replay_display_pts),
            .elapsed_q(elapsed),.seek_done(done),.scheduler_window(controlled_window),
            .fast_seek(fast),.rebase(rebase),.seek_elapsed_90k(seek_elapsed));
        assign seek_override=seeking;
        initial begin
            if($value$plusargs("AT_Q=%d",at_q)) begin end
            if($value$plusargs("SEEK_DELAY=%d",delay_cycles)) begin end
            wait(!reset);
            if(!$test$plusargs("NO_SKIP")) begin
                wait(elapsed>=at_q);repeat(delay_cycles) @(negedge clk);
                @(negedge clk);target=elapsed+3600000;seeking=1;
                $display("SEEK BEGIN cycle=%0d elapsed_q=%0d target_q=%0d byte=%0d",total_cycles,elapsed,target,stream_index);
                wait(done);@(negedge clk);seeking=0;
                $display("SEEK END cycle=%0d elapsed_q=%0d",total_cycles,elapsed);
            end
            playback_test_complete=1;
            if($test$plusargs("NO_SKIP")) wait(elapsed>=1440000);
            landed_swaps=display_swaps;landed_audio=replay_played;
            repeat(12000000) @(negedge clk);
            if(display_swaps<=landed_swaps || replay_played<=landed_audio)
                $fatal(1,"MPG_REPLAY_NO_RESUME swaps=%0d/%0d audio=%0d/%0d",display_swaps,landed_swaps,replay_played,landed_audio);
            if(replay_under||replay_terr)
                $fatal(1,"MPG_REPLAY_AUDIO_FAILURE underrun=%0d timestamp=%0d",replay_under,replay_terr);
            $display("MPG_REPLAY_BOUNDARY_PASS skipped=%0d cycles=%0d elapsed_q=%0d",!$test$plusargs("NO_SKIP"),total_cycles,elapsed);
            $finish;
        end
    end
