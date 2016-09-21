function ProcessGPIAS_Behavior(varargin)

%processes accelerometer behavioral data from djmaus
%
% usage: ProcessGPIAS_Behavior(datadir)
% saves to outfile


if nargin==0
    fprintf('\nno input');
    return;
end
datadir=varargin{1};




djPrefs;
global pref
cd (pref.datapath);
cd(datadir)

try
    load notebook.mat
catch
    warning('could not find notebook file')
end

%read messages
messagesfilename='messages.events';
[messages] = GetNetworkEvents(messagesfilename);


%read digital Events
Eventsfilename='all_channels.events';
[all_channels_data, all_channels_timestamps, all_channels_info] = load_open_ephys_data(Eventsfilename);
sampleRate=all_channels_info.header.sampleRate; %in Hz

%all_channels_data is the channel the Events are associated with
% the 0 channel Events are network Events
%all_channels_timestamps are in seconds
%all_channels_info is a struct with the following:
%Eventstype 5 are network events, according to https://open-ephys.atlassian.net/wiki/display/OEW/Network+Events
%   the content of those network event are stored in messages
%   Two network events are saved at the beginning of recording containing the system time and sampling information header.
%Eventstype 3 are TTL (digital input lines) one each for up & down
%eventId is 1 or 0 indicating up or down Events for the TTL signals

%FYI the nodeID corresponds to the processor that was the source of that
%Events or data. Which nodeIds correspond to which processor is listed in
%the settings.xml
%for example, in the test data file I'm working with, 100 is the Rhythm
%FPGA, and 102 is the bandpass filter.

sound_index=0;
for i=1:length(messages)
    str=messages{i};
    str2=strsplit(str);
    timestamp=str2num(str2{1});
    Events_type=str2{2};
    if strcmp(deblank(Events_type), 'StartAcquisition')
        %if present, a convenient way to find start acquisition time
        %for some reason not always present, though
        StartAcquisitionSamples=timestamp;
        StartAcquisitionSec=timestamp/sampleRate;
        check1=StartAcquisitionSamples;
    elseif strcmp(deblank(Events_type), 'Software')
        StartAcquisitionSamples=timestamp;
        StartAcquisitionSec=timestamp/sampleRate;
        check2=StartAcquisitionSamples;
    elseif strcmp(Events_type, 'TrialType')
        sound_index=sound_index+1;
        Events(sound_index).type=str2{3};
        for j=4:length(str2)
            str3=strsplit(str2{j}, ':');
            fieldname=str3{1};
            value=str2num(str3{2});
            Events(sound_index).(fieldname)= value;
        end
        Events(sound_index).message_timestamp_samples=timestamp - StartAcquisitionSamples;
        Events(sound_index).message_timestamp_sec=timestamp/sampleRate - StartAcquisitionSec;
        
        %get corresponding SCT TTL timestamp and assign to Event
        all_SCTs=[];
        for k=1:length(all_channels_timestamps)
            if all_channels_info.eventType(k)==3 & all_channels_info.eventId(k)==1 & all_channels_data(k)==2
                corrected_SCT=all_channels_timestamps(k)-StartAcquisitionSec;
                all_SCTs=[all_SCTs corrected_SCT];
            end
        end
        [idx]=find(all_SCTs>Events(sound_index).message_timestamp_sec, 1); %find first SCT after the message timestamp
        SCTtime_sec=all_SCTs(idx);
        %         SCTtime_sec=SCTtime_sec-StartAcquisitionSec; %correct for open-ephys not starting with time zero
        Events(sound_index).soundcard_trigger_timestamp_sec=SCTtime_sec;
        
    end
end

fprintf('\nNumber of sound events (from network messages): %d', length(Events));
fprintf('\nNumber of hardware triggers (soundcardtrig TTLs): %d', length(all_SCTs));
if length(Events) ~=  length(all_SCTs)
    error('ProcessGPIAS_Behavior: Number of sound events (from network messages) does not match Number of hardware triggers (soundcardtrig TTLs)')
end

if exist('check1', 'var') & exist('check2', 'var')
    fprintf('start acquisition method agreement check: %d, %d', check1, check2);
end

%accelerometer channels are 33, 34, 35
filename=getContinuousFilename('.', 33);
if exist(filename, 'file')~=2 %couldn't find it
    error(sprintf('could not find data file %s in datadir %s', filename, datadir))
end

[scaledtrace, datatimestamps, datainfo] =load_open_ephys_data(filename);





