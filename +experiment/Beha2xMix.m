classdef Beha2xMix < Block
    
    properties (Transient)
        panels = {'DiscriTest'};
        %panels = {'AllChTRF', 'TRF_Laser'};
    end
    
    methods
        function stimData = getStimuliConditions(this, source)
            stimData{1} = source.beha.data;
            this.stim(1).label = 'Go NoGo Tone';
        end
        
        function filtStimCond = getStimuliFilteringConditions(this, source)
            filter = zeros(size(source.beha.data));
            for i = 1:length(source.beha.data)
                timesub = source.Hit_.onset - source.beha.onset(i);
                lick = any(0 < timesub & timesub < 2);
                
                goTone = ~source.beha.data(i);
                
                if goTone && lick
                    filter(i) = 1; % Hit
                    
                elseif goTone && ~lick
                    filter(i) = 2; % Miss
                    
                elseif ~goTone && lick
                    filter(i) = 3; % FalseAlarm
                    
                elseif ~goTone && ~lick
                    filter(i) = 4; % CorrectReject
                end
            end
            
            filtStimCond{1} = filter;
            this.filtStim(1).label = '1 Hit 2 Miss 3 FA 4 CR';
            
            % Force the number of repetitions to 1
            this.nTrials = length(filtStimCond{1});
            
        
            filter = source.Lasr.data;
            filtStimCond{2} = filter;
            this.filtStim(2).label = 'Laser';
        end
    end
    
    methods (Static)
        function customAnalysis(group, chan)
        end
    end
    
     methods % Redefined methods
         function load(this, blockPath, blockName, nChannels, spikeDataType) %this has to be redefined as we did not save any coun for behavior, so we have to create one
             % Load a block depending on the dataType            
             % Basic data
             this.name = blockName;
             this.path = blockPath;
             this.nChannels = nChannels;
             
             matFile = matfile(fullfile(blockPath, [blockName '.mat'])); % access TDT mat file
             info = whos(matFile);
             if length(info) == 1 % mat file contain only 'data' structure
                 data = matFile.data;
                 epocs = data.epocs;
                 eNeu = data.snips.eNeu;
             else % mat file contain 'eNeu' and 'snips' structures separately
                 epocs = matFile.epocs;
                 snips = matFile.snips;
                 eNeu = snips.eNeu;
             end
             
