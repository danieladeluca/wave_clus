classdef readInData < handle
	properties
        par
        nick_name
        with_raw
        with_spikes
        with_results
        n_to_read
        sample_signal
        max_segments
        file_reader
        with_wc_spikes
    end 
	methods 
        function obj = readInData(par_gui)
            [~, fnam, ext] = fileparts(par_gui.filename);
            ext = lower(ext);
            obj.par = par_gui;
            obj.nick_name = fnam;
            obj.n_to_read = 1;
            obj.with_results = false;
            obj.with_raw = false;
            obj.with_spikes = false;
            obj.with_wc_spikes = false;
            with_par = false;

            %Search for previous results
            if exist(['data_' obj.nick_name '.dg_01.lab'],'file') && exist(['data_' obj.nick_name '.dg_01'],'file') && exist(['times_' obj.nick_name '.mat'],'file')
                obj.with_results = true;
                finfo = whos('-file',['times_' obj.nick_name '.mat']);
                if ismember('par',{finfo.name})  
                    load(['times_' obj.nick_name '.mat'],'par'); 
                    obj.par = update_parameters(obj.par,par,'relevant');
                    with_par = true;
                end
                
            end
            
            %Search for previously detected spikes
            if exist([obj.nick_name '_spikes.mat'],'file')
                obj.with_wc_spikes = true;
                obj.with_spikes = true;
                finfo = whos('-file', [obj.nick_name '_spikes.mat']);
                if ismember('par',{finfo.name}) && ~ with_par 
                    load([obj.nick_name '_spikes.mat'],'par'); 
                    obj.par = update_parameters(obj.par,par,'detec');
                    with_par = true;
                end
            end

            % Search raw data
            if exist([ext(2:end) '_reader'],'file')
                obj.file_reader = eval([ext(2:end) '_reader(obj.par,obj.par.filename)']);
                [sr, obj.max_segments, obj.with_raw, with_spikes] = obj.file_reader.get_info();
                obj.with_spikes = obj.with_spikes || with_spikes;
                
                if ~with_par                                                                                            %if didn't load sr from previous results 
                    if isempty(sr)
                        disp('Wave_clus din''t find a sampling rate in file. It will use the set in set_parameters.m')  %use default sr (from set_parameters) 
                    else
                        obj.par.sr = sr;                                                                                %load sr from raw data
                    end
                end
            else
                if ~(obj.with_results || obj.with_wc_spikes)
                    ME = MException('MyComponent:noSuchExt', 'File type ''%s'' isn''t supported',ext);
                    throw(ME)
                else
                    disp ('File type isn''t supported.')
                    disp ('Using Wave_clus data found it.')
                end
            end
            

            obj.par.ref = floor(obj.par.ref_ms *obj.par.sr/1000);
        end
        
        
        function [spikes, index_ts] = load_spikes(obj)
            if ~ (obj.with_spikes || obj.with_wc_spikes)
                ME = MException('MyComponent:noSpikesFound', 'Wave_Clus couldn''t find a file with spikes');
                throw(ME)
            end
            
            if obj.with_wc_spikes                               %wc data have priority
                load([obj.nick_name '_spikes.mat']);
                if ~ exist('index_ts','var')                    %for retrocompatibility
                    index_ts = index;
                end
            else
                [spikes, index_ts] = obj.file_reader.load_spikes();
            end
            
        end
        
        
        function [clu, tree, spikes, index, inspk, ipermut] = load_results(obj)
        	
            if ~ obj.with_results
            	ME = MException('MyComponent:noClusFound', 'This file don''t have a associated ''times_%s.mat'' file',obj.nick_name);
            	throw(ME)
            end
            load(['times_' obj.nick_name '.mat']);
            if ~exist('ipermut','var')
            	ipermut = [];
            end
            % cluster_class(:,1);
            index = cluster_class(:,2);
         	clu = load(['data_' obj.nick_name '.dg_01.lab']);
         	tree = load(['data_' obj.nick_name '.dg_01']);
        end

        
        function x = get_segment(obj)
            
            if ~ obj.with_raw
                ME = MException('MyComponent:noRawFound', 'Wave_Clus couldn''t find the raw data',ext);
                throw(ME)
            end
            if obj.n_to_read > obj.max_segments
                ME = MException('MyComponent:allFileReaded', 'The raw data is already fully loaded',ext);
                throw(ME)
            end
            
            x = obj.file_reader.get_segment(obj.n_to_read);
            
            if ~ isa(x,'double')
                x = double(x);
            end

            if obj.n_to_read == 1 && obj.par.show_signal
                lplot = min(floor(60*obj.par.sr), length(x));
                xf_detect = spike_detection_filter(x(1:lplot), obj.par);
                
                max_samples = 100000;
                sub = floor(lplot/max_samples);
                obj.sample_signal.xd_sub = xf_detect(1:sub:end) ;
                obj.sample_signal.sr_sub = obj.par.sr/sub ;
            end
            
            obj.n_to_read = obj.n_to_read + 1;
        end
        
        
        function index_ts = index2ts(obj,index)
            index_ts = obj.file_reader.index2ts(index,obj.n_to_read-1);
        end
        
        
        function [xd_sub, sr_sub] = get_signal_sample(obj)
            if obj.n_to_read == 1
                disp('Segment read only for plotting');
                obj.get_segment();
            end
            xd_sub = obj.sample_signal.xd_sub;
            sr_sub = obj.sample_signal.sr_sub;
            obj.sample_signal.xd_sub = [];
            
        end

  
	end

end
