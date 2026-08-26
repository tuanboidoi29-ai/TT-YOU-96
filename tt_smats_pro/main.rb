# frozen_string_literal: true

require 'json'
require 'net/http'
require 'rubygems/version'
require 'uri'
require 'sketchup.rb'
require 'tempfile'
require File.join(__dir__, 'board')

module TTSmatsPro
  VERSION = '1.0.6'
  REPOSITORY = 'tuanboidoi29-ai/TT-YOU-96'
  MANIFEST_URL = "https://api.github.com/repos/#{REPOSITORY}/contents/update.json?ref=main"

  module_function

  def start_update_check
    return if @update_check_running

    @update_check_running = true
    Thread.new do
      result = fetch_manifest
      UI.start_timer(0, false) { finish_update_check(result) }
    rescue StandardError => error
      UI.start_timer(0, false) { finish_update_check(error) }
    end
    UI.start_timer(0, false) { Sketchup.set_status_text('Đang kiểm tra bản cập nhật TT -SMATS PRO...') }
  end

  def fetch_manifest
    uri = URI(MANIFEST_URL)
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = "TT-SMATS-PRO/#{VERSION}"
    request['Accept'] = 'application/vnd.github.raw+json'
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
    Thread.new do
      archive_path = download_archive(download_url)
      UI.start_timer(0, false) { install_update(archive_path) }
    rescue StandardError => error
      UI.start_timer(0, false) { finish_update_check(error) }
    end
    Sketchup.set_status_text('Đang tải bản cập nhật TT -SMATS PRO...')
  end

  def download_archive(download_url)
    raise 'Manifest chưa có đường dẫn RBZ hợp lệ' unless download_url.start_with?('https://')

    uri = URI(download_url)
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = "TT-SMATS-PRO/#{VERSION}"
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 30) do |http|
      http.request(request)
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
      Sketchup.load(File.join(__dir__, 'main.rb'))
      UI.messagebox('Đã cập nhật TT -SMATS PRO và nạp lại hệ thống thành công.')
    else
      UI.messagebox('SketchUp không cài được bản cập nhật RBZ.')
    end
  rescue StandardError => error
    UI.messagebox("Cập nhật thất bại.\n#{error.message}")
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