monitor = 0;
if monitor
    %   I'm running the soundcard trigger (SCT) into ai1 as another sanity check.
    SCTfname=getSCTfile(datadir);
    if isempty(SCTfname)
        warning('could not find soundcard trigger file')
    else
        [SCTtrace, SCTtimestamps, SCTinfo] =load_open_ephys_data(SCTfname);
    end
    
    %here I'm loading a data channel to get good timestamps - the ADC timestamps are screwed up
    
    SCTtimestamps=SCTtimestamps-StartAcquisitionSec; %zero timestamps to start of acquisition
    datatimestamps=datatimestamps-StartAcquisitionSec;
    
    %messages is a list of all network event, which includes the stimuli
    %messages sent by djmaus, as well as the "ChangeDirectory" and
    %"GetRecordingPath" messages sent by djmaus, as well as 2 initial system
    %messages. I strip out the stimulus (sound) event and put them in "Events."
    %Events is a list of sound event, which were sent by djmaus with the
    %'TrialType' flag.
    
    figure
    hold on
    SCTtrace=SCTtrace./max(abs(SCTtrace));
    scaledtrace=scaledtrace./max(abs(scaledtrace));
    plot(SCTtimestamps, SCTtrace)
    plot(datatimestamps, scaledtrace, 'm')
    
    hold on
    %plot "software trigs" i.e. network messages in red o's
    for i=1:length(Events)
        plot(Events(i).message_timestamp_sec, .25, 'ro');
        plot(Events(i).soundcard_trigger_timestamp_sec, 1, 'g*');
        text(Events(i).message_timestamp_sec, .5, sprintf('network message #%d', i))
        text(Events(i).soundcard_trigger_timestamp_sec, .5, sprintf('SCT #%d', i))
    end
    
    %all_channels_info.eventType(i) = 3 for digital line in (TTL), 5 for network Events
    %all_channels_info.eventId = 1 for rising edge, 0 for falling edge
    %all_channels_data(i) is the digital input line channel
    
    % plot TTL SCTs in green ^=on, v=off
    for i=1:length(all_channels_timestamps)
        if all_channels_info.eventType(i)==3 & all_channels_info.eventId(i)==1 & all_channels_data(i)==2
            plot(all_channels_timestamps(i), 1, 'g^')
            text(all_channels_timestamps(i), 1, 'TTL on/off')
        elseif all_channels_info.eventType(i)==3 & all_channels_info.eventId(i)==0 & all_channels_data(i)==2
            plot(all_channels_timestamps(i), 1, 'gv')
        end
    end
    
    for i=1:length(Events)
        xlim([Events(i).message_timestamp_sec-.02 Events(i).message_timestamp_sec+.5])
        ylim([-5 2])
        pause(.1)
    end
end %if monitor
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


fprintf('\ncomputing tuning curve...');

samprate=sampleRate;

%get freqs/amps
j=0;
for i=1:length(Events)
    if strcmp(Events(i).type, 'GPIAS')
        j=j+1;
        allsoas(j)=Events(i).soa;
        allgapdurs(j)=Events(i).gapdur;
        allgapdelays(j)=Events(i).gapdelay;
        allpulseamps(j)=Events(i).pulseamp;
        allpulsedurs(j)=Events(i).pulsedur;
        allnoiseamps(j)=Events(i).amplitude;
        
    end
    
end
gapdurs=unique(allgapdurs);
pulsedurs=unique(allpulsedurs);
soas=unique(allsoas);
gapdelays=unique(allgapdelays);
pulseamps=unique(allpulseamps);
pulsedurs=unique(allpulsedurs);
noiseamps=unique(allnoiseamps);
numgapdurs=length(gapdurs);
numpulseamps=length(pulseamps);
nrepsON=zeros( numgapdurs, numpulseamps);
nrepsOFF=zeros( numgapdurs, numpulseamps);

if length(noiseamps)~=1
    error('not able to handle multiple noiseamps')
end
if length(gapdelays)~=1
    error('not able to handle multiple gapdelays')
end
if length(pulsedurs)~=1
    error('not able to handle multiple pulsedurs')
end
if length(soas)~=1
    error('not able to handle multiple soas')
end
noiseamp=noiseamps;
soa=soas;
pulsedur=pulsedurs;
gapdelay=gapdelays;

