function convert_siemens_skyra(TR,n_im)
[file,path] = uigetfile('F:\1.1_PALS_1TP_RAW_DICOM','Select first DICOM image');
first_dicom = strcat(path,file);
[file,path] = uigetfile('F:\2.1_PALS_1TP_rsfmri','Select corresponding puls file');
base_file_name = strcat(path,file(1:end-5));

%% scan parameters
info = dicominfo(first_dicom);
% info.AcquisitionTime
rec_time = info.AcquisitionTime; hr = str2num(rec_time(1:2)); min = str2num(rec_time(3:4)); sec = str2num(rec_time(5:end));
MPCUstart = (hr*60*60 + min*60 + sec)*1000;
% The first digit pair is hours since midnight (in this case: 10)
% The second digit pair is minutes (in this case: 29)
% The third digit pair is seconds (in this case: 07)
% The four digits after the decimal are ticks or, tenths of a millisecond (in this case: 1650). The trailing two zeros are ignored.
% MPCU miliseconds since midnight

% TR in s
% n_im - number of volumes
sampling = 400; % in Hz
% data points req for regressor
pts = TR*n_im*sampling;

%% ecg
if exist(strcat(base_file_name,'.ecg'))
fileID = fopen(strcat(base_file_name,'.ecg'),'r');
ecg = fgetl(fileID);
footer = textscan(fileID,'%s');
fclose(fileID);

pre = strfind(ecg,'6002');
ecg(1:pre(1)+4) = [];
str_start = strfind(ecg,' 5002');
str_end = strfind(ecg,' 6002');

% remove all non monitoring data
while length(str_end) > 0
    ecg(str_start(1)+1:str_end(1)+5) = [];
    str_start = strfind(ecg,' 5002');
    str_end = strfind(ecg,' 6002'); 
end

%Get time stamps from footer:
for n=1:size(footer{1},1)
    if strcmp(footer{1}(n),'LogStartMDHTime:')  %log start time
        LogStartTime=str2num(footer{1}{n+1});
    end
    if strcmp(footer{1}(n),'LogStopMDHTime:')   %log stop time
        LogStopTime=str2num(footer{1}{n+1});
    end
    if strcmp(footer{1}(n),'LogStartMPCUTime:') %scan start time
        ScanStartTime=str2num(footer{1}{n+1});
    end
    if strcmp(footer{1}(n),'LogStopMPCUTime:')  %scan stop time
        ScanStopTime=str2num(footer{1}{n+1});
    end
end

% in ms
ecg_start = ceil((MPCUstart - ScanStartTime)/1000)*sampling;
ecg_scan_time = ScanStopTime - ScanStartTime;
ecg_log_time = LogStopTime - LogStartTime;

ecg_dat = sscanf(ecg,'%d');
% remove end marker and trigger flags
ecg_dat(end) = [];
ecg_nopeak = ecg_dat(ecg_dat ~= 5000);
ecg_nopeak = ecg_nopeak(ecg_nopeak ~= 6000);
% split into 4 channels
ch1 = ecg_nopeak(1:4:length(ecg_nopeak));
ch2 = ecg_nopeak(2:4:length(ecg_nopeak));
ch3 = ecg_nopeak(3:4:length(ecg_nopeak));
ch4= ecg_nopeak(4:4:length(ecg_nopeak));

% calculate trigger positions
% time_cycle = [];
% trigger = 0;
% count = 0;
% h = waitbar(0,'Detecting triggers...');
% for t = 1:length(ecg_dat)
%     if ecg_dat(t) ~= 5000 && ecg_dat(t) ~= 6000
%         count = count + 1;
%     elseif ecg_dat(t) == 5000
%         trigger = 1;
%     elseif ecg_dat(t) == 6000
%         trigger = 0;    
%     end
%     if count == 4
%         waitbar(t / length(ecg_dat))
%         time_cycle = [time_cycle trigger];
%         count = 0;
%     end
% end
% close(h)
% 
% ends = ceil((length(ch1) - pts)/2);
% 
% 
 ch1_spliced = ch1(ecg_start:ecg_start+pts-1);
