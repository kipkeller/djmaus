function pulse=MakePulse(varargin)

% NOTE: This was the original header
% function pulse=MakePulse(start,width,height,npulses,isi,samplerate)

global exper pref

% Creates a current/voltage pulse waveform to be sent out via AO
% Input
%   start   -   start of the first pulse after the trigger (ms)
%   width   -   pulse width (ms)
%   height  -   pulse height (pA)
%   npulses -   number of pulses
%   isi     -   inter-stimulus interval, i.e. interval between the end of previous pulse and start of the next pulse
%   duration-   total duration of the pulse(s)
%   samplerate- sampling rate (Hz)
% Output
%   pulse   -   the required square waveform
%
    
pulse=[];

if nargin<2
    return;
end

params=varargin{1};
samplerate=varargin{2};
start=params.start;
width=params.width;
height=params.height;
npulses=params.npulses;
isi=params.isi;
if isfield(params,'channel')
    channel=params.channel; 
else
    channel=1;                  % default channel
end
if isfield(params,'fluctuation')
    fluctuation=params.fluctuation/100; % amplitude fluctuation is in percent
else
    fluctuation=0;
end
    
    pulse_length=(start+npulses*width+(npulses-1)*isi); % in ms
    if isfield(params,'duration')
        if params.duration>pulse_length
            pulse_length=params.duration;
        end
    end
    
    samplerate=samplerate/1000;
    
    %prepare the samples
    pulse=zeros(pulse_length*samplerate,1);
    
    sampled_width=width*samplerate;
    sampled_start=start*samplerate;
    sampled_isi=isi*samplerate;

    pulse_starts=[0:(npulses-1)]';
    sampled_start=max(1,sampled_start); % if sampled_start==0, we would have problems with indices below
    pulse_starts=sampled_start+pulse_starts*(sampled_isi+sampled_width);
    
    widths=0:sampled_width-1;
    
    idx=pulse_starts(:,ones(1,sampled_width))+widths(ones(1,npulses),:);

    heights=height.*ones(npulses,1)+(height*fluctuation).*(randn(npulses,1));
    heights=repmat(heights,1,sampled_width);
    
    pulse(idx)=heights;    

    mode=PatchPreProcess('GetMode');
    switch mode{channel}
        case {'Track','V-Clamp'}
            factor=20;
        case {'I=0','I-Clamp Normal','I-Clamp Fast'}
            factor=2000;
        otherwise
            factor=1;
        end

    pulse=pulse./factor;    % factor for I-clamp with beta==1

    pulse(end)=0;   % just quickly make it 0, so that the pulses don't stay high...