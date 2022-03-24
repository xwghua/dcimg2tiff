classdef dcimg
    properties (Constant = true)
        FILE_HDR_DTYPE = {  'uint8',[8 1],'file_format';...
                            'uint32',[1 1],'format_version';...
                            'uint32',[5 1],'skip';...
                            'uint32',[1 1],'nsess';...
                            'uint32',[1 1],'nfrms';...
                            'uint32',[1 1],'header_size';...
                            'uint32',[1 1],'skip2';...
                            'uint64',[1 1],'file_size';...
                            'uint32',[2 1],'skip3';...
                            'uint64',[1 1],'file_size2'  };

        SESS_HDR_DTYPE = {  'uint64',[1 1],'session_size';...
                            'uint32',[13 1],'skip1';...
                            'uint32',[1 1],'nfrms';...
                            'uint32',[1 1],'byte_depth';...
                            'uint32',[1 1],'skip2';...
                            'uint32',[1 1],'xsize';...
                            'uint32',[1 1],'ysize';...
                            'uint32',[1 1],'bytes_per_row';...
                            'uint32',[1 1],'bytes_per_img';...
                            'uint32',[2 1],'skip3';...
                            'uint32',[1 1],'offset_to_data'  };

        NEW_CROP_INFO = {  'uint16',[1 1],'x0';...
                           'uint16',[1 1],'xsize';...
                           'uint16',[1 1],'y0';...
                           'uint16',[1 1],'ysize'  };

        FMT_OLD = 1;
        FMT_NEW = 2;
    end
    properties (Access = public)
        dc_mm = nan; % a `numpy.memmap` object with the raw contents of the DCIMG file.
        data = nan; % memory-mapped `numpy.ndarray` of the image data, without 4px correction.
        dc_deep_copy_enabled = nan;

        dc_file_header = nan;
        dc_sess_header = nan;