%check for laser in Events
for i=1:length(Events)
    if isfield(Events(i), 'laser') & isfield(Events(i), 'LaserOnOff')
        LaserScheduled(i)=Events(i).laser; %whether the stim protocol scheduled a laser for this stim
        LaserOnOffButton(i)=Events(i).LaserOnOff; %whether the laser button was turned on
        LaserTrials(i)=LaserScheduled(i) & LaserOnOffButton(i);
        if isempty(stimlog(i).LaserStart)
            LaserStart(i)=nan;
            LaserWidth(i)=nan;
            LaserNumPulses(i)=nan;
            LaserISI(i)=nan;
        else
            LaserStart(i)=stimlog(i).LaserStart;
            LaserWidth(i)=stimlog(i).LaserWidth;
            LaserNumPulses(i)=stimlog(i).LaserNumPulses;
            LaserISI(i)=stimlog(i).LaserISI;
        end
        
    elseif isfield(Events(i), 'laser') & ~isfield(Events(i), 'LaserOnOff')
        %Not sure about this one. Assume no laser for now, but investigate.
        warning('ProcessGPIAS_Behavior: Cannot tell if laser button was turned on in djmaus GUI');
        LaserTrials(i)=0;
        Events(i).laser=0;
    elseif ~isfield(Events(i), 'laser') & ~isfield(Events(i), 'LaserOnOff')
        %if neither of the right fields are there, assume no laser
        LaserTrials(i)=0;
        Events(i).laser=0;
    else
        error('wtf?')
    end
end
fprintf('\n%d laser pulses in this Events file', sum(LaserTrials))
try
    if sum(LaserOnOffButton)==0
        fprintf('\nLaser On/Off button remained off for entire file.')
    end
end
if sum(LaserTrials)>0
    IL=1;
else
    IL=0;
end
%if lasers were used, we'll un-interleave them and save ON and OFF data

M1ON=[];M1OFF=[];
nrepsON=zeros(numgapdurs, numpulseamps);
nrepsOFF=zeros(numgapdurs, numpulseamps);

% %find optimal axis limits
if isempty(xlimits)
    xlimits(1)=-1.5*max(gapdurs);
    xlimits(2)=2*soa;
end
fprintf('\nprocessing with xlimits [%d-%d]', xlimits(1), xlimits(2))

%extract the traces into a big matrix M
j=0;
inRange=zeros(1, Nclusters);
for i=1:length(Events)
    if strcmp(Events(i).type, 'GPIAS') | strcmp(Events(i).type, 'gapinnoise')
        
        pos=Events(i).soundcard_trigger_timestamp_sec; %pos is in seconds
        laser=LaserTrials(i);
        start=pos + gapdelay/1000 +xlimits(1)/1000; %start is in seconds
        stop=pos+ gapdelay/1000 + xlimits(2)/1000; %stop is in seconds
        if start>0 %(disallow negative or zero start times)
            gapdur=Events(i).gapdur;
            gdindex= find(gapdur==gapdurs);
            pulseamp=Events(i).pulseamp;
            paindex= find(pulseamp==pulseamps);
            start=round(pos+xlimits(1)*1e-3*samprate);
            stop=round(pos+xlimits(2)*1e-3*samprate)-1;
            region=start:stop;
            if isempty(find(region<1))
                st_inrange=st(st>start & st<stop); % spiketimes in region, in seconds relative to start of acquisition
                spikecount=length(st_inrange); % No. of spikes fired in response to this rep of this stim.
                inRange(clust)=inRange(clust)+ spikecount; %accumulate total spikecount in region
                spiketimes1=st_inrange*1000 - pos*1000 - gapdelay;%covert to ms after gap termination
                spont_spikecount=length(find(st<start & st>(start-(stop-start)))); % No. spikes in a region of same length preceding response window
                if laser
                    nrepsON(gdindex,paindex)=nrepsON(gdindex,paindex)+1;
                    M1ON(gdindex,paindex, nrepsON(gdindex,paindex),:)=scaledtrace(region);
                    %                     M1ONstim(gdindex, paindex, nrepsON(gdindex, paindex),:)=stim(region);
                else
                    nrepsOFF(gdindex,paindex)=nrepsOFF(gdindex,paindex)+1;
                    M1OFF(gdindex,paindex, nrepsOFF(gdindex,paindex))=scaledtrace(region);
                    %                     M1OFFstim(gdindex, paindex, nrepsON(gdindex, paindex),:)=stim(region);
                end
            end
        end
    end
end

fprintf('\nmin num ON reps: %d\nmax num ON reps: %d', min(nrepsON(:)), max(nrepsON(:)))
fprintf('\nmin num OFF reps: %d\nmax num OFF reps: %d',min(nrepsOFF(:)), max(nrepsOFF(:)))

