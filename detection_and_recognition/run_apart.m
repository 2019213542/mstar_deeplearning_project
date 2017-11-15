close all;
clc;
% ����ȫ��clear����Ҫ�������������
clear is_valid_handle; 
clear;

% ������ͼ��
img_list = dir('.\*.jpg');

% ----------------���------------------
addpath(genpath('.\core'));
cd .\core
% ���·�� '.\external\caffe\matlab\caffe_faster_rcnn';
active_caffe_mex(1, 'caffe_faster_rcnn');
% ����gpu
caffe.set_mode_gpu();
% �����־
% caffe.init_log(fullfile(pwd, 'caffe_log'));

% ���������ļ�
model_dir = fullfile(pwd, 'output', 'faster_rcnn_final', 'faster_rcnn_VOC2007_ZF');
load(fullfile(model_dir, 'proposal_alone.mat'));
% ���ؼ������ģ�ͺͲ���
rpn_net = caffe.Net(fullfile(model_dir, 'proposal_test_alone.prototxt'), 'test');
rpn_net.copy_from(fullfile(model_dir, 'proposal_alone'));
% gpu������ʽ�ľ�ֵ�ļ�
% model.conf_proposal.image_means = gpuArray(conf_proposal.image_means);

% Ԥ�������������ڸ��õؼ���ʱ��
for j = 1:2 
    im = gpuArray(uint8(ones(375, 500, 3)*128));
    % ���
    proposal_im_detect(conf_proposal, rpn_net, im);
end

rpn_thres = 0.95;
nms_thres  = 0.3;
nms_thres_again = 0.3;

for i = 1:length(img_list)
    th = tic();
    im = gpuArray(imread(['..\' img_list(i).name]));
    % ���
    [boxes, det_scores] = proposal_im_detect(conf_proposal, rpn_net, im);
    aboxes = boxes_filter([boxes, det_scores], rpn_thres, nms_thres);
    [allboxes{i}, proposals{i}] = rois_modified(gather(im), aboxes);
    time{i} = toc(th);
end

caffe.reset_all();
rmpath('.\external\caffe\matlab\caffe_faster_rcnn');
cd ..
rmpath(genpath('.\core'));

% ----------------����------------------
cd '..\classification\caffe';
addpath(genpath('.\build\Release'));
caffe.set_mode_gpu();
caffe.set_device(0);
% ���������ļ�
net_model = '.\examples\mstar\mstar_deploy_96.prototxt';
% ���ز����ļ�
net_weights = '.\examples\mstar\mstar_96_iter_34400.caffemodel';
phase = 'test';
% ��ʼ������
net = caffe.Net(net_model, net_weights, phase);
% ����
net.forward({ones(96, 96, 1, 1)});    
net.forward({ones(96, 96, 1, 1)});    
 
for i = 1:length(img_list)
    th = tic();
    proposal = proposals{i};
    scores = [];
    classes = [];
    for j = 1:size(allboxes{i}, 1)
        [scores(j), classes(j)] = classify_on_detection(net, proposal(:, :, j));
    end
    reg_scores{i} = [scores' classes'];
    time{i} = time{i} + toc(th);
end
caffe.reset_all();
rmpath(genpath('.\build\Release'));
cd ..\..\detection_and_recognition

addpath(genpath('.\core'));
for i = 1:length(img_list)
    th = tic();
    aboxes = [allboxes{i} reg_scores{i}];
%     aboxes = [allboxes{i} ones(size(allboxes{i}, 1), 2)];
    aboxes = aboxes(nms(aboxes(:, 1:5), nms_thres_again), :);
    aboxes = aboxes(aboxes(:, 5) >= 0.5, :);
    fprintf('%s : %.3fs \n', img_list(i).name, time{i} + toc(th));
    figure(i);
    m_showboxes(imread(img_list(i).name), aboxes);
end
rmpath(genpath('.\core'));
    
function [patches, proposals] = rois_modified(im, patches)
    im = rgb2gray(im);
%     im = imresize(im, [594, 492]);

    % ���ޱ߿�Ϊ96*96������
    xcen = (patches(:,1)+patches(:,3))/2;
    ycen = (patches(:,2)+patches(:,4))/2;
    % �պ�Ϊ���ұ߽�
    patches(:,1) = max(xcen - 47,1);
    patches(:,3) = min(xcen + 48,size(im,2));
    % �պ�Ϊ���±߽�
    patches(:,2) = max(ycen - 47,1);
    patches(:,4) = min(ycen + 48,size(im,1));

    for i = 1:size(patches, 1)
        proposals(:,:,i) = imresize(im(patches(i,2) : patches(i,4), patches(i,1) : patches(i,3)),[96 96]);    
    end
    patches = patches(:, 1:end-1);
end

function aboxes = boxes_filter(aboxes, rpn_thres, nms_thres)
    % ���ݵ÷�������ߵ�N��
    aboxes = aboxes(aboxes(:, 5) >= rpn_thres, :);   
    % �Ǽ���ֵ����
    aboxes = aboxes(nms(aboxes, nms_thres, 1), :);    
end

function [score, class] = classify_on_detection(net, im)
    % gpu����
    im = single(im) / 255.0;
    im = im - mean(im(:));
    im = permute(im, [2, 1, 3]);
    im = reshape(im, [96, 96, 1, 1]);
    scores = net.forward({im});
    scores = scores{1};
    [score, class] = max(scores);
end