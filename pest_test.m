function [detection_threshold,repeat, baseline_stim, dev_std_stim] =  PEST(max_trials,subj_str,output_directory, SerialPortObj,windowPtr,black, white, red, green,x_centre, y_centre, da, dd, sinewave,yes_button,no_button,operator_button,active,repeat_button)
% 

% for test 
subj_str = 'test';
active = 0;
subj_intensity = 0.5;

    cd('C:\Users\Jones Lab\Documents\Task_Code\Neuropracticum');

    SIloc_trials = 150; %150
    training_trials1 = 5;%5
    eeg_rest = 60; %60
    max_pest_trials = 33;%33;
    training_trials2 = [5,10,20];%[5,10,20];
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
    SerialPortObj=serial('COM3', 'TimeOut', 1); % in this example x=3 SerialPortObj.BytesAvailableFcnMode='byte';
    SerialPortObj.BytesAvailableFcnCount=1; 
    SerialPortObj.BytesAvailableFcn=@ReadCallback;
    %%Psychtoolbox
    Screen('Preference','VisualDebugLevel',0);
    [windowPtr,rect]=Screen('OpenWindow', screenNumber, black);
    [x_centre, y_centre]=RectCenter(rect);
    %%Serialport
    fopen(SerialPortObj);
    fwrite(SerialPortObj, 0,'sync');  
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
    output_directory =  strcat('C:\Users\Jones Lab\Documents\TMSEEG\',subj_str,'\Session',num2str(active),'\');
    mkdir(output_directory);
    experiment_notes = fopen(strcat(output_directory,subj_str,'_notes'), 'a');
    fprintf(experiment_notes, '\r\n \r\n %s ', datestr(now)); 
    fprintf(experiment_notes, '\n Session: %i ', active); 
    
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
    
    
% From the IRB:
% This algorithm follows (Dai 1995) and (Jones 2007) in determining the
% tactile detection threshold.
% 
% First, a strong tactile stimulus (100%
% amplitude, 350 um deflection) is presented, followed by a weak stimulus
% (50% amplitude), and a blank stimulus. If the subject reports detection of
% the strong and the weak tactile stimuli, then the next set of stimuli will
% be given the 50% value set for the strong stimulus and a new value at
% one-half the distance between the weak and blank stimulus for the middle
% stimulus. If the subject does not detect the middle stimulus, then the
% maximum stimulus will remain the same, the middle stimulus will become the
% new minimum stimulus, and the new value for the middle stimulus will be the
% average of the maximum and new minimum. The procedure will be repeated
% until the change in the amplitude of movement for the piezoelectric between
% trials is 5 um. This process will take 3 minutes.

%% Initialize variables

% define events
event_cue = 4;
event_respcue = 16;

%Initialize variables to store stimulus values
no_detection = false;
max_stim = 1; % (the equivalent of 350 um ? CHECK THIS)
mid_stim = max_stim/2;
min_stim = 0;
detection_threshold = 1;
keep_max = [];
keep_mid = [];
keep_min = [];
keep_max_detected = [];
keep_mid_detected = [];
keep_min_detected = [];
max_memory=[];
%Initialize variable to detect 5 um difference
delta_threshold = .01; % the equivalent of 5 um

%Initialize boolean for while loop
threshold_not_reached = true;

%Delay times
delay_times = [.5 .6 .7 .8 .9 1 1.1 1.2 1.3 1.4 1.5];

%Index to keep track of loop
count = 0;

%init output
pest_results = fopen(strcat(output_directory,subj_str,'_pest'), 'a');
fprintf(pest_results, '\r\n \r\n %s ', datestr(now)); 
fprintf(pest_results, '\n Session: %i ', active); 
fprintf(pest_results,'\nTrial\tType\tStim\tDetect\tRT\tTapTime\tRespTime\tCueTime\tUpdate');


%fixation cross 
cross=30; 
x_coords=[-cross, cross, 0, 0];
y_coords=[0, 0, -cross, cross];
cross_coords=[x_coords; y_coords];
Screen('DrawLines', windowPtr, cross_coords,2, white, [x_centre, y_centre]);   
%up cue
x_coords=[-30,0,0,30];
y_coords=[-50,-100,-100,-50];
cue_up_coords=[x_coords; y_coords];
Screen('DrawLines', windowPtr, cue_up_coords,10, white, [x_centre, y_centre]);   
%down cue
cue_down_coords=[x_coords; y_coords*-1];
Screen('DrawLines', windowPtr, cue_down_coords,10, white, [x_centre, y_centre]); 
%flip everything
Screen('Flip', windowPtr);

% Wait for any key press to start 
KbStrokeWait()

%% 5) For loop of actual task
trial = 0;
while threshold_not_reached & trial <= max_trials
    trial = trial+1;
    RT_max = 0;
    RT_mid = 0;
    RT_min = 0;
    repeat_num = 0;
    
    % 1) Present cue
    % 2) Deliver stimulus 
    % 3) Present response cue
    % 4) Record response
    % 5) Repeat for other two intensities
    % 6) Update stimulation intensities
    
    %-----------------------------------------------------------------
    %% Delivery of Max stimulus
    delay_time_max = delay_times(randi([1 size(delay_times,2)]));
    %Draw cue
    Screen('DrawLines', windowPtr, cross_coords,2, white, [x_centre, y_centre]); 
    Screen('DrawLines', windowPtr, cue_up_coords,10, white, [x_centre, y_centre]);
    Screen('DrawLines', windowPtr, cue_down_coords,10, red, [x_centre, y_centre]); 
    Screen('Flip', windowPtr);
    % event