%         dc_sess_footer = nan;
%         dc_sess_footer2 = nan;
        dc_ts_data = nan;
        dc_fs_data = nan;
        dc_file_path = '';
        dc_fmt_version = nan;
        dc_x0 = 0;
        dc_y0 = 0;
        dc_binning = 1
        dc_target_line = -1;
        dc_first_4px_correction_enabled = true;
        dc_4px = nan;
    end
    
    methods
        %% =================== dcimg ===================
        function DCIMGFile = dcimg(file_path,slices)
            if ~isempty(file_path)
                DCIMGFile.dc_file_path = file_path;
                if nargin ==1
                    DCIMGFile = DCIMGFile.dcfunc_parse_header();
                elseif nargin ==2
                    DCIMGFile = DCIMGFile.dcimg_open(slices);
                end
            end
        end
        %% =================== open ===================
        function DCIMGFile = dcimg_open(DCIMGFile,slices)
            DCIMGFile.dcimg_close();
            try
                DCIMGFile = DCIMGFile.dcfunc_parse_header();
            catch ME
                DCIMGFile.dcimg_close();
                throw(ME);
            end

            bd = DCIMGFile.dc_sess_header.byte_depth;
            data_offset = DCIMGFile.dc_file_header.header_size+DCIMGFile.dc_sess_header.offset_to_data;
            strides = round(double([1,1,(DCIMGFile.dc_sess_header.bytes_per_img + 32)/bd]));
            dc_4px_shape = double([1,4,DCIMGFile.dc_sess_header.nfrms]);
            DCIMGFile.dc_4px = DCIMGFile.dcimg_ndarray('uint16',dc_4px_shape,...
                data_offset,strides,slices,DCIMGFile.dc_sess_header.bytes_per_img + 12);

            padding = DCIMGFile.dc_sess_header.bytes_per_img - DCIMGFile.dc_sess_header.xsize * DCIMGFile.dc_sess_header.ysize * bd;
            padding = floor(padding/DCIMGFile.dc_sess_header.ysize);
            data_strides = double(round([bd,DCIMGFile.dc_sess_header.xsize*bd+padding,DCIMGFile.dc_sess_header.bytes_per_img+32]/bd));
            data_shape = double([DCIMGFile.dc_sess_header.ysize,DCIMGFile.dc_sess_header.xsize,DCIMGFile.dc_sess_header.nfrms]);

            DCIMGFile.data = DCIMGFile.dcimg_ndarray('uint16',data_shape,data_offset,data_strides,slices);
            DCIMGFile = DCIMGFile.compute_target_line();
            DCIMGFile.data(DCIMGFile.dc_target_line,1:4,:) = DCIMGFile.dc_4px;
        end
        %% =================== compute_target_line ===================
        function DCIMGFile = compute_target_line(DCIMGFile)
                DCIMGFile.dc_target_line = floor((1023 - DCIMGFile.dc_y0+1) / DCIMGFile.dc_binning);
        end
        %% =================== close ===================
        function DCIMGFile = dcimg_close(DCIMGFile)
           DCIMGFile.dc_mm = nan;
        end
        %% =================== ndarray ===================
        function outputArray = dcimg_ndarray(DCIMGFile,fileformat,arrayShape,offset,strides,varargin)
            filename = DCIMGFile.dc_file_path;
            arrayShape1 = arrayShape(1);
            arrayShape(1) = arrayShape(2);
            arrayShape(2) = arrayShape1;
            memmapsize = [1 round(double(arrayShape(end)).*double(strides(end)))];
            memmapformat = {fileformat,memmapsize,'data'};
            mm = memmapfile(filename,'Format',memmapformat,'Offset',offset,'Repeat',1);
            if length(arrayShape)==2
                mm_ind = repmat(1:arrayShape(1),arrayShape(2),1)'+repmat(0:arrayShape(2)-1,arrayShape(1),1)*strides(2);
            elseif length(arrayShape)==3
                if nargin<=5
                    error('Please specify slice indices!')
                elseif nargin >=6
                    slices = double(varargin{1});
                    for ii = slices
                        mm_ind = repmat((1:arrayShape(1))',1,arrayShape(2),length(slices)) + ...
                            repmat(0:arrayShape(2)-1,arrayShape(1),1,length(slices))*strides(2);
                        mm_ind = mm_ind + repmat(reshape(slices-1,1,1,[]),arrayShape(1),arrayShape(2),1)*strides(3);
                    end
                    if nargin ==7
                        mm_ind = mm_ind + round(double(varargin{2})/2);
                    end
                end
            end
            outputArray = mm.Data.data(mm_ind(:));
            outputArray = reshape(outputArray,arrayShape(1),arrayShape(2),[]);
            outputArray = permute(outputArray,[2 1 3]);
        end
        %% =================== parse_header ===================
        function DCIMGFile = dcfunc_parse_header(DCIMGFile)
            dcimg_hdr_mem = memmapfile(DCIMGFile.dc_file_path,'Format',DCIMGFile.FILE_HDR_DTYPE,'Repeat',1);
            DCIMGFile.dc_file_header = dcimg_hdr_mem.Data;
            DCIMGFile.dc_fmt_version = DCIMGFile.FMT_NEW;

            dcimg_sess_hdr_mem = memmapfile(DCIMGFile.dc_file_path,'Format',...
                DCIMGFile.SESS_HDR_DTYPE,'Offset',DCIMGFile.dc_file_header.header_size,'Repeat',1);
            DCIMGFile.dc_sess_header = dcimg_sess_hdr_mem.Data;

            ii = DCIMGFile.dc_file_header.header_size + 712;
            dcimg_crop_info_mem = memmapfile(DCIMGFile.dc_file_path,'Format',...
                DCIMGFile.NEW_CROP_INFO,'Offset',ii,'Repeat',1);
            crop_info = dcimg_crop_info_mem.Data;
            DCIMGFile.dc_x0 = crop_info.x0;
            DCIMGFile.dc_y0 = crop_info.y0;
            binning_x = floor(double(crop_info.xsize)/double(DCIMGFile.dc_sess_header.xsize));
            binning_y = floor(double(crop_info.ysize)/double(DCIMGFile.dc_sess_header.ysize));

            if binning_y~=binning_x
                error('different binning in X and Y');
            end

            DCIMGFile.dc_binning = binning_x;
        end
        %% =================== parse_footer ===================
        function DCIMGFile = dcfunc_parse_footer(DCIMGFile)

        end
        %% =================== dcprop_has_4px_data ===================
        function has_4px_data = dcprop_has_4px_data(DCIMGFile)
%             Whether the footer contains 4px correction (only for `FMT_OLD`)
%             Returns
%             -------
%             bool
            if DCIMGFile.dc_fmt_version == DCIMGFile.FMT_NEW
                error('not implemented for FMT_NEW')
            end

            footer_size = round(DCIMGFile.dc_sess_footer.footer_size);
            offset_to_4px = round(DCIMGFile.dc_sess_footer2.offset_to_4px);

            has_4px_data = (footer_size == (offset_to_4px + ...
                4 * DCIMGFile.dc_sess_header.byte_depth * ...
                DCIMGFile.dc_sess_header.nfrms));
        end
        %% =================== dcprop_session_footer_offset ===================
        function session_footer_offset = dcprop_session_footer_offset(DCIMGFile)
            sess_data_size = nan;
            if DCIMGFile.dc_fmt_version == DCIMGFile.FMT_OLD
                sess_data_size = round(DCIMGFile.dc_sess_header.session_data_size);
            elseif DCIMGFile.dc_fmt_version == DCIMGFile.FMT_NEW
                sess_data_size = DCIMGFile.dc_sess_header.offset_to_data + ...
                    (round(DCIMGFile.dc_sess_header.bytes_per_img+8) * ...
                    DCIMGFile.dc_sess_header.nfrms);
            end
            session_footer_offset = DCIMGFile.dc_file_header.header_size + sess_data_size;
        end
    end
end