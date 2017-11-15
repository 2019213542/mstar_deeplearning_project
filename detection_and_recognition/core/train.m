clc;
clear mex;
clear is_valid_handle; 

% �������ѵ������Ҫɾ��cache��output
delete('.\imdb\cache\*');
out_dir = dir('.\output');
for i = 3:length(out_dir)
    rmdir(fullfile('output', out_dir(i).name), 's');
end

% ���·����ѡ��gpuѵ��
active_caffe_mex(1, 'caffe_faster_rcnn');
caffe.set_mode_gpu();

% ����ѵ���ļ�����
model = Model.ZF_for_Faster_RCNN_VOC2007;
cache_base_proposal = 'faster_rcnn_VOC2007_ZF';
cache_base_fast_rcnn = '';
% ���ݼ����أ�ѵ������������
dataset = [];
dataset = Dataset.voc2007_trainval(dataset, 'train', true);
dataset = Dataset.voc2007_test(dataset, 'test', false);
% ���ؾ�ֵ�ļ�
conf_proposal = proposal_config('image_means', model.mean_image, 'feat_stride', model.feat_stride);
conf_fast_rcnn = fast_rcnn_config('image_means', model.mean_image);
% ���û����ļ���
model = Faster_RCNN_Train.set_cache_folder(cache_base_proposal, cache_base_fast_rcnn, model);
% ͨ������ӳ���anchor�������ɺ�ѡ���С 
[conf_proposal.anchors, conf_proposal.output_width_map, conf_proposal.output_height_map] ...
                            = proposal_prepare_anchors(conf_proposal, model.stage1_rpn.cache_name, model.stage1_rpn.test_net_def_file);

% ��ʼѵ��                        
fprintf('\n***************\nstage one proposal \n***************\n');
model.stage1_rpn = Faster_RCNN_Train.do_proposal_train(conf_proposal, dataset, model.stage1_rpn, true);
dataset.roidb_train = cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage1_rpn, x, y), dataset.imdb_train, dataset.roidb_train, 'UniformOutput', false);
dataset.roidb_test = Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage1_rpn, dataset.imdb_test, dataset.roidb_test);
% ����Ƿ���ģ�ͣ���ѵ�����˽�����
% ����ģ�ͼ���ѵ��

fprintf('\n***************\nstage one fast rcnn\n***************\n');
model.stage1_fast_rcnn = Faster_RCNN_Train.do_fast_rcnn_train(conf_fast_rcnn, dataset, model.stage1_fast_rcnn, true);
opts.mAP = Faster_RCNN_Train.do_fast_rcnn_test(conf_fast_rcnn, model.stage1_fast_rcnn, dataset.imdb_test, dataset.roidb_test);

fprintf('\n***************\nstage two proposal\n***************\n');
% �̶���һ�׶ι����ֵĲ������ò���ѧϰ��Ϊ0
model.stage2_rpn.init_net_file = model.stage1_fast_rcnn.output_model_file;
model.stage2_rpn = Faster_RCNN_Train.do_proposal_train(conf_proposal, dataset, model.stage2_rpn, true);
dataset.roidb_train       	= cellfun(@(x, y) Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn, x, y), dataset.imdb_train, dataset.roidb_train, 'UniformOutput', false);
dataset.roidb_test       	= Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn, dataset.imdb_test, dataset.roidb_test);

fprintf('\n***************\nstage two fast rcnn\n***************\n');
% �̶���һ�׶ι����ֵĲ������ò���ѧϰ��Ϊ0
model.stage2_fast_rcnn.init_net_file = model.stage1_fast_rcnn.output_model_file;
model.stage2_fast_rcnn      = Faster_RCNN_Train.do_fast_rcnn_train(conf_fast_rcnn, dataset, model.stage2_fast_rcnn, true);

% ����
fprintf('\n***************\nfinal test\n***************\n');    
model.stage2_rpn.nms        = model.final_test.nms;
dataset.roidb_test       	= Faster_RCNN_Train.do_proposal_test(conf_proposal, model.stage2_rpn, dataset.imdb_test, dataset.roidb_test);
opts.final_mAP              = Faster_RCNN_Train.do_fast_rcnn_test(conf_fast_rcnn, model.stage2_fast_rcnn, dataset.imdb_test, dataset.roidb_test);

% ����ģ��
Faster_RCNN_Train.gather_rpn_fast_rcnn_models(conf_proposal, conf_fast_rcnn, model, dataset);

% anchor���Ƽ�boxӳ��
% ���ڱ������������ͱ�ע�Ƚϱ��أ�ֻ��Ҫһ��anchor�����Գ��Զ�߶ȼ��ʶ��
% scalesΪ8��ratioΪ1�������ñ߳�Ϊ128�Ŀ���Ϊ����iou��box
function [anchors, output_width_map, output_height_map] = proposal_prepare_anchors(conf, cache_name, test_net_def_file)
    [output_width_map, output_height_map] ...                           
                                = proposal_calc_output_size(conf, test_net_def_file);
    anchors                = proposal_generate_anchors(cache_name, ...
                                    'scales',  8,...
                                    'ratios',  [1]);
end