%     fwrite(SerialPortObj, event_cue,'sync');
    fwrite(SerialPortObj, 4,'sync');
    fwrite(SerialPortObj, 0,'sync');
    cue_time_max = GetSecs;
    
    %Deliver Max stimulus
    stimulus = max_stim*sinewave;
      
    preload(da, stimulus)
        waiting=1;
        while waiting  
            if (GetSecs - cue_time_max) > delay_time_max
                    start(da) %tap
                    tap_time_max = GetSecs;
                    write(dd,[1]) %event
                    write(dd,[0])
                waiting=0;
            end
        end       
                
    pause(2 - delay_time_max - .01)%%%
    stop(da)  
    
    %Draw green crosshair   
    Screen('DrawLines', windowPtr, cross_coords,2, green, [x_centre, y_centre]); 
    Screen('DrawLines', windowPtr, cue_up_coords,10, green, [x_centre, y_centre]);
    Screen('DrawLines', windowPtr, cue_down_coords,10, green, [x_centre, y_centre]);  
    %flip everything
    waiting=1;
    while waiting 
        if (GetSecs - cue_time_max) > 2
            Screen('Flip', windowPtr);
            waiting=0;
        end
    end
    
	%event
    fwrite(SerialPortObj, event_respcue,'sync');
    fwrite(SerialPortObj, 0,'sync');
    
    % Response
    respcue_time_max = GetSecs();
    [s, keyCode_max, delta_max] = KbWait(-3, 2, GetSecs()+1);
       
    %get RT
    if keyCode_max(yes_button) | keyCode_max(no_button)
         RT_max = s - respcue_time_max;
    end
        
    pause(1 - RT_max);
    
    % ------------------------------------------
    %% Delivery of Mid stimulus
    delay_time_mid = delay_times(randi([1 size(delay_times,2)]));
    %Draw cue
    Screen('DrawLines', windowPtr, cross_coords,2, white, [x_centre, y_centre]); 
    Screen('DrawLines', windowPtr, cue_up_coords,10, white, [x_centre, y_centre]);
    Screen('DrawLines', windowPtr, cue_down_coords,10, red, [x_centre, y_centre]); 
    Screen('Flip', windowPtr);
    % event
