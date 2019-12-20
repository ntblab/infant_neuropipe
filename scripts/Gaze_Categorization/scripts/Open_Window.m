function Window=Open_Window
%% OPEN_WINDOW Put up the screen for this categorization
%
% Create the screen and collect a variety of parameters, such as the resolution and the rectangle size. The pixels per
% degree are also calculated which is different if the screen is curved or
% not.
%
% Description added: 3/9/16 C Ellis

global Window

Window.Screen_width=40;
Window.Viewing_dist=30;

% display requirements (resolution and refresh rate)
Window.requiredRes  = []; % you can set a required resolution if you want, e.g., [1024 768]
Window.requiredRefreshrate = []; % you can set a required Refresh Rate, e.g., [60]

%basic drawing and screen variables
Window.gray        = 50;
Window.black       = 10;
Window.white       = 200;
Window.fontsize    = 32;
Window.bcolor      = Window.gray;

%open main screen, get basic information about the main screen
screens=Screen('Screens'); % how many screens attached to this computer?
WhichScreen='max';

% Use this monitor unless otherwise stated
if strcmp(WhichScreen, 'min')
    Window.screenNumber=min(screens);
else
    Window.screenNumber=max(screens);
end

%% Open up the window with the proposed parameters

[Window.onScreen, Window.Rect]=Screen('OpenWindow',Window.screenNumber, 0, [], 32, 2);

%Set up some screen size values
[Window.screenX, Window.screenY]=Screen('WindowSize', Window.onScreen); % check resolution
Window.screenDiag = sqrt(Window.screenX^2 + Window.screenY^2); % diagonal size
Window.screenRect  =[0 0 Window.screenX Window.screenY]; % screen rect
Window.centerX = Window.screenRect(3)*.5; % center of screen in X direction
Window.centerY = Window.screenRect(4)*.5; % center of screen in Y direction

% set some screen preferences
Screen('BlendFunction', Window.onScreen, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);


% get screen rate
[Window.frameTime, ~, ~] =Screen('GetFlipInterval', Window.onScreen);
Window.monitorRefreshRate=1/Window.frameTime;

%% Pixels per degree calculation


%What are the pixels per degree for a flat surface?
%This is found here by making a triangle out of one half of the display
%and finding the angle subtended by that half. Then finding the pixels
%in that half

Window.ppd=(Window.screenX/2) / atand((Window.Screen_width/2)/Window.Viewing_dist);

%Make screen a specified color
Screen(Window.onScreen,'FillRect',Window.bcolor);
Screen('Flip',Window.onScreen);



