function MakeVarGPIASdjProtocol(noiseamp, gapdurs, gapdelay, post_startle_duration, pulsedur, pulseamps, soa, soaflag, ...
    ramp, isi, isi_var, nrepeats)
% usage MakeVarGPIASdjProtocol(noiseamp, gapdurs, gapdelay, post_startle_duration, 
%       pulsedur, pulseamps, soa, soaflag, ramp, iti, iti_var, interleave_laser, nrepeats)
%
% creates a djmaus stimulus protocol file for GPIAS (gap-induced pre-pulse inhibition of acoustic startle
% response). can use multiple gap durations, gap is silent
% using variable ITI.
%
%this version randomly interleaves trial with a laser pulse for each GPIAS trial,
% the laser is on exactly during the gap. I.e. laser onset coincides with
% gap onset, laser duration matches gap duration


%recent edits: 
%  -updated to djmaus version 9-2016
%  -uses VarLaser params in stimuli to set laser params and ignore djmaus GUI, 9-2016
%  -changed to use whitenoise instead of band-passed noise. 9-2016
%  -added soaflag to specify whether soa is 'soa' or 'isi'
%  -changed gapdelay to specify time to gap offset instead of gap onset (so
%   that ppalaser comes on relative to gap offset in the 'isi' case) (note:
%   this is actually implemented in MakeGPIAS)
%   mw 06.09.2014
%
%NOTE: 
% inputs:
% noiseamp: amplitude of the continuous white noise, in dB SPL
% gapdurs: durations of the pre-pulse gap, in ms, in a vector, e.g. 50, or [0 50]
% gapdelay: delay from start of continuous noise to gap OFFSET, in ms
% post_startle_duration: duration of noise to play after the startle
%       stimulus has finished. We added this Oct 14, 2013 to allow extra time
%       for laser be on after the startle. 
% pulsedur: duration of the startle pulse in ms (can be 0 for no startle)
% pulseamps: amplitudes of the startle pulse in dB SPL, in a vector, e.g. 95, or [90 95 100]
% soa: Stimulus Onset Asynchrony in ms = time between gap onset and
%       startle pulse tone onset
% soaflag: can be either 'soa' (default), in which case soa value specifies the time
% between the onset of the gap and the onset of the startle, or else 'isi',
% in which case soa specifies the time between gap offset and startle
% onset. If anything other than 'isi' it will default to 'soa'.
% ramp: on-off ramp duration in ms
% iti: inter trial interval (onset-to-onset) in ms
% iti_var: fractional variability of iti. Use 0 for fixed iti, or e.g. 0.1 to have iti vary by up to +-10%
% interleave_laser: 0 or 1 to duplicate all stimuli and interleave laser
%            and non-laser trials in random order
% nrepeats: number of repetitions (different pseudorandom orders)
%
% outputs:
% creates a suitably named stimulus protocol in D:\lab\exper2.2\protocols\ASR Protocols
%
%example calls:
% fixed iti of 10 seconds:
%MakeVarGPIASdjProtocol(80, [0 2 4 6], 1000, 1000, 25, 100, 60, 'soa', 0, 10e3, 0, 1, 5)
%
% iti ranging from 10s to 20s (15 s on average)
%
%brief variable duration gaps, 60ms SOA
%MakeVarGPIASdjProtocol(80, [0 2 4 6], 1000, 1000, 25, 100, 60, 'soa', 0, 15e3, .33, 1, 15)
%
%brief gap, no startle, ability to deliver a long (1sec) laser pulse beyond
%startle offset time
%MakeVarGPIASdjProtocol(80, [10], 1000, 1000, 0, 100, 60, 'soa', 0, 15e3, .33, 1, 20)

%note: still using the variable isi for inter-trial interval, AKA iti

interleave_laser=1;
%fixing it to 1, otherwise you wouldn't eb using this function, you would
%use MakeGPIASdjProtocol instead

if ~strcmp(soaflag, 'isi')
    soaflag='soa';
    fprintf('\nusing soa of %d ms', soa)
else
    fprintf('\nusing isi of %d ms', soa)
end

