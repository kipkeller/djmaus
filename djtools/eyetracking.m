clear all
dbstop if error

dir = pwd; %E:\djmaus-data\iraira\2017-11-26_16-15-50_mouse-7827
filename = '2018-06-11_11-43-31.mp4'; %data file
thresh = 0.87; %pupil threshold for binarization
puprange = [5 100]; %set

%%closed loop parameters
pupercent = 0.15; %set range pupil radius window
pupchange = 0.25; %acceptable percent change in radius per framerange
framerange = 1; %number of frames to smooth over
a=VideoReader(filename);
length1=a.Duration*a.FrameRate;
j=0;
%collect all frames in matrix data
for i=1:10:length1-10
j=j+1;    
frame=read(a,i); %read frame one by one
grey_frame= rgb2gray(frame); %convert to grey scale
data(:,:,j) = squeeze(grey_frame); %get rid of color D
warning off;
end


%user input to select center and right points
sprintf('Please select pupil center and top, eyeball top and right points, darkest part of eyeball')
h1 = figure('units','normalized','outerposition',[0 0 1 1])
imshow(data(:,:,1)) %use the first frame to 
[cent] = ginput(5);
close(h1);
yc = cent(1,2); %pupil center y val
xc = cent(1,1); %pupil center x val 
horiz = (cent(4,1) - xc); %1/2 x search range
vert = (yc - cent(3,2)); %1/2 y search range
puprad = yc - cent(2,2); %initial pupil radius
% puprange = [round(puprad - puprad*pupercent) round(puprad + puprad*pupercent)]; %range of pupil sizes to search over
%ddata = double(data); 
ddata=data;
binmaxx = cent(5,1);
binmaxy = cent(5,2);
for i = 1:size(data,3)
    binmax(i) = mean(mean(mean(ddata(binmaxy-3:binmaxy+3,binmaxx-3:binmaxx+3,i))));
end
for i = 1:size(ddata,3)
%     bindata(:,:,i) = (ddata(yc-vert:yc+vert,xc-horiz:xc+horiz,i)/binmax(i) > thresh);

bindata(:,:,i)=imbinarize(ddata(:,:,i), 'adaptive', 'ForegroundPolarity', 'dark');
se = strel('disk',2);
ddata(:,:,i) = bwareaopen(ddata(:,:,i),10);
bindata(:,:,i)=imclose(bindata(:,:,i),se);
end

figure
imshow(bindata(:,:,size(bindata,3)))

%convert from uint8 into doubles and threshold, then binarize

tic
centroid = nan(size(data,3),2);
rad = nan(size(data,3),1);
centroid(1,:) = [horiz vert];
rad(1,1) = puprad;
for n = 2:size(data,3)
    find_best_fit=[];
    [center,radii,metric] = imfindcircles(bindata(:,:,n),puprange,'Sensitivity',0.885, 'ObjectPolarity','dark','Method','PhaseCode', 'EdgeThreshold',.7);
    if(isempty(center))
        centroid(n,:) = [NaN NaN]; % could not find anything...
        rad(n) = NaN;
    else
        for idx=1:length(metric)
        find_best_fit(idx)=abs(diff([radii(idx),mean(rad(1:n-1))]))+ abs(diff([center(idx,1),mean(centroid(1:n-1,1))]))+ abs(diff([center(idx,2),mean(centroid(1:n-1,2))]))-metric(idx)*2;
        end   
        
        [~,idx] = min(find_best_fit); % pick the circle with best score
        
        centroid(n,:) = center(idx,:);
        rad(n,:) = radii(idx);
    end
%     imshow(bindata(:,:,n));
%     circle2(center(:,1),center(:,2),radii)
    %%closed loop execution
%     if n>framerange && (isnan(rad(n-1)) | isnan(rad(n))) %if it's a nan or preceeded by all nans don't change puprange
%         puprange = puprange;
%     elseif n>framerange && (abs(1 - rad(n)/nanmean(rad(n-framerange:n-1))) > pupchange) %if % change is bigger than specified don't change puprange
%         puprange = puprange;
%     elseif n>framerange && (rad(n)>nanmean(rad(n-framerange:n-1))) %if radius goes up, shift range up
%         puprange = puprange + round(rad(n) - nanmean(rad(n-1)));
%     elseif n>framerange && (rad(n)<nanmean(rad(n-framerange:n-1))) %if radius goes down, shift range down
%         puprange = puprange - round(nanmean(rad(n-1)) - rad(n));
%     else
%         puprange = puprange;
%     end
end
toc
%plot x and y position and radius across experiment
h2 = figure
hold on
plot(0.1:0.1:size(data,3)/10,rad,'b-')
plot(0.1:0.1:size(data,3)/10,centroid(:,1),'.g')
plot(0.1:0.1:size(data,3)/10,centroid(:,2),'.r')
hold off
legend('radius','x pos','ypos')
ylim([5 55])

% %
h3 = figure
for i = 1:size(data,3)
 
    subplot(1,2,1)
    imshow(data(yc-vert:yc+vert,xc-horiz:xc+horiz,i));
    colormap gray
    hold on
    circle2(centroid(i,1),centroid(i,2),rad(i))
    drawnow
    hold off
    
    subplot(1,2,2)
    imshow(bindata(:,:,i));
    colormap gray
    hold on
    circle2(centroid(i,1),centroid(i,2),rad(i))
    drawnow
    hold off 

end

%%%%%
name='pdr.mat';


  save(name,'centroid','rad','h2','-append');


