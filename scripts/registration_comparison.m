% Run through all of the flirt analyses and check what the size of the cost function is
% 
% Use the subject selection criteria from Participant_Index to restric the
% sample being considered
%
function registration_comparison(varargin)

addpath scripts
reg='analysis/secondlevel/registration.feat/reg/';
cost_functions={'corratio'};%{'mutualinfo','corratio','normcorr','normmi','leastsq','labeldiff'};
savelocation='results/registration_comparison_';


transformation_highres_automatic='example_func2highres_automatic.mat';
transformation_highres_manual='example_func2highres.mat';
transformation_standard_automatic='highres2standard_infant_automatic.mat';
transformation_standard_manual='highres2standard_infant.mat';

transformations={transformation_highres_automatic, transformation_highres_manual, transformation_standard_automatic, transformation_standard_manual};

% What are the participants
participants=Participant_Index(varargin);

% Make the output name
output_name='';
for argcounter=1:nargin
    output_name=[output_name, '_', num2str(varargin{argcounter})];
end

for costfunctioncounter=1:length(cost_functions)
    costs=[];
    for participantcounter=1:length(participants)
        
        for transformationcounter=1:length(transformations)
            
            % Set up the names
            ppt=sprintf('subjects/%s/', participants{participantcounter});
            example_func=[ppt, reg, '/example_func.nii.gz'];
            highres=[ppt, reg, '/highres.nii.gz'];
            standard_infant=[ppt, reg, '/standard_infant.nii.gz'];

            % set up the variables
            cost_function=cost_functions{costfunctioncounter};
            transformation=[ppt, reg, transformations{transformationcounter}];
            
            %What are the volumes to use on this trial
            if transformationcounter<3
                input=example_func;
                ref=highres;
            else
                input=highres;
                ref=standard_infant;
            end
            
            % Get the fsl path
            command=['fslpath=`which feat`; fslpath=${fslpath%bin}; echo $fslpath'];
            [~, fslpath]=unix(command); 
            
            % Compare the example_func to highres
            command=sprintf('flirt -in %s -ref %s -schedule %s/etc/flirtsch/measurecost1.sch -init %s -cost %s | head -1 | cut -f1 -d'' ''', input, ref, fslpath, transformation, cost_function)
            [~, cost]=unix(command);
            
            costs(participantcounter, transformationcounter)=str2double(cost);
        end
        
        if costs(participantcounter,2)<costs(participantcounter,1)
            asdfaasfsas
        end
        
    end
    costs
    %What is the difference in automatic and manual for this cost
    
    manual_benefit = costs(:,1)-costs(:,2);
    
    manual_benefit = manual_benefit(~isnan(manual_benefit));
    
    hist(manual_benefit);
    xlabel('Manual benefit');
    title(sprintf('Difference in %s for registration to highres', cost_function));
    saveas(gcf, [savelocation, cost_function, output_name, '_highres.png']);
    
    manual_benefit = costs(:,3)-costs(:,4);
    manual_benefit = manual_benefit(~isnan(manual_benefit));
    
    hist(manual_benefit);
    xlabel('Manual benefit');
    title(sprintf('Difference in %s for registration to standard', cost_function));
    saveas(gcf, [savelocation, cost_function, output_name, '_standard.png']);
    
    save([savelocation, cost_function, output_name, '.mat'], 'costs');
end
