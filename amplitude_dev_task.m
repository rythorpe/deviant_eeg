function [trainIaccuracy,repeat] = amplitude_dev_task(training_trials,subj_str,output_directory, SerialPortObj,windowPtr,black, white, red, green,x_centre, y_centre, da, dd, sinewave,yes_button,no_button,operator_button,session,repeat_button,supra,baseline_stim,dev_delta_stim)

    % define events
    event_cue = 4;
    event_respcue = 16;

    %Delay times
    delay_times = [.5 .6 .7 .8 .9 1 1.1 1.2 1.3 1.4 1.5];

    %init output
    trainingI_results = fopen(strcat(output_directory,subj_str,'_train_I'), 'a');
    fprintf(trainingI_results, '\r\n \r\n %s ', datestr(now));  
    fprintf(trainingI_results, '\n Session: %i ', session); 
    fprintf(trainingI_results,'\nTrial\tType\tStim\tDetect\tRT\tTapTime\tRespTime\tCueTime');

    %fixation cross 
    cross=30; 
    x_coords=[-cross, cross, 0, 0];
    y_coords=[0, 0, -cross, cross];
    cross_coords=[x_coords; y_coords];
    Screen('DrawLines', windowPtr, cross_coords,2, white, [x_centre, y_centre]);   
    %flip everything
    Screen('Flip', windowPtr);

    % Wait for any key press to start 
    KbStrokeWait()


    %% 5) For loop of actual task
    accuracy =[];
    run_length = 0;
    for trial = 1:training_trials
        RT_dev = 0;

        % 1) Present cue
        % 2) Deliver stimulus 
        % 3) Present response cue
        % 4) Record response
        % 5) Repeat for other two intensities
        % 6) Update stimulation intensities

        
        %-----------------------------------------------------------------
        %% Delivery of Baseline/Dev stimulus
        delay_time_dev = delay_times(randi([1 size(delay_times,2)]));
        %Draw cue
        Screen('DrawLines', windowPtr, cross_coords,2, red, [x_centre, y_centre]);
        Screen('Flip', windowPtr);
        % event
        fwrite(SerialPortObj, event_cue, 'uint8');
        fwrite(SerialPortObj, 0, 'uint8');
        cue_time_dev = GetSecs;

        %Deliver Max stimulus
        if rand < 0.15
            true_stim = false;
            stim_mag = 0;
            stimulus = stim_mag * sinewave;
            run_length = 0;
        else
            true_stim = true;
            if rand < 0.2 && run_length >= 2
    %             stimulus = (baseline_stim + randn * dev_std_stim) * sinewave;
                stim_mag = baseline_stim + sign(rand-0.5) * dev_delta_stim;
                stimulus = stim_mag * sinewave;
                run_length = 0;
            else
                stim_mag = baseline_stim;
                stimulus = stim_mag * sinewave;
                run_length = run_length + 1;
            end
        end
        preload(da, stimulus)
            waiting=1;
            while waiting  
                if (GetSecs - cue_time_dev) > delay_time_dev
                        start(da) %tap
                        tap_time_dev = GetSecs;
                        write(dd, 1, 'uint8') %event
                        write(dd, 0, 'uint8')
                    waiting=0;
                end
            end       

        pause(2 - delay_time_dev - .01)%%%
        stop(da)  

        %Draw green crosshair   
        Screen('DrawLines', windowPtr, cross_coords,2, green, [x_centre, y_centre]); 
        %flip everything
        waiting=1;
        while waiting 
            if (GetSecs - cue_time_dev) > 2
                Screen('Flip', windowPtr);
                waiting=0;
            end
        end

        %event
        fwrite(SerialPortObj, event_respcue, 'uint8');
        fwrite(SerialPortObj, 0, 'uint8');

        % Response
        respcue_time_dev = GetSecs();
        [s, keyCode_dev, ~] = KbWait(-3, 2, GetSecs()+1);

        %get RT
        if keyCode_dev(yes_button) || keyCode_dev(no_button)
             RT_dev = s - respcue_time_dev;
        end

        pause(1 - RT_dev);

        %% Adjustment of weights
        % Keeps track of participant's response (yes=1 is 49, no=2 is 50)
        dev_detected = keyCode_dev(yes_button);

        accuracy = [accuracy; dev_detected == true_stim];
        
        %save
        fprintf(trainingI_results,'\n%i\t%i\t%2.2f\t%i\t%i\t%2.2f\t%2.2f\t%2.2f\t',...
                trial,2,stim_mag, dev_detected,round(RT_dev*1000),tap_time_dev-cue_time_dev,respcue_time_dev-cue_time_dev,cue_time_dev);
    end

    text = sprintf('End of Training\n Accuracy: %i%%',round(mean(accuracy)*100));
    trainIaccuracy= round(mean(accuracy)*100);
    DrawFormattedText(windowPtr,text,'center','center',white);
    Screen('Flip',windowPtr)
    [~, keyCode_repeat, ~] = KbWait(-3, 2);
    repeat = 0;
    if keyCode_repeat(repeat_button)
        repeat = 1;
    end

end

    
