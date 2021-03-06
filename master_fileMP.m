%%
cd('D:\CODE\MariusBox\runSuite2P')
addpath('D:\CODE\GitHub\Suite2P')

% make database to run in batch
make_db_adaptation;

ops0.useGPU                 = 1; % if you can use a GPU in matlab this accelerate registration approx 3 times
ops0.doRegistration         = 1;

% root paths for files and temporary storage (ideally an SSD drive. my SSD is C)
ops0.RegFileTiffLocation    = []; %'D:/DATA/'; % leave empty to NOT save registered tiffs
ops0.RegFileRoot            = 'C:/DATA/tempreg';
ops0.TempStorage            = 'C:/DATA/'; % copy data locally first
ops0.ResultsSavePath        = 'D:/DATA/F';
ops0.RootStorage            = '//zserver4/Data/2P';

ops0.getROIs                = 1;
ops0.getSVDcomps            = 1;
ops0.nSVD                   = 1000; % how many SVD components to keep

ops0.CopyDataLocally        = 1;
ops0.useImRead              = 1; % imread works faster from a local drive
ops0.PhaseCorrelation       = 1; % set to 0 for non-whitened cross-correlation
ops0.SubPixel               = Inf; % 2 is alignment by 0.5 pixel, Inf is the exact number from phase correlation

ops0.showTargetRegistration = 1;
ops0.ShowCellMap            = 1;
ops0.DeleteBin              = 1; % set to 1 for batch processing on a limited hard drive
ops0.DeleteRawOnline        = 1; % set to 1 for deleting local tiff files right after registration

ops0.LoadRegMean   			= 0; % 

% these are modifiable settings for classifying ROIs post-clustering
clustrules.MaxNpix                          = 500; 
clustrules.MinNpix                          = 30; 
clustrules.Compact                          = 2; 
clustrules.parent.minPixRelVar              = 1/10;
clustrules.parent.PixelFractionThreshold    = 0.5; 
clustrules.parent.MaxRegions                = 10;

% the following settings shouldn't need to be adjusted
ops0.NavgFramesSVD          = 3000; % how many (binned) timepoints to do the SVD based on
ops0.Nk0                    = 1300;  % how many clusters to start with
ops0.Nk                     = 650;  % how many clusters to end with
ops0.nSVDforROI             = 1000;
ops0.niterclustering        = 30;   % how many iterations of clustering
ops0.sig                    = 0.25;  % spatial smoothing length for clustering; encourages localized clusters

ops0.showTargetRegistration = 1;
ops0.NimgFirstRegistration  = 1000; 
ops0.RegPrecision           = 'int16';
ops0.RawPrecision           = 'int16';
ops0.NiterPrealign          = 10;


%%
for iexp = 13 % 1:length(db)        %3:length(db)          
    % copy files from zserver
    if ops0.CopyDataLocally
        db0 = copy_from_zserver(db(iexp), ops0);
        ops = build_ops2(db0, ops0);
    else
        ops = build_ops(db(iexp), ops0);
    end
    
    if ops.useGPU
        gpuDevice(1);   % reset GPU at each dataset
    end
    %
    ops1         = reg2Pnew(ops);  % do registration
    
    for i = 1:length(ops.planesToProcess)
        iplane  = ops.planesToProcess(i);
        ops     = ops1{i};
        ops.iplane  = iplane;
        
        if numel(ops.yrange)>300 && numel(ops.xrange)>300
            if ops.getSVDcomps
                ops    = get_svdcomps(ops);
            end
            
            if ops.getROIs                
                [ops, U, Sv]        = get_svdForROI(ops);
                [ops, stat0, res0]  = fast_clustering(ops, reshape(U, [], size(U,3)), Sv);
                [stat, res]         = apply_ROIrules(ops, stat0, res0, clustrules);
                Fcell               = get_signals(ops, iplane);
            end
        end
        
        if ops.DeleteBin
            delete(ops.RegFile);        % delete temporary bin file
        end
    end
   
    
    % clean up
    fclose all;        
end
%%
