# frozen_string_literal: true

require 'json'
require 'net/http'
require 'rubygems/version'
require 'uri'
require 'sketchup.rb'
require 'tempfile'
require File.join(__dir__, 'board')

module TTSmatsPro
  VERSION = '1.1.7'
  REPOSITORY = 'tuanboidoi29-ai/TT-YOU-96'
  MANIFEST_URL = "https://raw.githubusercontent.com/#{REPOSITORY}/main/update.json"

  module_function

  def start_update_check
    return if @update_check_running

    @update_check_running = true
    @update_result = nil
    Thread.new do
      @update_result = fetch_manifest
    rescue StandardError => error
      @update_result = error
    end
    Sketchup.set_status_text('Đang kiểm tra bản cập nhật TT -SMATS PRO...')
    wait_for_update_result
  end

  def wait_for_update_result
    UI.start_timer(0.1, true) do
      next unless @update_result

      timer = @update_timer
      UI.stop_timer(timer) if timer
      @update_timer = nil
      finish_update_check(@update_result)
    end.tap { |timer| @update_timer = timer }
  end

  def fetch_manifest
    uri = URI("#{MANIFEST_URL}?t=#{Time.now.to_i}")
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = "TT-SMATS-PRO/#{VERSION}"
    request['Cache-Control'] = 'no-cache'
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 8) do |http|
      http.request(request)
    end
    raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def finish_update_check(result)
    @update_check_running = false
    if result.is_a?(Exception)
      UI.messagebox("Không thể kiểm tra cập nhật.\n#{result.message}")
      return
    end

    version = result['version'].to_s
    if version.empty? || Gem::Version.new(version) <= Gem::Version.new(VERSION)
      UI.messagebox("Bạn đang dùng phiên bản mới nhất (#{VERSION}).")
      return
    end

    message = "Có phiên bản #{version} mới.\n\n#{result['notes']}\n\nTải và cài đặt ngay?"
    return unless UI.messagebox(message, MB_YESNO) == IDYES

    download_update(result['download_url'].to_s)
  end

  def download_update(download_url)
    @update_check_running = true
    @update_result = nil
    Thread.new do
      @update_result = download_archive(download_url)
    rescue StandardError => error
      @update_result = error
    end
    Sketchup.set_status_text('Đang tải bản cập nhật TT -SMATS PRO...')
    UI.start_timer(0.1, true) do
      next unless @update_result

      timer = @download_timer
      UI.stop_timer(timer) if timer
      @download_timer = nil
      if @update_result.is_a?(Exception)
        finish_update_check(@update_result)
      else
        install_update(@update_result)
      end
    end.tap { |timer| @download_timer = timer }
  end

  def download_archive(download_url)
    raise 'Manifest chưa có đường dẫn RBZ hợp lệ' unless download_url.start_with?('https://')

    uri = URI(download_url)
    response = nil
    5.times do
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = "TT-SMATS-PRO/#{VERSION}"
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 30) do |http|
        http.request(request)
      end
      break unless response.is_a?(Net::HTTPRedirection)

      uri = URI(response['location'])
    end
    raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    file = Tempfile.new(['tt-smats-pro-', '.rbz'])
    file.binmode
    file.write(response.body)
    file.close
    file.path
  end

  def install_update(archive_path)
    @update_check_running = false
    installed = Sketchup.install_from_archive(archive_path)
    File.delete(archive_path) if File.exist?(archive_path)
    if installed
      reload_system
      UI.messagebox('Đã cập nhật và nạp lại TT -SMATS PRO thành công.')
    else
      UI.messagebox('SketchUp không cài được bản cập nhật RBZ.')
    end
  rescue StandardError => error
    UI.messagebox("Cập nhật thất bại.\n#{error.message}")
  end

  def reload_system
    plugins_path = Sketchup.find_support_file('Plugins')
    raise 'Không tìm thấy thư mục Plugins của SketchUp' unless plugins_path

    loader_path = File.join(plugins_path, 'tt_smats_pro.rb')
    runtime_path = File.join(plugins_path, 'tt_smats_pro', 'main.rb')
    raise 'Không tìm thấy loader sau khi cài cập nhật' unless File.file?(loader_path)
    raise 'Không tìm thấy runtime sau khi cài cập nhật' unless File.file?(runtime_path)

    Kernel.load(loader_path)
    Kernel.load(runtime_path)
    raise 'Runtime mới chưa được nạp' unless TTSmatsPro::VERSION == VERSION
  end

  def show_about
    UI.messagebox("TT -SMATS PRO RBZ\nVersion: #{VERSION}\nCreator: TRẦN TUẤN\n\nBộ công cụ vẽ và quản lý cập nhật cho SketchUp.")
  end

  unless file_loaded?(__FILE__)
    menu = UI.menu('Extensions').add_submenu('TT -SMATS PRO RBZ')
    menu.add_item('Vẽ ván AUTU') { CreateBoard.start }
    menu.add_item('Đổi độ dày và tiếp tục vẽ') { CreateBoard.start }
    menu.add_separator
    menu.add_item('Kiểm tra bản cập nhật') { start_update_check }
    menu.add_item('Thông tin plugin') { show_about }

    toolbar = UI::Toolbar.new('TT -SMATS PRO')
    board_command = UI::Command.new('Vẽ ván AUTU') { CreateBoard.start }
    board_command.tooltip = 'Vẽ ván AUTU'
    board_command.status_bar_text = 'Nhập kích thước và chọn điểm đặt ván'
    board_command.small_icon = File.join(__dir__, 'icons', 'board.svg')
    board_command.large_icon = File.join(__dir__, 'icons', 'board.svg')
    toolbar.add_item(board_command)

    update_command = UI::Command.new('Cập nhật TT -SMATS PRO') { start_update_check }
    update_command.tooltip = 'Kiểm tra cập nhật TT -SMATS PRO'
    update_command.status_bar_text = 'Kiểm tra phiên bản mới từ GitHub'
    update_command.small_icon = File.join(__dir__, 'icons', 'update.svg')
    update_command.large_icon = File.join(__dir__, 'icons', 'update.svg')
    toolbar.add_item(update_command)
    toolbar.show

    file_loaded(__FILE__)
  end
end
