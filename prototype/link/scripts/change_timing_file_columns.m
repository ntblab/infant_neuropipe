% Change the column values of a file
% Take in a file name, an output file name with a column change as specified. If the
% list is length one then all the values in that column will be replaced with this. If it
% is a list, make sure it is of the form: [1,2,3] (no spaces, commas).
% Slope will make a mean centred slope out of the timing data

function change_timing_file_columns(input, output, values, column)

% Set the type of the values
if isstr(column)
    column = str2num(column);
end

% Read in the timing file
timing = textread(input);

% If values is a string then you are doing something different with it
if isstr(values);
    
    if ~isempty(strfind(values, 'add_'))
	% Add the given value to all values that you currently have from the input
	values = timing(:, column) + str2num(values(5:end));

    elseif ~strcmp(values, 'slope')
        values = str2num(values);
    else
        
        % make the values to be set as the slope (this is hacky but you try make this
        % arithmetic in bash!)
        blocks=size(timing,1);
        values=1:blocks;
        
        numerator=values-((length(values)+1)/2);
        denominator=sum(abs((values-((length(values)+1)/2))))/2;
        
        values=numerator/denominator;
        
    end
end


% Replace the weights
timing(:,column)=values;

% Print
timing

% Save the weights
dlmwrite(output, timing, '\t');
