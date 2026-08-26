# frozen_string_literal: true

require 'sketchup.rb'
require 'extensions.rb'

module TTSmatsPro
  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new('TT -SMATS PRO RBZ', 'tt_smats_pro/main')
    extension.description = 'Bộ công cụ SketchUp tiếng Việt: vẽ ván AUTU và tự kiểm tra bản cập nhật từ GitHub.'
    extension.version = '1.0.4'
    extension.creator = 'TRẦN TUẤN'
    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end