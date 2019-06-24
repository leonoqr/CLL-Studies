clear all; clc;

images = 200;
TR = 2.5;
freq = 496;
exp_samples = images*TR*freq;

fileID = fopen('phys_run2.log','r');
% 11 params
data = textscan(fileID,'%d %d %d %d %d %d %d %d %d %d %d','delimiter','\n','headerlines',6);
fclose(fileID);

ecg_signal = data{1,4} - data{1,3};
resp_signal = data{1,6};
puls_signal = data{1,5};
align_l = floor((length(ecg_signal) - exp_samples)/2);
ecg_signal = ecg_signal(align_l+1:(align_l+exp_samples));
resp_signal = resp_signal(align_l+1:(align_l+exp_samples));
puls_signal = puls_signal(align_l+1:(align_l+exp_samples));

w_file = fopen('txt_ecg.txt','w'); 
for n=1:length(ecg_signal)
    fprintf(w_file,'%d\r\n',ecg_signal(n));
end
fclose(w_file);

w_file = fopen('txt_resp.txt','w'); 
for n=1:length(resp_signal)
    fprintf(w_file,'%d\r\n',resp_signal(n));
end
fclose(w_file);

w_file = fopen('txt_puls.txt','w'); 
for n=1:length(puls_signal)
    fprintf(w_file,'%d\r\n',puls_signal(n));
end
fclose(w_file);