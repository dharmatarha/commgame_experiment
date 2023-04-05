function [mat_files] = mat2mat_wrapper(input_folder, max_depth)
%% Wrapper to turn all Octave default (text) .mat files into Matlab defaults
%
% USAGE: mat2mat_wrapper(input_folder=pwd, max_depth=5)
%
% !!! TO BE CALLED IN OCTAVE !!!
%
% Lists all .mat files in the input folder recursively and calls the
% function mat2mat on all of them. 
%
% !!! Files are overwritten in place !!!
%
% Inputs:
% input_folder - Char array, path to folder. Defaults to pwd.
% max_depth    - Maximum depth for recursive search. Defaults to 5.
%
% Output:
% mat_files    - Cell array of .mat files where mat2mat was applied.

%% Check inputs

if nargin == 0
    input_folder = pwd;
    max_depth = 5;
elseif nargin == 1
    max_depth = 5;
    if ~exist(input_folder, 'dir')
        error('Input arg "input_folder" must be a valid path to a folder!');
    end
elseif nargin == 2
    if ~exist(input_folder, 'dir')
        error('Input arg "input_folder" must be a valid path to a folder!');
    end
    if ~ismember(max_depth, 1:99)
        error('Input arg "max_depth" should be one of 1:99!');
    end    
else
    error('Input args "input_folder" and "max_depth" are optional, there are no other input args!');
end

disp('Called mat2mat_wrapper function with input args:');
disp(['Input folder: ', input_folder]);
disp(['Max depth: ', num2str(max_depth)]);


%% List .mat files, apply mat2mat

% standardize path ending
if ~strcmp(input_folder(end), '/')
    input_folder = [input_folder, '/'];
end

% list .mat files
mat_files = cell(0, 0);
for i = 1:max_depth
  if i == 1
    pattern = [input_folder, '*.mat'];
    res = glob(pattern);
  else
    pattern = [input_folder, repmat('*/', [1 i]), '*.mat'];
  endif
  res = glob(pattern);
  mat_files = cat(2, mat_files, res);
endfor

% call the function handling transformation
cellfun('mat2mat', mat_files);

disp([num2str(numel(mat_files)), ' files were transformed.']);


endfunction
