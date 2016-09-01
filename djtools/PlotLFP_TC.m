function PlotLFP_TC(varargin)

% usage: PlotILTC_OE(datafile, [xlimits],[ylimits],[channel])
% (xlimits & ylimits are optional)
% xlimits default to [0 200]
% channel number must be a string
%
%Processes data if outfile is not found; ProcessTC is only used to find
%correct data files
%ira 04-01-2014
%

datadir=varargin{1};

try
    xlimits=varargin{3};
catch
    xlimits=[0 200];
end
try
    ylimits=varargin{4};
catch
    ylimits=[];
end
try
    channel=varargin{2};
catch
    prompt=('please enter channel number: ');
    channel=input(prompt);
end
if strcmp('char',class(channel))
    channel=str2num(channel);
end
high_pass_cutoff=400;
[a,b]=butter(1, high_pass_cutoff/(30e3/2), 'high');
fprintf('\nusing xlimits [%d-%d]', xlimits(1), xlimits(2))

djPrefs;
global pref
cd (pref.datapath);
cd(datadir)
outfilename=sprintf('outLFP_ch%d.mat',channel);
if exist(outfilename,'file')
    load(outfilename)
else
    ProcessLFP_TC(datadir,  channel, xlimits, ylimits);
    load(outfilename);
end



M1stim=out.M1stim;
freqs=out.freqs;
amps=out.amps;
durs=out.durs;
nreps=out.nreps;
numfreqs=out.numfreqs;
numamps=out.numamps;
numdurs=out.numdurs;
samprate=out.samprate; %in Hz
M1=out.M1;
scaledtrace=out.scaledtrace;
traces_to_keep=out.traces_to_keep;
mM1=out.mM1;
mM1ON=out.mM1ON;
mM1OFF=out.mM1OFF;
nrepsON=out.nrepsON;
nrepsOFF=out.nrepsOFF;


% %find optimal axis limits
if isempty(ylimits)
    ylimits=[0 0];
    for dindex=1:numdurs
        for aindex=numamps:-1:1
            for findex=1:numfreqs
                trace1=squeeze(mM1(findex, aindex, dindex, :));
%                 trace1=filtfilt(b,a,trace1);
                trace1=trace1-mean(trace1(1:100));
                if min([trace1])<ylimits(1); ylimits(1)=min([trace1]);end
                if max([trace1])>ylimits(2); ylimits(2)=max([trace1]);end
            end
        end
    end
end
ylimits=round(ylimits*100)/100;

%plot the mean tuning curve BOTH
for dindex=1:numdurs
    figure
    p=0;
    subplot1(numamps,numfreqs)
    for aindex=numamps:-1:1
        for findex=1:numfreqs
            p=p+1;
            subplot1(p)
            %
            %             for i=1:length(nrepsON)
            %             end
            %             trace1=squeeze(squeeze(meanONbl(findex, aindex, dindex, :)));
            %             trace2=(squeeze(meanOFFbl(findex, aindex, dindex, :)));
            trace1=squeeze(squeeze(out.mM1ON(findex, aindex, dindex, :)));
            trace2=(squeeze(out.mM1OFF(findex, aindex, dindex, :)));
            
            trace1=trace1 -mean(trace1(1:10));
            trace2=trace2-mean(trace2(1:10));
%             trace1=filtfilt(b,a,trace1);
%             trace2=filtfilt(b,a,trace2);
            t=1:length(trace1);
            t=1000*t/out.samprate; %convert to ms
            t=t+out.xlimits(1); %correct for xlim in original processing call
            line([0 0+durs(dindex)], [0 0], 'color', 'm', 'linewidth', 5)
            plot(t, trace1, 'b');
            hold on; plot(t, trace2, 'k');
            %ylim([-5000 5000])
            ylim(ylimits)
            xlim(xlimits)
            box off
            
        end
    end
    subplot1(1)
    h=title(sprintf('%s: %dms, nreps: %d-%d, ON&OFF',datadir,durs(dindex),min(min(min(nrepsOFF))),max(max(max(nrepsOFF)))));
    set(h, 'HorizontalAlignment', 'left')
    
    %label amps and freqs
    p=0;
    for aindex=numamps:-1:1
        for findex=1:numfreqs
            p=p+1;
            subplot1(p)
            if findex==1
                text(-400, mean(ylimits), int2str(amps(aindex)))
            end
            if aindex==1
                if mod(findex,2) %odd freq
                    vpos=ylimits(1)-mean(ylimits);
                else
                    vpos=ylimits(1)-mean(ylimits);
                end
                text(xlimits(1), vpos, sprintf('%.1f', freqs(findex)/1000))
            end
        end
    end
