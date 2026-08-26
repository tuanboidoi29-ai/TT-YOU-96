# frozen_string_literal: true

require 'fileutils'

root = File.expand_path(__dir__)
version = File.read(File.join(root, 'tt_smats_pro', 'main.rb')).match(/VERSION = '([^']+)'/)[1]
output = File.join(root, "TT-SMATS-PRO-RBZ-v#{version}.rbz")
files = ['tt_smats_pro.rb', 'update.json']
files << Dir[File.join(root, 'tt_smats_pro', '**', '*')].reject { |path| File.directory?(path) }.map { |path| path.delete_prefix("#{root}/") }
files = files.flatten

File.delete(output) if File.exist?(output)
Dir.chdir(root) do
  system('zip', '-r', output, *files, exception: true)
end
puts output