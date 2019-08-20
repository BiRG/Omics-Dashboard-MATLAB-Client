classdef OmicsDashboardSession
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        omics_weboptions
        omics_url
    end
    
    methods
        function obj = OmicsDashboardSession(omics_url, email, password)
            %OmicsDashboardSession Construct an Omics Dashboard session
            %   
            if ~exist('email','var') || ~exist('password','var')
                [email,password] = logindlg;
                if isempty(email) && isempty(password)
                    error('You must enter an email and password');
                end
            end
            obj.omics_url = omics_url;
            obj = obj.authenticate(email, password);
        end
        
        function obj = authenticate(obj, email, password)
            if ~exist('email','var') || ~exist('password','var')
                [email,password] = logindlg;
                if isempty(email) && isempty(password)
                    error('You must enter an email and password');
                end
            end
            initial_options = weboptions('CertificateFilename', '', 'MediaType', 'application/json', 'HeaderFields', {'Connection', 'keep-alive'});
            credentials = struct('email', email, 'password', password); 
            res = webwrite([obj.omics_url '/api/authenticate'], credentials, initial_options);
            auth_token = ['Bearer' ' ' char(res.token)];
            obj.omics_weboptions = weboptions('CertificateFilename', '', 'MediaType', 'application/json', 'HeaderFields', {'Authorization', auth_token});
        end
        
        function authenticated = is_authenticated(obj)
            try
                res = webread([obj.omics_url '/api/current_user'], obj.omics_weboptions);
                if isfield(res, 'name')
                    authenticated = 1;
                    return;
                else
                    authenticated = 0;
                    return;
                end
            catch
                authenticated = 0;
                return;
            end
        end
        
        function check_authentication(obj)
            if ~obj.is_authenticated()
                error('Please reauthenticate by calling authenticate() on this object');
            end
        end
        
        function [sample, message] = get_sample(obj, sample_id)
        % Gets the given collection from the birg website using the given username 
        % and password.  If called without any of the parameters, displays dialogs
        % to get them from the user.
        %
        % Returns the collection or {} on error.  If there is an error, message
        % contains an error message for the user.
        message = '';
        sample = struct;
        obj.check_authentication()

        if ~exist('sample_id','var') || isempty(sample_id)
            prompt={'Sample ID:'};
            name='Enter the collection ID from the website';
            numlines=1;
            defaultanswer={''};
            answer=inputdlg(prompt,name,numlines,defaultanswer);
            if isempty(answer)
                message = 'You must enter a collection ID';
                return;
            end
            sample_id = str2double(answer{1});
            if isnan(sample_id) || length(sample_id) ~= 1
                message = 'You must enter a number as the collection ID';
                return;
            end
        end
        download_url = sprintf('%s/api/samples/download/%d', obj.omics_url, sample_id);
        info_url = sprintf('%s/api/samples/%d', obj.omics_url, sample_id);
        h5_filename = sprintf('%s%d.h5', tempdir, sample_id);
        % TODO: get name from server and insert into file
        h5_filename = websave(h5_filename, download_url, obj.omics_weboptions);
        info_response = webread(info_url, obj.omics_weboptions);
        sample = load_hdf5_collection(h5_filename);
        sample.('name') = info_response.name;
        end
        
        function [collection, message] = get_collection(obj, collection_id)
        % Gets the given collection from the birg website using the given username 
        % and password.  If called without any of the parameters, displays dialogs
        % to get them from the user.
        %
        % Returns the collection or {} on error.  If there is an error, message
        % contains an error message for the user.
            message = '';
            collection = struct;
            obj.check_authentication();

            if ~exist('collection_id','var') || isempty(collection_id)
                prompt={'Collection ID:'};
                name='Enter the collection ID from the website';
                numlines=1;
                defaultanswer={''};
                answer=inputdlg(prompt,name,numlines,defaultanswer);
                if isempty(answer)
                    message = 'You must enter a collection ID';
                    return;
                end
                collection_id = str2double(answer{1});
                if isnan(collection_id) || length(collection_id) ~= 1
                    message = 'You must enter a number as the collection ID';
                    return;
                end
            end
            download_url = sprintf('%s/api/collections/download/%d', obj.omics_url, collection_id);
            info_url = sprintf('%s/api/collections/%d', obj.omics_url, collection_id);

            h5_filename = sprintf('%s%d.h5', tempdir, collection_id);
            % TODO: get name from server and insert into file
            h5_filename = websave(h5_filename, download_url, obj.omics_weboptions);
            info_response = webread(info_url, obj.omics_weboptions);
            collection = load_hdf5_collection(h5_filename);
            collection.('name') = info_response.name;
        end
        
        function [message, new_id] = post_collection(obj, collection, analysis_id)
            % Upload a collection structure as an HDF5 file to Omics Dashboard
            new_id = NaN;
            obj.check_authentication()

            % file upload routes take multipart/form-data instead of JSON
            outdir = tempname;
            mkdir(outdir);
            filename = [fullfile(outdir,'collection_'), num2str(collection.collection_id), '.h5'];
            save_hdf5_collection(collection, filename)
            fid = fopen(filename, 'r');
            data = fread(fid);
            fclose(fid);
            % once data is read, we can delete the file
            try
                rmdir(outdir)
            catch
                fprintf('No directories were removed\n');
            end
            % matlab does not support multipart/form-data requests
            % so we sadly have to base64 encode the file and send it as text...
            req_body = struct('file', matlab.net.base64encode(data), 'name', collection.name, 'description', collection.processing_log, 'parent_id', collection.collection_id);
            if exist('analysis_id', 'var')
                req_body.('analysis_id') = analysis_id;
            end
            disp(req_body)
            res = webwrite([obj.omics_url '/api/collections/upload'], req_body, obj.omics_weboptions);
            if isfield(res, 'id')
                new_id = res.id;
                message = sprintf('Created collection %d.', new_id);
                if (exist('analysis_id', 'var') && analysis_id ~= -1 && ~isnan(analysis_id))
                    fprintf('Successfully posted collection %d and attached to analysis %d\n', new_id, analysis_id);
                else
                    fprintf('Successfully posted collection %d. Not attached to analysis.\n', new_id);
                end    
            else
                if isfield(res, 'message')
                    message = res.message;
                else
                    message = 'Upload Failed';
                end
                return;
            end
        end        
    end
end

