close all;
clc;
% ����ȫ��clear����Ҫ�������������
clear is_valid_handle; 

addpath(genpath('.\core'));
% ������ͼ��
load '.\core\imdb\cache\imdb_voc_2007_test.mat';
img_list = imdb.image_ids;

cd .\core
% ���·�� '.\external\caffe\matlab\caffe_faster_rcnn';
active_caffe_mex(1, 'caffe_faster_rcnn');
% ����gpu
caffe.set_mode_gpu();
% �����־
% caffe.init_log(fullfile(pwd, 'caffe_log'));

% ���������ļ�
model_dir = fullfile(pwd, 'output', 'faster_rcnn_final', 'faster_rcnn_VOC2007_ZF');
load(fullfile(model_dir, 'model.mat'));

% ���ؼ������ģ�ͺͲ���
rpn_net = caffe.Net(fullfile(model_dir, 'proposal_test.prototxt'), 'test');
rpn_net.copy_from(fullfile(model_dir, 'proposal_final'));
% ���ط�������ģ�ͺͲ���
fast_rcnn_net = caffe.Net(fullfile(model_dir, 'detection_test.prototxt'), 'test');
fast_rcnn_net.copy_from(fullfile(model_dir, 'detection_final'));
% gpu������ʽ�ľ�ֵ�ļ�
model.conf_proposal.image_means = gpuArray(model.conf_proposal.image_means);
model.conf_detection.image_means = gpuArray(model.conf_detection.image_means);
% �Ǽ���ֵ���Ʋ���
nms_thres = 0.6;    % ��ɸ��һ��
nms_num  = 30;
nums_thres_again = 0.3;
% ----�ò�����ָ��----
% Mean time used: 0.028s
% Real target number: 375
% Missing alarm: 2.1%
% False alarm: 0.3%
% Recognition rate: 90.7%

% Ԥ�������������ڸ��õؼ���ʱ��
for j = 1:2 
    im = gpuArray(uint8(ones(375, 500, 3)*128));
    % ���
    [boxes, scores] = proposal_im_detect(model.conf_proposal, rpn_net, im);
    % ɸѡ
    aboxes = boxes_filter([boxes, scores], nms_thres, nms_num);
    % ����
    [boxes, scores] = fast_rcnn_conv_feat_detect(model.conf_detection, fast_rcnn_net, im, ...
        rpn_net.blobs(model.last_shared_output_blob_name), ...
        aboxes(:, 1:4), nms_num);     
end

time_sum = 0;
for j = 1:length(img_list)
    % ��ʱ
    th = tic();
    im = gpuArray(imread(['.\datasets\VOCdevkit2007\VOC2007\JPEGImages\' char(img_list(j)) '.jpg']));
    % ���
    [boxes, scores] = proposal_im_detect(model.conf_proposal, rpn_net, im);
    % ����ɸѡ
    aboxes = boxes_filter([boxes, scores], nms_thres, nms_num);
    % ����
    [boxes, scores] = fast_rcnn_conv_feat_detect(model.conf_detection, fast_rcnn_net, im, ...
        rpn_net.blobs(model.last_shared_output_blob_name), ...
        aboxes(:, 1:4), nms_num);    
    boxes_cell = cell(length(model.classes), 1);
    for i = 1:length(boxes_cell)
        boxes_cell{i} = [boxes(:, (1+(i-1)*4):(i*4)), scores(:, i)];
        boxes_cell{i} = boxes_cell{i}(nms(boxes_cell{i}, nums_thres_again), :);
        % �ڶ���ɸѡ��ֻ��������÷ִ���60��
        I = boxes_cell{i}(:, 5) >= 0.5;
        boxes_cell{i} = boxes_cell{i}(I, :);
    end
    this_time = toc(th);
    fprintf('%s : %.3fs \n', [char(img_list(i)) '.jpeg'], this_time);
    time_sum = time_sum + this_time;
    % ���棬���ڼ���ָ��
    allboxes{j} = [];
    for i = 1:length(boxes_cell)
        if ~isempty(boxes_cell{i})
            allboxes{j} = [allboxes{j}; [boxes_cell{i}, ones(size(boxes_cell{i}, 1), 1)*i]];
        end
    end
end

caffe.reset_all(); 
clear mex;
cd ..
rmpath(genpath('.\core'));

% ����ָ��
compute_evaluations(img_list, allboxes, time_sum);

function aboxes = boxes_filter(aboxes, nms_thres, nms_num)
    % �Ǽ���ֵ����
    aboxes = aboxes(nms(aboxes, nms_thres, 1), :);    
    % ���ݵ÷�������ߵ�N��
    aboxes = aboxes(1:min(length(aboxes), nms_num), :);
end
