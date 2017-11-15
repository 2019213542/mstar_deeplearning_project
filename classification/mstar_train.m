clear;
cd caffe-Release
addpath(genpath('.\build\Release'));

% ����gpu��cpuģʽ
% caffe.set_mode_cpu();
caffe.set_mode_gpu();
caffe.set_device(0);

% ����solver
solver = caffe.Solver('.\examples\mstar\mstar_solver.prototxt');
% ѵ��
solver.solve();
rmpath(genpath('.\build\Release'));
cd ..