%     fwrite(SerialPortObj, event_cue,'sync');
    fwrite(SerialPortObj, 4,'sync');

    fwrite(SerialPortObj, 0,'sync');
    cue_time_mid = GetSecs;
    
    %Deliver Mid stimulus
    stimulus = mid_stim*sinewave;
    preload(da, stimulus)
        waiting=1;
        while waiting  
            if (GetSecs - cue_time_mid) >delay_time_mid
                    start(da) %tap
                    tap_time_mid = GetSecs;
                    write(dd,[1]) %event
                    write(dd,[0])
                waiting=0;
            end
        end         
     
     pause(2 - delay_time_mid - .01)
     stop(da)
                    
    %Draw green crosshair   
    Screen('DrawLines', windowPtr, cross_coords,2, green, [x_centre, y_centre]); 
    Screen('DrawLines', windowPtr, cue_up_coords,10, green, [x_centre, y_centre]);
    Screen('DrawLines', windowPtr, cue_down_coords,10, green, [x_centre, y_centre]);  
    waiting=1;
    while waiting 
        if (GetSecs - cue_time_mid > 2)
            Screen('Flip', windowPtr);
            waiting=0;
        end
    end
    
	%event
    fwrite(SerialPortObj, event_respcue,'sync');
    fwrite(SerialPortObj, 0,'sync');
    
    % Response
    respcue_time_mid = GetSecs();
    [s, keyCode_mid, delta_mid] = KbWait(-3, 2, GetSecs()+1);
        
    %get RT
    if keyCode_mid(yes_button) | keyCode_max(no_button)
         RT_mid = s - respcue_time_mid;
    end
    pause(1 - RT_mid);
    
    % -----------------------------------------
    %% Delivery of Min stimulus
    delay_time_min = delay_times(randi([1 size(delay_times,2)]));
    %Draw cue
    Screen('DrawLines', windowPtr, cross_coords,2, white, [x_centre, y_centre]); 
    Screen('DrawLines', windowPtr, cue_up_coords,10, white, [x_centre, y_centre]);
    Screen('DrawLines', windowPtr, cue_down_coords,10, red, [x_centre, y_centre]); 
    Screen('Flip', windowPtr);
    % event
%     fwrite(SerialPortObj, event_cue,'sync');
    fwrite(SerialPortObj, 4,'sync');

    fwrite(SerialPortObj, 0,'sync');
    cue_time_min = GetSecs;
    
    %Deliver Min stimulus
    stimulus=min_stim*sinewave;
    preload(da, stimulus)
        waiting=1;
        while waiting  
            if (GetSecs - cue_time_min) >delay_time_min
                    start(da) %tap
                    tap_time_min = GetSecs;
                    write(dd,[1]) %event
                    write(dd,[0])
                waiting=0;
            end
        end       
                       
    pause(2 - delay_time_min - .01)
    stop(da) 
    
    %Draw green crosshair   
    Screen('DrawLines', windowPtr, cross_coords,2, green, [x_centre, y_centre]); 
    Screen('DrawLines', windowPtr, cue_up_coords,10, green, [x_centre, y_centre]);
    Screen('DrawLines', windowPtr, cue_down_coords,10, green, [x_centre, y_centre]);  
    waiting=1;
    while waiting 
        if (GetSecs - cue_time_max) > 2
            Screen('Flip', windowPtr);
            waiting=0;
        end
    end
    
	%event
    fwrite(SerialPortObj, event_respcue,'sync');
    fwrite(SerialPortObj, 0,'sync');
    
    % Response
    respcue_time_min = GetSecs();
    [s, keyCode_min, delta_min] = KbWait(-3, 2, GetSecs()+1);
    RT_min = s - respcue_time_min;
    %get RT
    if keyCode_max(yes_button) | keyCode_max(no_button)
         RT_min = s - respcue_time_min;
    end
           
    pause(1 - RT_min);

    
    %% Adjustment of weights
    % Keeps track of participant's response (yes=1 is 49, no=2 is 50)
    max_detected = keyCode_max(yes_button);
    mid_detected = keyCode_mid(yes_button);
    min_detected = keyCode_min(yes_button);
    
    %save
    count = count + 3;    
    fprintf(pest_results,'\n%i\t%i\t%2.2f\t%i\t%i\t%2.2f\t%2.2f\t%2.2f\t',...
            count-2,2,max_stim, max_detected,round(RT_max*1000),tap_time_max-cue_time_max,respcue_time_max-cue_time_max,cue_time_max);
    fprintf(pest_results,'\n%i\t%i\t%2.2f\t%i\t%i\t%2.2f\t%2.2f\t%2.2f\t',...
        count-1,1,mid_stim, mid_detected,round(RT_mid*1000),tap_time_mid-cue_time_mid,respcue_time_mid-cue_time_mid,cue_time_mid);
    fprintf(pest_results,'\n%i\t%i\t%2.2f\t%i\t%i\t%2.2f\t%2.2f\t%2.2f\t',...
        count,0,min_stim, min_detected,round(RT_min*1000),tap_time_min-cue_time_min,respcue_time_min-cue_time_min,cue_time_min);
    
    keep_max = [keep_max, max_stim];
    keep_mid = [keep_mid, mid_stim];
    keep_min = [keep_min, min_stim];
    
    keep_max_detected = [keep_max_detected, max_detected];
    keep_mid_detected = [keep_mid_detected, mid_detected];
    keep_min_detected = [keep_min_detected, min_detected];
    
    update = 0;
    
    %%sanity check
    if trial <=3
        max_memory = [max_memory,max_detected];
        if trial==3
            if sum(max_memory)==0
                    text = sprintf('Check in: You''ve reported no detection of strong taps');
                    DrawFormattedText(windowPtr,text,'center','center',white);
                    Screen('Flip',windowPtr)
                    contkeycode(operator_button)=0;
                    while contkeycode(operator_button)==0
                        [s, contkeycode, delta] = KbWait();
                    end
            end
        end
    end
                
    %% Changing Intensities
    % If max,mid,min = 0,0,0 then repeat trials up to 5 times, then quit
    if (max_detected == 0 && mid_detected == 0 && min_detected == 0)           
            if repeat_num >= 5
                threshold_not_reached = false;
                detection_threshold = mid_stim;
                no_detection = true;
            end
            update = 1;
            repeat_num = repeat_num + 1;
            max_stim = max_stim*1.2;
            mid_stim = mid_stim*1.2;
            min_stim = min_stim*1.2;                    
    end
    
    % Check to see if threshold reached
    if (max_detected == 1 && (mid_stim - min_stim) <= delta_threshold)     
        detection_threshold = mid_stim;
        threshold_not_reached = false;     
    end
    
    % If mid detected, move down, if not, move up
    if (max_detected == 1 && mid_detected == 1) 
        update = 2;
        max_stim = mid_stim;
        mid_stim = (min_stim + mid_stim)/2;    
    elseif (max_detected == 1 && mid_detected == 0 && min_detected == 0) 
        update =3;
        min_stim = mid_stim;
        mid_stim = (max_stim + min_stim)/2;   
    end
    if max_stim >=5
        max_stim = 4.5;
        update = 4;
    end
    if mid_stim >=5
        mid_stim = 4.5;
        update = 5;
    end
    %%% what if max is not detected? many scenarios in which nothing
    %%% happens
    fprintf(pest_results,'%i',update)

