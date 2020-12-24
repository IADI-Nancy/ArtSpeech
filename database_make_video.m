function database_make_video(dataset_dir, i_subject, series)
    [images, DicomInfos] = load_dicom_files([dataset_dir, '/P', num2str(i_subject),...
                '/DCM_2D/S', num2str(series)]);
    [sound_recording, fs] = audioread([dataset_dir, '/P', num2str(i_subject), '/OTHER/S', num2str(series),...
                '/DENOISED_SOUND_P', num2str(i_subject), '_S', num2str(series), '.wav']);
    trs = parce_trs([dataset_dir, '/P', num2str(i_subject), '/OTHER/S', num2str(series),...
                '/TEXT_ALIGNMENT_P', num2str(i_subject), '_S', num2str(series), '.trs']);
    tg_sound = tgRead([dataset_dir, '/P', num2str(i_subject), '/OTHER/S', num2str(series),...
                '/TEXT_ALIGNMENT_P', num2str(i_subject), '_S', num2str(series), '.textgrid']);
    [Nx, Ny, n_frames] = size(images);
    step = length(sound_recording) / n_frames;
    FrameRate =  fs / step;

    Min_images = min(images(:));
    Max_images = max(images(:));
    time_x = 0.5/FrameRate:1/FrameRate:(n_frames - 0.5)/FrameRate;
    time_x_sound =  1/fs:1/fs:length(sound_recording)/fs;
    videoFWriter = vision.VideoFileWriter([dataset_dir, '/P', num2str(i_subject), '/OTHER/S', num2str(series),...
        '/VIDEO_P', num2str(i_subject), '_S', num2str(series), '.avi'], 'AudioInputPort', true,...
        'FrameRate',  fs / step, 'FileFormat', 'AVI');
    h = figure('Position', [200, 300, 600, 600]);
    for index = 1:n_frames
        idx_begin = round(step * (index - 1) + 1);
        time_astali = time_x(index);
     
        sp1 = subplot(2, 1, 2);
        set(sp1, 'Units', 'normalized');
        set(sp1, 'Position', [0, 0.1, 1, 0.2]);
        plot(time_x_sound, sound_recording);
        line([time_x(index), time_x(index)], [- 1, 1], 'Color', 'r');
        idx = get_sentence_idx(trs, time_astali);
        if idx ~= -1
            title(trs{idx}{3}, 'FontSize', 8);
        end
        xlim([time_x(index) - 1, time_x(index) + 1]);
        ylim([-1, 1]);
        
        sp2 = subplot(2, 1, 1);
        set(sp2, 'Units', 'normalized');
        set(sp2, 'Position', [0, 0.36, 1, 0.6]);

        imshow(images(:,:,index),[Min_images,  Max_images ]);

        text(2,double(Ny)*0.03,sprintf('S%d',series),'Color','yellow');
        text(2,double(Ny)*0.97,sprintf('I%d',index),'Color','yellow');
        word = get_word(tg_sound, time_astali);%
        text(double(Nx)*0.38,double(Ny)*0.97, sprintf(word), 'Color', 'yellow');
        phoneme = get_phoneme(tg_sound, time_astali);%
        text(double(Nx)*0.45,double(Ny)*0.03, sprintf(phoneme),'Color','yellow');
        
        frame = getframe(h);
        im = frame2im(frame);
        videoFWriter(im, sound_recording(idx_begin : idx_begin + round(step - 1)));
    end
    release(videoFWriter);
end

function [images, infos] = load_dicom_files(workdir)
    files = dir([workdir, '/']);
    info = dicominfo([workdir '/' files(3).name], 'UseDictionaryVR', true);
    images = zeros(info.Rows, info.Columns, length(files) - 2);
    infos = cell(length(files) - 2, 1);
    for i = 3:length(files)
        info = dicominfo([workdir '/' files(i).name], 'UseDictionaryVR', true);
        filename = [workdir '/' files(i).name];
        idx = info.InstanceNumber;
        images(:,:,idx) = dicomread([workdir '/' files(i).name]);
        infos{idx} = info;
    end
    is_zero = true;
    first_image = 1;
    while is_zero
        if images(:,:,first_image) == zeros(size(images, 1), size(images, 2))
            first_image = first_image + 1;
        else
            is_zero = false;
        end
    end
    images = images(:,:,first_image:end);
end

function label = get_word(tg_sound, time)
    ind = tgGetIntervalIndexAtTime(tg_sound, 1, time);
    if ~isnan(ind)
        label = tgGetLabel(tg_sound, 1, ind);
    else
        label = '';
    end
end

function label = get_phoneme(tg_sound, time)
    ind = tgGetIntervalIndexAtTime(tg_sound, 2,  time);
    if ~isnan(ind)
        label = tgGetLabel(tg_sound, 2, ind);
    else
        label = '';
    end
end

function trs = parce_trs(filename)
    fid = fopen(filename, 'r', 'native');
    trs = {};
    prev_line_empty = false;
    sentence_started = false;
    for i = 1:14
        tline = fgetl(fid);
    end
    while ischar(tline)
        if contains(tline, '<Sync time=')
            splitted_line = strsplit(tline, '"');
            if ~sentence_started
                start_time = str2double(splitted_line(2));
                trs{end + 1}{1} = start_time;
                sentence_started = true;
            else
                finish_time = str2double(splitted_line(2));
                trs{end}{2} = finish_time;
                sentence_started = false;
            end
        elseif strcmp(tline, '')
            prev_line_empty = true;
        else
            if ~prev_line_empty
                sentence_started = true;
                trs{end + 1}{1} = trs{end}{2};
            end
            if sentence_started
                trs{end}{3} = tline;
                prev_line_empty = false;
            end
        end
        tline = fgetl(fid);
    end
    fclose(fid);
end

function idx = get_sentence_idx(trs, time)
    idx = -1;
    for i = 1:length(trs)
        if time >= trs{i}{1} && time <= trs{i}{2}
            idx = i;
            break;
        end
    end
end