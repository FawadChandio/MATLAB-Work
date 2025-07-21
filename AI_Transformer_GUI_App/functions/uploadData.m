function data = uploadData()
    [file, path] = uigetfile({'*.csv;*.xlsx;*.mat', 'Supported Files (*.csv, *.xlsx, *.mat)'}, ...
                             'Select Transformer Data');
    if isequal(file, 0)
        disp('No file selected.');
        data = [];
        return;
    end

    fullPath = fullfile(path, file);
    [~, ~, ext] = fileparts(fullPath);

    try
        switch lower(ext)
            case '.csv'
                data = readtable(fullPath);
            case '.xlsx'
                data = readtable(fullPath);
            case '.mat'
                loaded = load(fullPath);
                vars = fieldnames(loaded);
                data = loaded.(vars{1});
            otherwise
                error('Unsupported file type.');
        end
        disp(['Successfully loaded: ', file]);
    catch ME
        uialert(gcf, ['Failed to load file: ', ME.message], 'File Error');
        data = [];
    end
end
