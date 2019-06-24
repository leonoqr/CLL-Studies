function convert_siemens_prisma(TR,n_im)
[file,path] = uigetfile(fullfile('C:\Users\CLL.SGHSWP180006-A\Desktop\FSL_Files\rsfMRI\Tremor'...
    ,'*.log'),'Select PULS file');
base_file_name = strcat(path,file(1:end-4));

[file,path] = uigetfile(fullfile('C:\Users\CLL.SGHSWP180006-A\Desktop\FSL_Files\rsfMRI\Tremor'...
    ,'*.IMA'),'Select first DICOM image');
first_dicom = strcat(path,file);

%% scan parameters
% TR in s
% n_im - number of volumes
sampling = 200; % in Hz
% data points req for regressor
pts = TR*n_im*sampling;

%% 
% Dicom info
info = dicominfo(first_dicom);
rec_time = info.AcquisitionTime; dic_hr = str2num(rec_time(1:2)); 
dic_min = str2num(rec_time(3:4)); dic_sec = str2num(rec_time(5:end));

%% physio (PULS)
fileID = fopen(strcat(base_file_name,'.log'),'r');
puls_data = textscan(fileID,'%s');
fclose(fileID);
puls_data = puls_data{1,1};
header = puls_data(1:19); phy_hr = str2num(header{6}(10:11)); 
phy_min = str2num(header{6}(12:13)); phy_sec = str2num(header{6}(14:15));
puls_data(1:19) = []; % remove headers
puls_num_str =regexp(puls_data,'\d+','match');
puls_num = [];
puls_timing = [];
for n = 1:length(puls_num_str)
    cell_str = char(puls_num_str{n});
    if str2double(cell_str)<5000;
        puls_num = [puls_num; str2double(cell_str)];
    elseif length(cell_str)==8;
        puls_timing = [puls_timing; str2double(cell_str)];
    end
end

%% adjust for timing offset between dicom and phys recording
offset = ((dic_hr-phy_hr)*60*60 + (dic_min-phy_min)*60 + (dic_sec-phy_sec))*200;
if length(puls_timing) < (pts + offset);
    puls_output = puls_num(length(puls_timing)-pts+1:end);
else
    puls_output = puls_num(offset:offset+pts-1);
end

%% write files
fileID = fopen(strcat('puls.txt'),'w');
for n = 1:length(puls_output)
    fprintf(fileID,'%d\r\n',puls_output(n));
end
fclose(fileID);