if strcmp(soaflag, 'soa')
    if any(gapdurs>soa)
        fprintf('\n\n!!!!!!!\n\n')
        warning('at least one gap duration exceeds the soa, so that gap duration will be invalid (will be interrupted by startle during the gap)')
    end
end

%if post_startle_duration==0 error('please use a finite post_startle_duration');end

global pref
if isempty(pref) djPrefs;end
if nargin~=12 error('\MakeGPIASdjProtocol: wrong number of arguments.'); end

numgapdurs=length(gapdurs);
numpulseamps=length(pulseamps);

gapdursstring='';
for i=1:numgapdurs
    gapdursstring=[gapdursstring, sprintf('%g-', gapdurs(i))];
end
gapdursstring=gapdursstring(1:end-1); %remove trailing -

pulseampsstring='';
for i=1:numpulseamps
    pulseampsstring=[pulseampsstring, sprintf('%d-', pulseamps(i))];
end
pulseampsstring=pulseampsstring(1:end-1); %remove trailing -

if interleave_laser==1
    [GapdurGrid,PulseampGrid, Lasers]=meshgrid( gapdurs , pulseamps, [0 1]);
    numlasers=2;
else
    [GapdurGrid,PulseampGrid, Lasers]=meshgrid( gapdurs , pulseamps, 0);
    numlasers=1;
end


neworder=randperm( numpulseamps * numgapdurs * numlasers);
rand_gapdurs=zeros(1, size(neworder, 2)*nrepeats);
rand_pulseamps=zeros(1, size(neworder, 2)*nrepeats);
lasers=zeros(1, size(neworder, 2)*nrepeats);


for n=1:nrepeats
    neworder=randperm( numpulseamps * numgapdurs * numlasers);
    rand_gapdurs( prod(size(GapdurGrid))*(n-1) + (1:prod(size(GapdurGrid))) ) = GapdurGrid( neworder );
    rand_pulseamps( prod(size(PulseampGrid))*(n-1) + (1:prod(size(PulseampGrid))) ) = PulseampGrid( neworder );
    lasers( prod(size(Lasers))*(n-1) + (1:prod(size(Lasers))) ) = Lasers( neworder );
end

if interleave_laser
    interleave_laserstr='IL-';
else
    interleave_laserstr='';
end

name= sprintf('GPIAS-VarLaser1-na%ddB-gd%sms-pd%dms-pa%sdb-soa%dms(%s)-r%d-iti%d-itivar%d-%s%dreps.mat',...
    noiseamp, gapdursstring, round(pulsedur), pulseampsstring, soa,soaflag, round(ramp), isi,round(100*isi_var),interleave_laserstr, nrepeats);

description=sprintf('GPIAS protocol with Var Laser on exactly during the gap, noise amp:%ddB, gap duration: %sms, gapdelay: %dms, pulse duration%dms pulse amplitude:%sdb SOA:%dms (%s) ramp:%dms iti:%dms iti-var: %.1f %s %drepeats',...
    noiseamp, gapdursstring, gapdelay, pulsedur, pulseampsstring, soa, soaflag, ramp, isi,round(100*isi_var),interleave_laserstr, nrepeats);
filename=name;


gpias_duration=gapdelay+max(rand_gapdurs)+soa+pulsedur+post_startle_duration; %actual duration

%note: for seamless playing of sounds, all buffers must be identical in
%length. So we are making short noise segments and using variable numbers
%of them

%next=-2000;%totally empirical value that allows psychportaudio rescheduling to work seamlessly
%was -1000, trying new values to get it working on Rig 2
next = -gapdelay/2;%testing mw 032410
%next = -.9*gapdelay;%testing mw 06.11.2014

this_isi_ms=round(isi+isi*isi_var*(2*rand(1)-1));
num_noises=round(this_isi_ms/gpias_duration);


n=0;