% trigger_spliced = time_cycle(ends+1:ends+pts);
fileID = fopen('ecg.txt','w');
for n = 1:length(ch1_spliced)
    fprintf(fileID,'%d\r\n',ch1_spliced(n));
end
fclose(fileID);

end
%% resp
if exist(strcat(base_file_name,'.resp'))
fileID = fopen(strcat(base_file_name,'.resp'),'r');
resp = fgetl(fileID);
footer = textscan(fileID,'%s');
fclose(fileID);

pre = strfind(resp,'6002');
resp(1:pre(1)+4) = [];
str_start = strfind(resp,'5002');
str_end = strfind(resp,'6002');

% remove all non monitoring data
while length(str_end) > 0
    resp(str_start(1):str_end(1)+4) = [];
    str_start = strfind(resp,'5002');
    str_end = strfind(resp,'6002'); 
end

%Get time stamps from footer:
for n=1:size(footer{1},1)
    if strcmp(footer{1}(n),'LogStartMDHTime:')  %log start time
        LogStartTime=str2num(footer{1}{n+1});
    end
    if strcmp(footer{1}(n),'LogStopMDHTime:')   %log stop time
        LogStopTime=str2num(footer{1}{n+1});
    end
    if strcmp(footer{1}(n),'LogStartMPCUTime:') %scan start time
        ScanStartTime=str2num(footer{1}{n+1});
    end
    if strcmp(footer{1}(n),'LogStopMPCUTime:')  %scan stop time
        ScanStopTime=str2num(footer{1}{n+1});
    end
end

% in ms
resp_start = ceil((MPCUstart - ScanStartTime)/1000)*sampling;
resp_scan_time = ScanStopTime - ScanStartTime;
resp_log_time = LogStopTime - LogStartTime;

resp_dat = sscanf(resp,'%d');
ends = ceil((length(resp_dat) - pts)/2);
fprintf("puls - %d, %d/%d\n",length(resp_dat),length(resp_dat(resp_start:end)),pts)
resp_spliced = resp_dat(resp_start:resp_start+pts-1);

fileID = fopen(strcat('resp.txt'),'w');
for n = 1:length(resp_spliced)
    fprintf(fileID,'%d\r\n',resp_spliced(n));
end
fclose(fileID);

end
%% puls
if exist(strcat(base_file_name,'.puls'))
fileID = fopen(strcat(base_file_name,'.puls'),'r');
puls = fgetl(fileID);
footer = textscan(fileID,'%s');
fclose(fileID);

pre = strfind(puls,'6002');
puls(1:pre(1)+4) = [];
str_start = strfind(puls,'5002');
str_end = strfind(puls,'6002');

% remove all non monitoring data
while length(str_end) > 0
    puls(str_start(1):str_end(1)+4) = [];
    str_start = strfind(puls,'5002');
    str_end = strfind(puls,'6002'); 
end

%Get time stamps from footer:
for n=1:size(footer{1},1)
    if strcmp(footer{1}(n),'LogStartMDHTime:')  %log start time
        LogStartTime=str2num(footer{1}{n+1});
    end
    if strcmp(footer{1}(n),'LogStopMDHTime:')   %log stop time
        LogStopTime=str2num(footer{1}{n+1});
    end
    if strcmp(footer{1}(n),'LogStartMPCUTime:') %scan start time
        ScanStartTime=str2num(footer{1}{n+1});
    end
    if strcmp(footer{1}(n),'LogStopMPCUTime:')  %scan stop time
        ScanStopTime=str2num(footer{1}{n+1});
    end
end

% in ms
puls_start = ceil((MPCUstart - ScanStartTime)/1000)*sampling;
puls_scan_time = ScanStopTime - ScanStartTime;
puls_log_time = LogStopTime - LogStartTime;

puls_dat = sscanf(puls,'%d');
ends = ceil((length(puls_dat) - pts)/2);
fprintf("puls - %d, %d/%d\n",length(puls_dat),length(puls_dat(puls_start:end)),pts)
puls_spliced = puls_dat(puls_start:puls_start+pts-1);

fileID = fopen(strcat('puls.txt'),'w');
for n = 1:length(puls_spliced)
    fprintf(fileID,'%d\r\n',puls_spliced(n));
end
fclose(fileID);

end
