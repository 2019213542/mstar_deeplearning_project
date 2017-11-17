clear;
cd caffe
addpath(genpath('.\build\Release'));

% ����gpu��cpuģʽ
% caffe.set_mode_cpu();
caffe.set_mode_gpu();
caffe.set_device(0);

% ����solver
% solver = caffe.Solver('.\examples\mstar\mstar_solver.prototxt');
solver = caffe.Solver('.\examples\mstar\mstar_solver_96.prototxt');
% ѵ��
tic;
solver.solve();
toc;
rmpath(genpath('.\build\Release'));
cd ..