% Accumulate startle response across trials using peak rectified signal in region
for paindex=1:numpulseamps
    for gdindex=1:numgapdurs; % Hardcoded.
        for k=1:nrepsON(gdindex, paindex);
            traceON=squeeze(M1ON(gdindex,paindex, k, region));
            PeakON(gdindex, paindex, k)=max(abs(traceON));
        end
        for k=1:nrepsOFF(gdindex, paindex);
            traceOFF=squeeze(M1OFF(gdindex,paindex, k, region));
            PeakOFF(gdindex, paindex, k)=max(abs(traceOFF));
        end
        mPeakON(gdindex, paindex)=mean(PeakON(gdindex,paindex, 1:nrepsON(gdindex, paindex)));
        mPeakOFF(gdindex, paindex)=mean(PeakOFF(gdindex,paindex, 1:nrepsOFF(gdindex, paindex)));
        semPeakON(gdindex, paindex)=mean(PeakON(gdindex,paindex, 1:nrepsON(gdindex, paindex)))/sqrt(nrepsON(gdindex, paindex));
        semPeakOFF(gdindex, paindex)=mean(PeakOFF(gdindex,paindex, 1:nrepsOFF(gdindex, paindex)))/sqrt(nrepsOFF(gdindex, paindex));
        
    end
    
    %sanity check that first gapdur is 0 (i.e. control condition)
    if gapdurs(1)~=0
        error('first gapdur is not 0, what is wrong?')
    end
    
    %only makes sense for numgapdurs==2
    percentGPIAS_ON(1)=nan;
    pON(1)=nan;
    percentGPIAS_OFF(1)=nan;
    pOFF(1)=nan;
    for p=2:numgapdurs;
        m1=mPeakON(1, paindex);
        m2=mPeakON(p, paindex);
        percentGPIAS_ON(p)=((m1-m2)/m1)*100;
        A=peakON(1,paindex, 1:nreps(1, paindex));
        B=peakON(p,paindex, 1:nreps(p, paindex));
        [H,pON(p)]=ttest2(A,B);
        fprintf('\nLaser ON  pa:%ddB,', pulseamps(paindex));
        fprintf(' %%GPIAS = %.1f%%, T-test:%d, p-value:%.3f',percentGPIAS_ON,H,pON(p));
    end
    for p=2:numgapdurs;
        m1=mPeakOFF(1, paindex);
        m2=mPeakOFF(p, paindex);
        percentGPIAS_OFF(p)=((m1-m2)/m1)*100;
        A=peakOFF(1,paindex, 1:nreps(1, paindex));
        B=peakOFF(p,paindex, 1:nreps(p, paindex));
        [H,pOFF(p)]=ttest2(A,B);
        fprintf('\nLaser OFF  pa:%ddB,', pulseamps(paindex));
        fprintf(' %%GPIAS = %.1f%%, T-test:%d, p-value:%.3f',percentGPIAS_OFF,H,pOFF(p));
    end
    

end



%save to outfiles
out.IL=IL;

out.M1ON=M1ON;
out.M1OFF=M1OFF;
out.mM1ON=mM1ON;
out.mM1OFF=mM1OFF;
out.PeakON=PeakON;
out.PeakOFF=PeakOFF;
out.mPeakON=mPeakON;
out.mPeakOFF=mPeakOFF;
out.semPeakON=semPeakON;
out.semPeakOFF=semPeakOFF;
out.datadir=datadir;
out.nrepsON=nrepsON;
out.nrepsOFF=nrepsOFF;
out.Events=Events;
out.LaserTrials=LaserTrials;
out.samprate=samprate;

out.percentGPIAS_OFF=percentGPIAS_OFF;
out.pOFF=pOFF;
out.percentGPIAS_ON=percentGPIAS_ON;
out.pON=pON;
    
if IL
    out.LaserStart=unique(LaserStart); %only saving one value for now, assuming it's constant
    out.LaserWidth=unique(LaserWidth);
    out.LaserNumPulses=unique(LaserNumPulses);
else
    out.LaserStart=[];
    out.LaserWidth=[];
    out.Lasernumpulses=[];
end
  

out.numpulseamps = numpulseamps;
out.numgapdurs = numgapdurs;
out.pulseamps = pulseamps;
out.gapdurs = gapdurs;
out.gapdelay = gapdelay;
out.soa=soa;
out.xlimits=xlimits;
out.samprate=samprate;
out.datadir=datadir;
try
    out.nb=nb;
    out.stimlog=stimlog;
    out.user=nb.user;
catch
    out.nb='notebook file missing';
    out.stimlog='notebook file missing';
    out.user='unknown';
end
outfilename=sprintf('outGPIAS_Behavior.mat');
save (outfilename, 'out')





