function PlotGPIAS_PSTH(varargin)

%plots clustered spiking tuning curve data from djmaus
%
% usage: PlotGPIAS_PSTH(datapath, [channel], [clust], [xlimits],[ylimits], [binwidth])
% (channel, clust, xlimits, ylimits are optional)
% xlimits default to [0 200]
% channel number should be an integer
% clust can be an integer or an array of integers, or defaults to all clusts
%
%Processes data if outfile is not found;

rasters=1;
force_reprocess=1;

if nargin==0
    fprintf('\nno input');
    return;
end
datadir=varargin{1};

try
    channel=varargin{2};
catch
    prompt=('please enter channel number: ');
    channel=input(prompt);
end
if strcmp('char',class(channel))
    channel=str2num(channel);
end
try
    clust=varargin{3};
catch
    clust=[]; %to plot all clusts
end
if strcmp('char',class(clust))
    clust=str2num(clust);
end
try
    xlimits=varargin{4};
catch
    xlimits=[];
end
try
    ylimits=varargin{5};
catch
    ylimits=[];
end
try
    binwidth=varargin{6};
catch
    binwidth=5;
end


t_filename=sprintf('ch%s_simpleclust_0%s.t', channel, clust);


djPrefs;
global pref
cd (pref.datapath);
cd(datadir)

if force_reprocess
    fprintf('\nForce ReProcess')
    ProcessGPIAS_PSTH(datadir,  channel, xlimits, ylimits);
end

if isempty(clust)
    basefn=sprintf('outPSTH_ch%dc*.mat',channel);
    d=dir(basefn);
    numclusters=size(d, 1);
    if numclusters==0
        ProcessGPIAS_PSTH(datadir,  channel, xlimits, ylimits);
        basefn=sprintf('outPSTH_ch%dc*.mat',channel);
        d=dir(basefn);
        numclusters=size(d, 1);
        if numclusters==0
            error('ProcessGPIAS_PSTH: no cluster files found');
        end
    else fprintf('\nno cluster specified\n%d outfiles found', numclusters)
        if numclusters>1 fprintf(' -  will plot all of them');end
    end
    for clustnum=1:numclusters
        
        outfilename{clustnum}=d(clustnum).name;
    end
else %a clust was specified
    outfilename{1}=sprintf('outPSTH_ch%dc%d.mat',channel, clust);
end

