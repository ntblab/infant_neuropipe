% Append the regressor files
%
% Takes in a file name to be appended to another file (if it exists) and
% insures that there are equivalent numbers of columns. This means it will
% either pad the number of columns of the file being added or pad
% the number of columns for the existing file.
%
% If the input file is not a file name but instead a number then this
% simply refers to the number of TRs to be created instead, since it
% suggests there are no confounds to be added
%
% Extend specifies whether you ought to extend the timing files width to
% fit these new files in or whether you should simply just concatenate them
% First created by C Ellis 2/23

function append_regressor_file(Input, Output, Extend)

%Load the output
if exist(Output)~=0
    Output_Mat=dlmread(Output);
    
    %Make the input matrix
    if isempty(str2num(Input))
        %If the input is a file then load it
        Input_Mat=dlmread(Input);
    else
        %If the input is a number then create a matrix of the size of output
        fprintf('Making a filler matrix because no file was supplied\n');
        Input_Mat=zeros(str2num(Input), size(Output_Mat,2));
    end
    
    %Print the results
    fprintf('\nInput size %d by %d, Output size %d by %d\n', size(Input_Mat,1), size(Input_Mat,2), size(Output_Mat,1), size(Output_Mat,2));
    
    if strcmp(Extend, '1')
        fprintf('Extending the width of the file to accommodate\n');
        % Widen the matrices to deal with the new confounds that will be added
        Input_width=size(Input_Mat,2);
        Output_width=size(Output_Mat,2);
        Output_Mat(:,end+1:end+Input_width)=zeros(size(Output_Mat,1), Input_width);
        Input_Mat=[zeros(size(Input_Mat,1), Output_width), Input_Mat];
    else
        fprintf('Just appending, not widening\n');
       
        
    end
    
    %Concatenate the matrices
    Output_Mat=[Output_Mat; Input_Mat];
    
else
    fprintf('\nNo output found, copying Input to Output\n');
    
    %Make the output matrix
    if isempty(str2num(Input))
        %If the output doesn't exist then just copy it.
        try
            Output_Mat=dlmread(Input);
        catch
            fprintf('The input matrix is empty, not creating anything. Should have supplied a number as input instead.\n');
            return
        end
    else
        %If the input is a number then create a matrix with one column
        Output_Mat=zeros(str2num(Input), 1);
    end
    
end

% Write the output
dlmwrite(Output, Output_Mat, ' ');