end

%plot the mean tuning curve OFF
for dindex=1:numdurs
    figure
    p=0;
    subplot1(numamps,numfreqs)
    for aindex=numamps:-1:1
        for findex=1:numfreqs
            p=p+1;
            subplot1(p)
            trace1=squeeze(mM1OFF(findex, aindex, dindex, :));
%             trace1=filtfilt(b,a,trace1);
            trace1=trace1 -mean(trace1(1:100));
            
            t=1:length(trace1);
            t=1000*t/out.samprate; %convert to ms
            t=t+out.xlimits(1); %correct for xlim in original processing call
            line([0 0+durs(dindex)], [0 0], 'color', 'm', 'linewidth', 5)
            hold on; plot(t, trace1, 'k');
            ylim(ylimits)
            xlim(xlimits)
            xlabel off
            ylabel off
            axis off
        end
    end
    subplot1(1)
    h=title(sprintf('OFF %s: %dms, nreps: %d-%d',datadir,durs(dindex),min(min(min(nrepsOFF))),max(max(max(nrepsOFF)))));
    set(h, 'HorizontalAlignment', 'left')
    
    %label amps and freqs
    p=0;
    for aindex=numamps:-1:1
        for findex=1:numfreqs
            p=p+1;
            subplot1(p)
            if findex==1
                text(-400, mean(ylimits), int2str(amps(aindex)))
            end
            if aindex==1
                if mod(findex,2) %odd freq
                    vpos=ylimits(1)-mean(ylimits);
                else
                    vpos=ylimits(1)-mean(ylimits);
                end
                text(xlimits(1), vpos, sprintf('%.1f', freqs(findex)/1000))
            end
            %             if findex==numfreqs && aindex==numamps
            %                 axis on
            %                 ylab=[ceil(ylimits(1)*10)/10 floor(ylimits(2)*10)/10];
            %                 set(gca,'ytick',ylab,'yticklabel',ylab,'YAxisLocation','right')
            %             end
        end
    end
end

%% plot on
for dindex=1:numdurs
    figure
    p=0;
    subplot1(numamps,numfreqs)
    for aindex=numamps:-1:1
        for findex=1:numfreqs
            p=p+1;
            subplot1(p)
            axis off
            
            trace1=squeeze(mM1ON(findex, aindex, dindex, :));
%             trace1=filtfilt(b,a,trace1);
            trace1=trace1 -mean(trace1(1:100));
            t=1:length(trace1);
           t=1000*t/out.samprate; %convert to ms
            t=t+out.xlimits(1); %correct for xlim in original processing call
             line([0 0+durs(dindex)], [0 0], 'color', 'm', 'linewidth', 5)
            hold on; plot(t, trace1, 'b');
            ylim(ylimits)
            xlim(xlimits)
            axis off
            
        end
    end
    subplot1(1)
    h=title(sprintf('ON %s: %dms, nreps: %d-%d',datadir,durs(dindex),min(min(min(nrepsON))),max(max(max(nrepsON)))));
    set(h, 'HorizontalAlignment', 'left')
    
    %label amps and freqs
    p=0;
    for aindex=numamps:-1:1
        for findex=1:numfreqs
            p=p+1;
            subplot1(p)
            if findex==1
                text(-400, mean(ylimits), int2str(amps(aindex)))
            end
            if aindex==1
                if mod(findex,2) %odd freq
                    vpos=ylimits(1)-mean(ylimits);
                else
                    vpos=ylimits(1)-mean(ylimits);
                end
                text(xlimits(1), vpos, sprintf('%.1f', freqs(findex)/1000))
            end
            %             if findex==numfreqs && aindex==numamps
            %                 axis on
            %                 ylab=[ceil(ylimits(1)*10)/10 floor(ylimits(2)*10)/10];
            %                 set(gca,'ytick',ylab,'yticklabel',ylab,'YAxisLocation','right')
            %             end
        end
    end
end

