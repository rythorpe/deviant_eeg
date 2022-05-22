function TMSEEG(subj_str,session)
    %inputs:
%         subj_str: subject number as string ('BETAXX')
%         session: index

    cd('C:\Users\Jones Lab\Documents\Task_Code\Neuropracticum');

    SIloc_trials = 150; %150
    training_trials1 = 200;%5
    eeg_rest = 60; %60
    max_pest_trials = 33;%33;
    trialmultiplier = 6;%6
    %% TMS EEG Experiment
    % 1) S1 Localization 
    % 2) Training I
    % 3) Resting EEG Sound ON
    % 4) Resting EEG Sound OFF
    % 5) PEST 
    % 6) Training II
    % 7) Task
    % 8) S1 Localization 
    % 9) Resting EEG Sound ON
    % 10) Resting EEG Sound OFF
    
    %% Initializing Psychtoolbox & Serialport
    % we have to redo this once we want to use TMS
    Screen('Preference', 'SkipSyncTests', 1);
    PsychDefaultSetup(2); %default PTB setup
    screens = Screen('Screens'); %get screen numbers
    screenNumber = max(screens); %get max screen
    black = [0 0 0];
    white = [255 255 255];
    red = [255,0,0];
    green = [0,255,0];    
    SerialPortObj=serialport('COM3', 9600, 'TimeOut', 1); % in this example x=3 SerialPortObj.BytesAvailableFcnMode='byte';
    %%Psychtoolbox
    Screen('Preference','VisualDebugLevel',0);
    [windowPtr,rect]=Screen('OpenWindow', screenNumber, black);
    [x_centre, y_centre]=RectCenter(rect);
    %%Serialport
    fopen(SerialPortObj);
    fwrite(SerialPortObj, 0, 'uint8');  
     %%Nidaq
    da = daq('ni'); %analog - tap
    dd = daq('ni'); % digital - event
    addoutput(da, 'Dev1', 'ao0', 'Voltage'); %deliver tap
    addoutput(dd,'Dev1','port0/line0', 'Digital'); %tap event
    %Tap
    dq_dt = 1/da.Rate;
    freq = 100; phase = 3*pi/2; 
    time = 0:dq_dt:0.01; %0:0.01 sec in 0.1 msec steps
    sinewave = sin(2*pi*freq*time + phase)'; 
    sinewave = sinewave +1; 
    sinewave(end+1)=0;
    
    %% output
    output_directory =  strcat('C:\Users\Jones Lab\Documents\TMSEEG\',subj_str,'\Session',num2str(session),'\');
    mkdir(output_directory);
    experiment_notes = fopen(strcat(output_directory,subj_str,'_notes'), 'a');
    fprintf(experiment_notes, '\r\n \r\n %s ', datestr(now)); 
    fprintf(experiment_notes, '\n Session: %i ', session); 
    
%     %load motor threshold intensities and save in notes
%     %(this can fail if MotorThreshold.m was shut down abruptly)
%     try
%         intensities = load('C:\Users\Jones Lab\Documents\TMSEEG\temp');op
%         fprintf(experiment_notes,'\nMotor Thresholding: %s',num2str(intensities.keep_intensities));
%     catch
%         fprintf('intensities not found')
%     end

    %%% define response buttons
    yes_button = 34;
    no_button = 40; 
    operator_button = 187; %=
    repeat_button = 189;%-
    % tap intensity
    supra = 1;
    
    repeat=0;
    
%% TEST

    for i = 1:3
        fwrite(SerialPortObj, 0, 'uint8');
        pause(2)
        fwrite(SerialPortObj, 4, 'uint8');
        pause(2)
        fwrite(SerialPortObj, 16, 'uint8');
        pause(2)
    end

     %% 5) PEST
    %instructions
    text = sprintf('Training #1 \n\nPlease keep your eyes on the CROSS on the screen, rest your hand on the tap device \nand pay attention to the tapping sensation on your hand. \n\nWhile the the CROSS is RED, you might feel a tap or you might not. \nOnce the CROSS turns GREEN, report whether you felt a tap or not using the response buttons. \n\nPress ''Y'' with your left index finger if you DID feel a tap (Yes), \nor ''N'' with your left middle finger if you did NOT feel a tap (No). \n\nYour response will only count when the cross is GREEN.');
    DrawFormattedText(windowPtr,text,'center','center',white);
    Screen('Flip',windowPtr);
    contkeycode(operator_button)=0;
    while contkeycode(operator_button)==0
        [s, contkeycode, delta] = KbWait();
    end
    detection_threshold = 0;
    [detection_threshold,repeat,baseline_stim,dev_std_stim] =  PEST(max_pest_trials,subj_str,output_directory, SerialPortObj,windowPtr,black, white, red, green,x_centre, y_centre, da, dd, sinewave,yes_button,no_button,operator_button,session,repeat_button);
    fprintf(experiment_notes, '\n Threshold: %2.2f ', detection_threshold); 
    if repeat
        fprintf(experiment_notes, '\n PEST repeated'); 
        DrawFormattedText(windowPtr,text,'center','center',white);
        Screen('Flip',windowPtr);
        contkeycode(operator_button)=0;
        while contkeycode(operator_button)==0
            [s, contkeycode, delta] = KbWait();
        end
        [detection_threshold,repeat,baseline_stim,dev_std_stim] =  PEST(max_pest_trials,subj_str,output_directory, SerialPortObj,windowPtr,black, white, red, green,x_centre, y_centre, da, dd, sinewave,yes_button,no_button,operator_button,session,repeat_button);
        fprintf(experiment_notes, '\n Threshold: %2.2f ', detection_threshold); 
    end
    pause(1)
    
    %% 2) Training Block 1
    % instructions
    Screen('TextSize',windowPtr, 50);
    Screen('TextFont',windowPtr,'Arial');
    text = sprintf('Training #1 \n\nPlease keep your eyes on the CROSS on the screen, rest your hand on the tap device \nand pay attention to the tapping sensation on your hand. \n\nWhile the the CROSS is RED, you might feel a tap or you might not. \nOnce the CROSS turns GREEN, report whether you felt a tap or not using the response buttons. \n\nPress ''Y'' with your left index finger if you DID feel a tap (Yes), \nor ''N'' with your left middle finger if you did NOT feel a tap (No). \n\nYour response will only count when the cross is GREEN.');
    DrawFormattedText(windowPtr,text,'center','center',white);
    Screen('Flip',windowPtr);
    contkeycode(operator_button)=0;
    while contkeycode(operator_button)==0
        [s, contkeycode, delta] = KbWait();
    end
    trainIacc=0;
    baseline_stim = 10 * detection_threshold;
    dev_delta_stim = baseline_stim * 0.8;
    [trainIacc,repeat] = amplitude_dev_task(training_trials1,subj_str,output_directory, SerialPortObj,windowPtr,black, white, red, green,x_centre, y_centre, da, dd, sinewave,yes_button,no_button,operator_button,session,repeat_button,supra,baseline_stim,dev_delta_stim);
    fprintf(experiment_notes, '\n TrainingI: %i%% ', trainIacc); 
    if repeat
        fprintf(experiment_notes, '\n Training I repeated'); 
        DrawFormattedText(windowPtr,text,'center','center',white);
        Screen('Flip',windowPtr);
        contkeycode(operator_button)=0;
        while contkeycode(operator_button)==0
            [s, contkeycode, delta] = KbWait();
        end
        trainIacc=0;
        [trainIacc,repeat] = amplitude_dev_task(training_trials1,subj_str,output_directory, SerialPortObj,windowPtr,black, white, red, green,x_centre, y_centre, da, dd, sinewave,yes_button,no_button,operator_button,session,repeat_button,supra);
        fprintf(experiment_notes, '\n TrainingI: %i%% ', trainIacc);      
    end
    pause(1)

    %All done
    text = sprintf('You''ve completed today''s session - thank you!!');
    DrawFormattedText(windowPtr,text,'center','center',white);
    Screen('Flip',windowPtr);
    KbStrokeWait
    fclose(SerialPortObj);
    delete(SerialPortObj);
    fclose('all');
    sca;
end