%             %the following lines make sure that the first dataset start with no laser and finished with laser, ...
%             %so that there is an even number of laser off laser on trials
%             if epocs.Lasr.data(1)==1  %remove the first stimulus in case it starts with a laser
%                 epocs.Lasr.data=epocs.Lasr.data(2:end);
%                 epocs.Lasr.onset=epocs.Lasr.onset(2:end);
%                 epocs.Lasr.offset=epocs.Lasr.offset(2:end);
%                 epocs.beha.data=epocs.beha.data(2:end);
%                 epocs.beha.onset=epocs.beha.onset(2:end);
%                 epocs.beha.offset=epocs.beha.offset(2:end);
%                 if epocs.Lasr.onset(1)-epocs.Hit_.onset(1)>0
%                     epocs.Hit_.onset=epocs.Hit_.onset(2:end);
%                     epocs.Hit_.offset=epocs.Hit_.offset(2:end);
%                     epocs.Hit_.data=epocs.Hit_.data(2:end);
%                 end
%             end
%             
%             if epocs.Lasr.data(end)==0  %remove the last stimulus in case it ends without a laser
%                 epocs.Lasr.data=epocs.Lasr.data(1:end-1);
%                 epocs.Lasr.onset=epocs.Lasr.onset(1:end-1);
%                 epocs.Lasr.offset=epocs.Lasr.offset(1:end-1);
%                 epocs.beha.data=epocs.beha.data(1:end-1);
%                 epocs.beha.onset=epocs.beha.onset(1:end-1);
%                 epocs.beha.offset=epocs.beha.offset(1:end-1);
%                 if epocs.Hit_.onset(end)-epocs.Lasr.onset(end)>2
%                     epocs.Hit_.onset=epocs.Hit_.onset(1:end-1);
%                     epocs.Hit_.offset=epocs.Hit_.offset(1:end-1);
%                     epocs.Hit_.data=epocs.Hit_.data(1:end-1);
%                 end
%             end
            
             % Take epocs.beha.data as a reference for a number of trials (every block has it)
             this.nTotal = length(epocs.beha.data); %this is redefined here
             
             %--- Assign the stimuli conditions (there must be 2 different stimuli in total)
             stimData = this.getStimuliConditions(epocs);
             if length(stimData) > 2
                 error('Block:load', 'Too many stimuli conditions (maximum 2)');
             end
             for k = 1:2
                 if k > length(stimData)
                     % Create a blank stimulus in case of only 1 stimuli in the '+experiment' file
                     stimData{k} = ones([this.nTotal, 1]);
                 end
                 this.stim(k).val = unique(stimData{k});
                 this.stim(k).len = length(this.stim(k).val);
                 this.stim(k).ind = k;
             end            
             % Number of trials per repetition and per group
             this.nTrials = prod([this.stim.len]); 
             %--- Assign the grouping conditions
             groupData = this.getGroupingConditions(epocs);
             for k = 1:length(groupData)
                 this.group(k).val = unique(groupData{k});
                 this.group(k).len = length(this.group(k).val);
                 this.group(k).sel = 1;
             end             
             % Number of groups
             this.nGroups = prod([this.group.len]);            
             %--- Assign the stimuli filtering conditions
             filtStimData = this.getStimuliFilteringConditions(epocs);
             for k = 1:length(filtStimData)
                 this.filtStim(k).val = unique(filtStimData{k});
                 this.filtStim(k).len = length(this.filtStim(k).val);
                 this.filtStim(k).sel = 1;
             end             
             %--- Assign the spikes filtering conditions
             filtSpikesData = this.getSpikesFilteringConditions(epocs);
             for k = 1:length(filtSpikesData)
                 this.filtSpikes(k).val = unique(filtSpikesData{k});
                 this.filtSpikes(k).len = length(this.filtSpikes(k).val);
                 this.filtSpikes(k).sel = 1;
             end
             % Number of repetitions (only stimuli and groups affect it, filters do not)
             this.nRep = this.nTotal/this.nTrials/this.nGroups;   
             % Organize stimuli timings and conditions, and filtering conditions
             all_stimCond = [stimData{:}];
             all_onset = epocs.beha.onset;
             this.stimTimings = zeros(this.nTrials, this.nRep, this.nGroups);
             for k = 1:this.nGroups
                 % Calculate indexes related to the k'th group
                 ind = true(this.nTotal, 1);
                 dim = [this.group.len];
                 J = k;
                 for l = 1:length(this.group)-1
                     [I, J] = ind2sub(dim(l:end), J);
                     ind = ind & (groupData{l} == this.group(l).val(I));
                 end
                 ind = ind & (groupData{end} == this.group(end).val(J));                 
                 % Group values
                 stimCond = all_stimCond(ind, :);
                 onset = all_onset(ind);                
                 for l = 1:this.nRep
                     ind_rep = 1+(l-1)*this.nTrials : l*this.nTrials;
                     [rep, ind_sort] = sortrows(stimCond(ind_rep, :), [1 2]);
                     ind_ord = ind_rep(ind_sort);
                     this.stimTimings(:, l, k) = onset(ind_ord);                     
                     % Organize stimuli filters
                     for m = 1:length(this.filtStim)
                         this.filtStim(m).map(:, l, k) = filtStimData{m}(ind_ord);
                     end                     
                     % Once save stimuli conditions
                     if l == 1 && k == 1
                         this.stimConditions = rep;
                     end
                 end
             end
             
             % Load spike data
             switch spikeDataType
                 case 'TDT'
                     ts = eNeu.ts;
                     chan = eNeu.chan;
                     snips = eNeu.data;
                     
                 case 'Klusta'
                     [ts, chan, snips, clustNum] = ...
                         this.loadKlustaSpikeData(blockPath, blockName, nChannels);
                     
                     % Assign 'clustNum' as a filtering condition for spikes
                     filtSpikesData{end+1} = clustNum;
                     this.filtSpikes(end+1).label = 'Cluster';
                     this.filtSpikes(end).val = unique(clustNum);
                     this.filtSpikes(end).len = length(unique(clustNum));
                     this.filtSpikes(end).sel = 1:this.filtSpikes(end).len;
             end
             
             % Organize spikes data
             this.spikeTimings_raw = cell(1, nChannels);
             this.snips = cell(1, nChannels);
             for l = 1:length(this.filtSpikes)
                 this.filtSpikes(l).map = cell(1, nChannels);
             end
             for k = 1:nChannels
                 idx = (chan == k);
                 this.spikeTimings_raw{k} = ts(idx);
                 this.snips{k} = snips(idx, :);
                 
                 % Spikes filters
                 for l = 1:length(this.filtSpikes)
                     this.filtSpikes(l).map{k} = filtSpikesData{l}(idx);
                 end
             end
             this.spikeTimings = this.spikeTimings_raw;
             
             % Save utility information (used in 'suppressRepSpikes' method)
             this.ts = ts;
             this.chan = chan;
             this.filtSpikesData = filtSpikesData;
         end
     end
end