end
detection_threshold = mid_stim;

% fit psychometric curve
intensities = [keep_max, keep_mid, keep_min];
detections = [keep_max_detected, keep_mid_detections, keep_min_detections];
[b, dev, stats] = glmfit(intensities, detections, 'binomial', 'logit');
logit_fit = glmval(b, intensities, 'logit');
x_80 = (log(0.8 / (1 - 0.8)) - b(1)) / b(2);  % intensity with 0.8 detection rate
x_80_derivative = (b(2) * exp(b(1) - (b(2) * x_80))) / (exp(b(1) - (b(2) * x_80)) + 1)^2;  % slope at target intensity
x_diff_10 = 0.1 / x_80_derivative;  % intensity change that increases or decreases the detection rate by +/-0.1
baseline_stim = x_80;
dev_std_stim = x_diff_10;

% plot 
figure
subplot(1, 2, 1)
hold on
plot(keep_min,'--','Color',[.5 .5 .5])
plot(keep_max,'--','Color',[.5 .5 .5])
plot(keep_mid,'r-','Linewidth',2)
hold off
title('Intensity Updating')
ylabel('Intensity')
xlabel('Trials')
subplot(1, 2, 2)
[I_sorted, I_idx] = sort(intensities);
logit_fit_sorted = logit_fit(I_idx);
plot(intensities, detections, 'ks', I_sorted, logit_fit_sorted, 'r-')
title('Psychometric Curve')
ylabel('Detection Probability')
xlabel('Intensity')
getcd = cd()
cd(output_directory)
print(gcf,'PEST','-dpng')
close all
img = imread('PEST.png');
imageTexture = Screen('MakeTexture', windowPtr, img);
Screen('DrawTexture', windowPtr, imageTexture, [], [], 0);
text = sprintf('End of PEST Procedure');
if trial >= max_trials
    text = sprintf('End of PEST Procedure (max number of trials reached)');
end
if no_detection
    text = sprintf('End of PEST Procedure (no detection for 5 trials)');
end
DrawFormattedText(windowPtr,text,'center',200,white);
Screen('Flip',windowPtr)
contkeycode(operator_button)=0;
contkeycode(repeat_button)=0;
while contkeycode(operator_button)==0 & contkeycode(repeat_button)==0
    [s, contkeycode, delta] = KbWait();
    repeat = 0;
    if contkeycode(repeat_button)
        repeat = 1;
    end
end
cd(getcd)
end
    
