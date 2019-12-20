% Create a rotating plot of the motion trajectory for each participant in
% 3d. This plot slowly rotates around the trailing trajectory in the center

function motion_trajectory_plotter(input_file, output_file)

if nargin == 0
    input_file='subjects/0924161_dev02/analysis/firstlevel/Confounds/MotionParameters_functional01.par';
    output_file='subjects/0924161_dev02/analysis/firstlevel/Confounds/MotionParameters_functional01';
end

motion=textread(input_file);
trailing_edge = 20;
pause_duration=0.05;
oscillation_freq = 0.1;
oscillation_range = [22.5, 67.5]; % What is the range of viewing angles?

% Set up the rotation dynamics
elements_per_oscillation = (1/oscillation_freq) / pause_duration; % How many rotations will there be?
oscillations = size(motion,1) / elements_per_oscillation;
oscillation_func=cos(0:(2*pi*oscillations)/(elements_per_oscillation*oscillations):2*pi*oscillations); % Set up the oscillation function
oscillation_func=oscillation_func(1:end-1); % Makes one extra
oscillation_func=(oscillation_func*diff(oscillation_range) /2)+oscillation_range(1)+(diff(oscillation_range)/2);

RotationPosition=[oscillation_func', linspace(45,45,elements_per_oscillation*oscillations)'];

% Set up the movie 
makeVideo=1;

if makeVideo == 1
    MovieFrameRate=round(1/pause_duration);
    daObj=VideoWriter(output_file, 'MPEG-4'); %specify the name of the object
    daObj.FrameRate=MovieFrameRate;
    open(daObj); % Start the movie object
end

h=figure;

for timepoint = 1:size(motion,1)
   
    % Plot the axes
    
    lower_idx = timepoint-trailing_edge;
    lower_idx(lower_idx<1) = 1; % Clip
    
    % Plot each element separately
    for idx = lower_idx:timepoint-1
        markerwidth = idx - lower_idx+1; % How big ought the line be?
        markercolor = [1, repmat(1-((idx - lower_idx) / (timepoint-lower_idx)), 1, 2)];
        
        plot3(motion(idx:idx+1,1), motion(idx:idx+1,2), motion(idx:idx+1,3), 'Color', markercolor);
        scatter3(motion(idx:idx+1,1), motion(idx:idx+1,2), motion(idx:idx+1,3), markerwidth, markercolor, 'filled');
        hold on
    end
    
    % Set up the image
    title(sprintf('Position relative to reference, TR: %d', timepoint))
    range=[-0.5, 0.5];
    xlim(range);
    ylim(range);
    zlim(range);
    xlabel('x diff (mm)');
    ylabel('y diff (mm)');
    zlabel('z diff (mm)');
    view(RotationPosition(timepoint,:)); drawnow; % Specify the viewing angle
    
    % Write the movie if appropriate
    if makeVideo == 1
        writeVideo(daObj,getframe(h)); %use figure, since axis changes size based on view
    end
    
    hold off
end

%End the video
if makeVideo == 1
    close(daObj);
end