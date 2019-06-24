function [] = glm_matrix(mcf,w,c,d,n,s,TR)

% Create design matrix for fsl_glm
% ------------------------------------
% INPUTS
% mcf - fsl par file
% card - ecg txt file
% n - volumes discarded
% s - physiological sampling rate
% TR - repititon time
% w - wm signal
% c - csf signal 
% d - DVARS
% ------------------------------------
% OUTPUT
% reg_design - matrix file for fsl_glm
% ------------------------------------

% load files
mov = dlmread(mcf);
wm = dlmread(w);
csf = dlmread(c);
dvars = dlmread(d);

% prepare puls files only if it exists %% modified from ecg flag
if exist('puls.txt')
    ecg_flag = 1;
    card = 'puls.txt';
    ecg = dlmread(card);
    for m = 1:length(ecg)/(TR*s)
        ecg_median(m) = median(ecg(1+(m-1)*s*TR:(m-1)*s*TR+s*TR));
    end
    ecg_median = ecg_median';
    % discard first n volumes
    ecg_median(1:n) = [];
else
    ecg_flag = 0;
    fprintf('\nNo puls file detected\n')
end

% combine all into matrix
switch ecg_flag
    case 0
        reg_design = [dvars wm csf mov];
    case 1
        reg_design = [dvars wm csf mov ecg_median];
end
dlmwrite('reg_design.txt',reg_design,' ');
end