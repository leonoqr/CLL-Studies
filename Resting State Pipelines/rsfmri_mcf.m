%% set up movement matrix using par files
files = dir('data');

% count P and C
p_no = 0;
c_no = 0;
mov_mat={};
status = [];
for n = 3:length(files)
    f_name = files(n).name;
    if endsWith(f_name,'C')
        c_no = c_no + 1;
        status(n-2,1) = 0;
    end
    if endsWith(f_name,'P')
        p_no = p_no + 1;
        status(n-2,1) = 1;
    end
    mov_mat{n-2} = dlmread(strcat('data/',f_name,'/',f_name,...
        '_rsfmri_mcf.par'),'');
end

%% absolute mean, sd, maximum displacement
rel_mat = {};
for n = 1:length(mov_mat)
    abs_mean(n,:) = mean(abs(mov_mat{n}));
    abs_std(n,:) = std(mov_mat{n});
    % find greatest intra slice motion
    for m = 1:length(mov_mat{n})-1
        interslice(m,:) = abs(mov_mat{n}(m,:) - mov_mat{n}(m+1,:));
    end
    rel_mat{n} = interslice;
    rel_mean(n,:) = mean(interslice);
    rel_std(n,:) = std(interslice);
end
%% save struct
rsf_movement.individual_abs_motion = mov_mat;
rsf_movement.individual_rel_motion = rel_mat;
rsf_movement.abs_mov.mean = abs_mean;
rsf_movement.abs_mov.std = abs_std;
rsf_movement.rel_mov.mean = rel_mean; 
rsf_movement.rel_mov.std = rel_std;
rsf_movement.groupstats.PD_no = p_no;
rsf_movement.groupstats.HC_no = c_no;


%% calculate displacement
for n = 1:length(rsf_movement.individual_rel_motion);
    %absolute
    rot_x = rsf_movement.individual_abs_motion{1,n}(:,1);
    rot_y = rsf_movement.individual_abs_motion{1,n}(:,2);
    rot_z = rsf_movement.individual_abs_motion{1,n}(:,3);
    d = rsf_movement.individual_abs_motion{1,n}(:,4:6);
    for m = 1:length(rot_x);
        A = rot_x(m);
        B = rot_y(m);
        C = rot_z(m);
        Rx = [1 0 0; 0 cos(A) -sin(A); 0 sin(A) cos(A)];
        Ry = [cos(B) 0 sin(B); 0 1 0; -sin(B) 0 cos(B)];
        Rz = [cos(C) -sin(C) 0; sin(C) cos(C) 0; 0 0 1];
        d_xyz = Rx*Ry*Rz*d(m,:)';
        rsf_movement.individual_abs_motion{1,n}(m,7) = sqrt(d_xyz(1)^2 + d_xyz(2)^2 + d_xyz(3)^2);
    end
    %relative
    rot_x = rsf_movement.individual_rel_motion{1,n}(:,1);
    rot_y = rsf_movement.individual_rel_motion{1,n}(:,2);
    rot_z = rsf_movement.individual_rel_motion{1,n}(:,3);
    d = rsf_movement.individual_rel_motion{1,n}(:,4:6);
    
    for m = 1:length(rot_x);
        A = rot_x(m);
        B = rot_y(m);
        C = rot_z(m);
        Rx = [1 0 0; 0 cos(A) -sin(A); 0 sin(A) cos(A)];
        Ry = [cos(B) 0 sin(B); 0 1 0; -sin(B) 0 cos(B)];
        Rz = [cos(C) -sin(C) 0; sin(C) cos(C) 0; 0 0 1];
        d_xyz = Rx*Ry*Rz*d(m,:)';
        rsf_movement.individual_rel_motion{1,n}(m,7) = sqrt(d_xyz(1)^2 + d_xyz(2)^2 + d_xyz(3)^2);
    end
    
    rsf_movement.abs_mov.mean(n,7) = mean(rsf_movement.individual_abs_motion{1,n}(:,7));
    rsf_movement.abs_mov.std(n,7) = mean(rsf_movement.individual_abs_motion{1,n}(:,7));
    rsf_movement.rel_mov.mean(n,7) = mean(rsf_movement.individual_rel_motion{1,n}(:,7));
    rsf_movement.rel_mov.std(n,7) = std(rsf_movement.individual_rel_motion{1,n}(:,7));
end

%% calculate group stats

rsf_movement.groupstats.abs_mean = mean(rsf_movement.abs_mov.mean);
rsf_movement.groupstats.abs_max = max(rsf_movement.abs_mov.mean);
rsf_movement.groupstats.abs_std = std(rsf_movement.abs_mov.std);
rsf_movement.groupstats.rel_mean = mean(rsf_movement.rel_mov.mean);
rsf_movement.groupstats.rel_max = max(rsf_movement.rel_mov.mean);
rsf_movement.groupstats.rel_std = std(rsf_movement.rel_mov.std);

save('rsf_movement.mat','rsf_movement');


%% number of frames per participant
% number of frames left after threshold
rel_mov_thresh = 0.3;
abs_mov_thresh = 0.3;
frames_thresh = 140;
for n = 1:length(status); 
    clear usable_rel
    usable_rel = rsf_movement.individual_rel_motion{1,n}(:,7)<rel_mov_thresh;
    usable_rel = [1; usable_rel];
    residual_abs = sum(rsf_movement.individual_abs_motion{1,n}(:,7).*usable_rel)/sum(usable_rel);
    status(n,2)=sum(usable_rel);
    status(n,3)=(status(n,2)>frames_thresh && residual_abs < abs_mov_thresh);
end

PD_usable = sum((status(status(:,3)==1))==1);
HC_usable = sum((status(status(:,3)==1))==0);
fprintf("PD - %d / %d \n HC - %d / %d\n", PD_usable, p_no, HC_usable, c_no);
    
%% write names to text file
fileID = fopen('subjects.txt','w');
for n = 3:length(files)
    if status(n-2,3)==1
        fprintf(fileID,'%s\r\n',files(n).name);
    end
end
fclose(fileID);

fileID = fopen('subjects_high_mov.txt','w');
for n = 3:length(files)
    if status(n-2,3)==0
        fprintf(fileID,'%s\r\n',files(n).name);
    end
end
fclose(fileID);