for noisenum=1:num_noises

    n=n+1;

    stimuli(n).type='whitenoise';
    stimuli(n).param.amplitude=noiseamp;
    stimuli(n).param.ramp=ramp;
    stimuli(n).param.loop_flg=0;
    stimuli(n).param.seamless=1;
    %     stimuli(n).param.duration=500;
    stimuli(n).param.duration=gpias_duration;
    stimuli(n).param.next=next; %totally empirical value that allows psychportaudio rescheduling to work seamlessly

    paramstring=sprintf('whitenoise %d dB, %g ms ramp, %d ms dur, %d ms isi',noiseamp, ramp, gpias_duration, next);
    stimuli(n).protocol_name=name;
    stimuli(n).stimulus_description=paramstring;
    stimuli(n).protocol_description=description;
    stimuli(n).version='djmaus';
    stimuli(n).param.VarLaser=0;
end

for kk=1:length(rand_gapdurs)

    n=n+1;
    stimuli(n).type='GPIAS';
    stimuli(n).param.amplitude=noiseamp;
    stimuli(n).param.ramp=ramp;
    stimuli(n).param.soa=soa;
    stimuli(n).param.soaflag=soaflag;
    stimuli(n).param.loop_flg=0;
    stimuli(n).param.seamless=1;
    stimuli(n).param.duration=gpias_duration;
    stimuli(n).param.next=next; %totally empirical value that allows psychportaudio rescheduling to work seamlessly
    stimuli(n).param.gapdelay=gapdelay;
    stimuli(n).param.gapdur=rand_gapdurs(kk);
    stimuli(n).param.pulsedur=pulsedur;
    stimuli(n).param.pulseamp=rand_pulseamps(kk);
    stimuli(n).param.laser=lasers(kk);
    if lasers(kk) laserstr='Var laser ON'; else laserstr='laser OFF';end
        paramstring= sprintf('GPIAS  %d dB, %g ms ramp, %d ms SOA, soa-type: %s, %d ms GPIAS dur, %d gapdelay, %d ms gap dur, %d ms pulse dur, %d dB pulseamp, %d ms isi, %s',...
            noiseamp, ramp, soa, soaflag, gpias_duration, gapdelay, stimuli(n).param.gapdur, pulsedur, stimuli(n).param.pulseamp, next, laserstr);    
    stimuli(n).protocol_name=name;
    stimuli(n).stimulus_description=paramstring;
    stimuli(n).protocol_description=description;
    stimuli(n).version='djmaus';
    if lasers(kk)
        stimuli(n).param.VarLaser=1;
        stimuli(n).param.VarLaserstart=gapdelay-stimuli(n).param.gapdur; %for example.  laser onset coincides w/ gap onset
        stimuli(n).param.VarLaserpulsewidth=stimuli(n).param.gapdur; %for example
        stimuli(n).param.VarLasernumpulses=1;
        stimuli(n).param.VarLaserisi=0; %not used
    else
        stimuli(n).param.VarLaser=0;
    end
    
    %
    this_isi_ms=round(isi+isi*isi_var*(2*rand(1)-1));
    num_noises=round(this_isi_ms/gpias_duration);
    for noisenum=1:num_noises
        n=n+1;
        stimuli(n).type='whitenoise';
        stimuli(n).param.amplitude=noiseamp;
        stimuli(n).param.ramp=ramp;
        stimuli(n).param.loop_flg=0;
        stimuli(n).param.seamless=1;
        stimuli(n).param.duration=gpias_duration; %trying to set to same dur as gpias
        stimuli(n).param.next=next; %totally empirical value that allows psychportaudio rescheduling to work seamlessly
        
        paramstring=sprintf('whitenoise %d dB, %g ms ramp, %d ms dur, %d ms isi',noiseamp, ramp, gpias_duration, next);
        stimuli(n).protocol_name=name;
        stimuli(n).stimulus_description=paramstring;
        stimuli(n).protocol_description=description;
        stimuli(n).version='djmaus';
        stimuli(n).param.VarLaser=0;
    end

end


cd(pref.stimuli) %where stimulus protocols are saved
warning off MATLAB:MKDIR:DirectoryExists
mkdir('GPIAS Protocols')
cd('GPIAS Protocols')
save(filename, 'stimuli')

fprintf('\nwrote file %s \n in directory %s', filename, pwd)