for clustindex=1:length(outfilename) %main cluster loop
    fprintf('\nclustindex=%d', clustindex)
    if exist(outfilename{clustindex},'file')
        load(outfilename{clustindex})
    else
        ProcessGPIAS_PSTH(datadir,  channel, xlimits, ylimits);
        load(outfilename{clustindex});
    end
    
    IL=out.IL; %whether there are any interleaved laser trials
    numpulseamps=out.numpulseamps;
    numgapdurs=out.numgapdurs;
    pulseamps=out.pulseamps;
    gapdurs=out.gapdurs;
    gapdelay=out.gapdelay;
    samprate=out.samprate; %in Hz
    mM1ON=out.mM1ON;
    mM1OFF=out.mM1OFF;
    M1ON=out.M1ON;
    M1OFF=out.M1OFF;
    nrepsON=out.nrepsON;
    nrepsOFF=out.nrepsOFF;
    soa=out.soa;
    
    fs=10; %fontsize
    
    % %find optimal axis limits
    if isempty(xlimits)
        xlimits(1)=-1.5*max(gapdurs);
        xlimits(2)=2*soa;
    end
    fprintf('\nusing xlimits [%d-%d]', xlimits(1), xlimits(2))
    
    if isempty(ylimits)
        ymax=0;
        for paindex=1:numpulseamps
            for gdindex=1:numgapdurs
                if isempty(M1OFF)
                    
                    st=mM1ON(gdindex,paindex).spiketimes;
                    nr=nrepsON(gdindex,paindex);
                else
                    st=mM1OFF(gdindex,paindex).spiketimes;
                    nr=nrepsOFF(gdindex,paindex);
                end
                X=xlimits(1):binwidth:xlimits(2); %specify bin centers
                [N, x]=hist(st, X);
                N=N./nr; %normalize to spike rate (averaged across trials)
                N=1000*N./binwidth; %normalize to spike rate in Hz
                ymax= max(ymax,max(N));
            end
        end
        ylimits=[-.3 ymax];
    end
    
    if ~isempty(M1OFF)
        
        %plot the mean tuning curve OFF
        figure
        p=0;
        subplot1(numgapdurs, numpulseamps, 'Max', [.95 .9])
        for paindex=1:numpulseamps
            for gdindex=1:numgapdurs
                p=p+1;
                subplot1(p)
                hold on
                spiketimes1=mM1OFF(gdindex,paindex).spiketimes; %spiketimes are in ms relative to gap termination
                X=xlimits(1):binwidth:xlimits(2); %specify bin centers
                [N, x]=hist(spiketimes1, X);
                N=N./nrepsOFF(gdindex,paindex); %normalize to spike rate (averaged across trials)
                N=1000*N./binwidth; %normalize to spike rate in Hz
                offset=0;
                yl=ylimits;
                inc=(yl(2))/max(nrepsOFF(:));
                if rasters==1
                    for n=1:nrepsOFF(gdindex,paindex)
                        spiketimes2=M1OFF(gdindex,paindex, n).spiketimes;
                        offset=offset+inc;
                        h=plot(spiketimes2, yl(2)+ones(size(spiketimes2))+offset, '.k');
                    end
                end
                bar(x, N,1,'facecolor','k','edgecolor','k');
                
                if gapdurs(gdindex)>0
                    line([0 0],[ylim],'color','m')
                    line(-[(gapdurs(gdindex)) (gapdurs(gdindex))],[ylim],'color','m')
                end
                line(xlimits, [0 0], 'color', 'k')
                ylimits2(2)=ylimits(2)*3;
                ylimits2(1)=-2;
                ylim(ylimits2)
                
                xlim(xlimits)
                set(gca, 'fontsize', fs)
                %set(gca, 'xticklabel', '')
                %set(gca, 'yticklabel', '')
                
            end
        end
        subplot1(1)
        h=title(sprintf('%s: \ntetrode%d cell %d, nreps: %d-%d, OFF',datadir,channel,out.cluster,min(nrepsOFF(:)),max(nrepsOFF(:))));
        set(h, 'HorizontalAlignment', 'center', 'interpreter', 'none', 'fontsize', fs, 'fontw', 'normal')
        
        %label amps and freqs
        p=0;
        for paindex=1:numpulseamps
            for gdindex=1:numgapdurs
                p=p+1;
                subplot1(p)
                vpos=ylimits(2);
                text(xlimits(1), vpos, sprintf('%d', gapdurs(gdindex)), 'color', 'r')
                set(gca, 'yticklabel', '');
            end
        end
        %turn on ytick for bottom-most plot
        set(gca, 'yticklabelmode', 'auto');
        
    end
    
    
    if IL
        %plot the mean tuning curve ON
        figure
        p=0;
        subplot1(numgapdurs, numpulseamps, 'Max', [.95 .9])
        for paindex=1:numpulseamps
            for gdindex=1:numgapdurs
                p=p+1;
                subplot1(p)
                hold on
                spiketimes1=mM1ON(gdindex,paindex).spiketimes; %spiketimes are in ms relative to gap termination
                X=xlimits(1):binwidth:xlimits(2); %specify bin centers
                [N, x]=hist(spiketimes1, X);
                N=N./nrepsON(gdindex,paindex); %normalize to spike rate (averaged across trials)
                N=1000*N./binwidth; %normalize to spike rate in Hz
                offset=0;
                yl=ylimits;
                inc=(yl(2))/max(nrepsON(:));
                if rasters==1
                    for n=1:nrepsON(gdindex,paindex)
                        spiketimes2=M1ON(gdindex,paindex, n).spiketimes;
                        offset=offset+inc;
                        h=plot(spiketimes2, yl(2)+ones(size(spiketimes2))+offset, '.k');
                    end
                end
                bar(x, N,1,'facecolor','g','edgecolor','k');
                
                if gapdurs(gdindex)>0
                    line([0 0],[ylim],'color','m')
                    line(-[(gapdurs(gdindex)) (gapdurs(gdindex))],[ylim],'color','m')
                end
                line(xlimits, [0 0], 'color', 'k')
                ylimits2(2)=ylimits(2)*3;
                ylimits2(1)=-2;
                ylim(ylimits2)
                
                xlim(xlimits)
                set(gca, 'fontsize', fs)
                %set(gca, 'xticklabel', '')
                %set(gca, 'yticklabel', '')
                
            end
        end
        subplot1(1)
        h=title(sprintf('%s: \ntetrode%d cell%d, nreps: %d-%d, ON',datadir,channel,out.cluster,min(nrepsON(:)),max(nrepsON(:))));
        set(h, 'HorizontalAlignment', 'center', 'interpreter', 'none', 'fontsize', fs, 'fontw', 'normal')
        
             %label amps and freqs
        p=0;
        for paindex=1:numpulseamps
            for gdindex=1:numgapdurs
                p=p+1;
                subplot1(p)
                vpos=ylimits(2);
                text(xlimits(1), vpos, sprintf('%d', gapdurs(gdindex)), 'color', 'r')
                set(gca, 'yticklabel', '');
            end
        end
        %turn on ytick for bottom-most plot
        set(gca, 'yticklabelmode', 'auto');
        
    end %plot ON
    
    
    
end %main cluster loop