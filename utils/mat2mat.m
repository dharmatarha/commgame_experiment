function mat2mat(matFilePath)
%% For turning Octave default .mat files into Matlab defaults. 
% !!! OVERWRITES DATA IN PLACE !!!

    load(matFilePath);
    save(matFilePath, '-v7');
    
endfunction
