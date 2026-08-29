# frozen_string_literal: true

module TTSmatsPro
  module CreateBoard
    extend self

    def start
      values = UI.inputbox(['Độ dày'], ['18mm'], 'Độ dày ván AUTU')
      return unless values

      thickness = Sketchup.parse_length(values.first.to_s)
      if !thickness || thickness <= 0
        UI.messagebox('Độ dày phải lớn hơn 0 và có đơn vị hợp lệ.')
        return
      end
      Sketchup.active_model.select_tool(PlacementTool.new(thickness))
    end

    class PlacementTool
      def initialize(thickness)
        @thickness = thickness
        @first_point = nil
        @plane_index = nil
        @reverse_thickness = false
        @input_point = Sketchup::InputPoint.new
        @planes = [[0, 1], [0, 2], [1, 2]]
        @plane_names = ['Mặt phẳng Đỏ-Xanh lá (XY)', 'Mặt phẳng Đỏ-Xanh dương (XZ)', 'Mặt phẳng Xanh lá-Xanh dương (YZ)']
        @status_message = 'Chọn điểm đầu tiên để bắt đầu ván'
      end

      def activate
        @status_message = 'Click góc chéo thứ nhất của ván AUTU'
        update_prompt(@status_message)
      end

      def status_summary(message = @status_message)
        direction = @reverse_thickness ? 'Ra ngoài' : 'Vào trong'
        phase = if @first_point
                  'Đang chọn điểm đối diện'
                else
                  'Đang chọn điểm đầu'
                end
        "#{message} | #{phase} | Tab=#{direction} | Esc=hủy"
      end

      def onKeyDown(key, _repeat, _flags, view)
        return unless key == 9

        @reverse_thickness = !@reverse_thickness
        @status_message = @first_point ? 'Click góc chéo đối diện để tạo ván' : 'Click góc chéo thứ nhất của ván AUTU'
        update_prompt(@status_message)
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        @input_point.pick(view, x, y)
        point = @input_point.valid? ? @input_point.position : view.inputpoint(x, y).position
        return unless point
        if @first_point
          if create_board(@first_point, point)
            @first_point = nil
            @preview_point = nil
            @status_message = 'Ván đã tạo. Click góc chéo thứ nhất của ván AUTU tiếp theo'
            update_prompt(@status_message)
            view.invalidate
          end
        else
          @first_point = point
          @preview_point = default_preview_point(point)
          @status_message = 'Click góc chéo đối diện để tạo ván'
          update_prompt(@status_message)
          view.invalidate
        end
      rescue StandardError => error
        UI.messagebox("Không thể tạo ván.\n#{error.message}")
      end

      def onMouseMove(_flags, x, y, view)
        @input_point.pick(view, x, y)
        view.invalidate
        return unless @first_point

        unless preview_available?(view)
          @status_message = 'Chuyển sang View 3D để xem trước ván'
          update_prompt(@status_message)
          @preview_point = nil
          return
        end

        point = @input_point.valid? ? @input_point.position : view.inputpoint(x, y).position
        return unless point

        dimensions = rectangle_dimensions(@first_point, point)
        @status_message = "Dài: #{Sketchup.format_length(dimensions[0])} | Rộng: #{Sketchup.format_length(dimensions[1])} | Click để tạo ván"
        update_prompt(@status_message)
        @preview_point = point
      end

      def draw(view)
        @input_point.draw(view) if @input_point.valid?
        return unless @first_point
        return unless preview_available?(view)

        @preview_point ||= default_preview_point(@first_point)

        corners = board_corners(@first_point, @preview_point)
        return if corners[0].distance(corners[1]) <= 0.001 || corners[0].distance(corners[3]) <= 0.001

        thickness_vector = normal_vector(corners) * signed_thickness
        top_corners = corners.map { |point| point + thickness_vector }
        draw_preview_frame(view, corners, top_corners)
        draw_preview_faces(view, corners, top_corners)
        draw_preview_edges(view, corners, top_corners)
      end

      def draw_preview_frame(view, corners, top_corners)
        view.line_width = 1
        view.drawing_color = [255, 153, 51, 180]
        view.draw(GL_LINE_STRIP, corners + [corners.first])
        view.draw(GL_LINE_STRIP, top_corners + [top_corners.first])
        4.times do |index|
          next_index = (index + 1) % 4
          view.draw(GL_LINES, [corners[index], top_corners[index]])
          view.draw(GL_LINES, [corners[index], corners[next_index]])
        end
      end

      def draw_preview_faces(view, corners, top_corners)
        view.drawing_color = [255, 130, 0, 100]
        view.draw(GL_TRIANGLES, [corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]])
        view.draw(GL_TRIANGLES, [top_corners[0], top_corners[2], top_corners[1], top_corners[0], top_corners[3], top_corners[2]])
        4.times do |index|
          next_index = (index + 1) % 4
          side = [corners[index], corners[next_index], top_corners[next_index], corners[index]]
          view.draw(GL_TRIANGLES, [side[0], side[1], side[2], side[0], side[2], side[3]])
        end
      end

      def draw_preview_edges(view, corners, top_corners)
        view.line_width = 4
        view.drawing_color = [255, 110, 0, 255]
        view.draw(GL_LINE_STRIP, corners + [corners.first])
        view.draw(GL_LINE_STRIP, top_corners + [top_corners.first])
        4.times do |index|
          next_index = (index + 1) % 4
          view.draw(GL_LINES, [corners[index], top_corners[index]])
          view.draw(GL_LINES, [corners[index], corners[next_index]])
        end
      end

      def default_preview_point(point)
        axes = @plane_index ? @planes[@plane_index] : [0, 1]
        length = Sketchup.parse_length('1000mm')
        width = Sketchup.parse_length('500mm')
        coordinates = [point.x, point.y, point.z]
        coordinates[axes[0]] += length
        coordinates[axes[1]] += width
        Geom::Point3d.new(coordinates)
      end

      def onCancel(_reason, _view)
        @first_point = nil
        @preview_point = nil
        Sketchup.set_status_text('', SB_PROMPT)
      end

      private

      def rectangle_dimensions(first_point, second_point)
        coordinates = second_point - first_point
        axes = selected_plane(first_point, second_point)
        [coordinates[axes[0]].abs, coordinates[axes[1]].abs].sort.reverse
      end

      def create_board(first_point, second_point)
        plane_axes = selected_plane(first_point, second_point)
        corners = board_corners(first_point, second_point)
        differences = [second_point.x - first_point.x, second_point.y - first_point.y, second_point.z - first_point.z].map(&:abs)
        raise 'Hai điểm phải khác nhau' if differences[plane_axes[0]] <= 0.001 || differences[plane_axes[1]] <= 0.001

        model = Sketchup.active_model
        model.start_operation('Vẽ ván AUTU từ 2 điểm chéo', true)
        group = model.active_entities.add_group
        face = group.entities.add_face(corners)
        raise 'Không tạo được mặt ván từ hai điểm chéo' unless face

        face.pushpull(signed_thickness)
        group.name = 'Ván AUTU'
        model.commit_operation
        true
      rescue StandardError => error
        model.abort_operation if model&.operation?
        UI.messagebox("Không thể tạo ván.\n#{error.message}")
        false
      end

      def board_corners(first_point, second_point)
        plane_axes = selected_plane(first_point, second_point)
        first_coordinates = [first_point.x, first_point.y, first_point.z]
        second_coordinates = [second_point.x, second_point.y, second_point.z]
        corner_a = first_coordinates.dup
        corner_b = first_coordinates.dup
        corner_c = second_coordinates.dup
        corner_d = second_coordinates.dup
        corner_b[plane_axes[0]] = second_coordinates[plane_axes[0]]
        corner_b[plane_axes[1]] = first_coordinates[plane_axes[1]]
        corner_d[plane_axes[0]] = first_coordinates[plane_axes[0]]
        corner_d[plane_axes[1]] = second_coordinates[plane_axes[1]]
        [corner_a, corner_b, corner_c, corner_d].map { |coordinates| Geom::Point3d.new(coordinates) }
      end

      def normal_vector(corners)
        vector = (corners[1] - corners[0]).cross(corners[3] - corners[0])
        vector.normalize!
        vector
      end

      def update_prompt(message)
        @status_message = message
        plane = @plane_index ? @plane_names[@plane_index] : 'Tự động theo không gian'
        Sketchup.set_status_text("#{status_summary(message)} | Mặt: #{plane}", SB_PROMPT)
      end

      def signed_thickness
        @reverse_thickness ? -@thickness : @thickness
      end

      def preview_available?(view)
        return false unless view
        return false unless view.respond_to?(:is_3d?)

        begin
          view.is_3d?
        rescue StandardError
          false
        end
      end

      def selected_plane(first_point, second_point)
        return @planes[@plane_index] if @plane_index

        delta = second_point - first_point
        differences = [delta.x.abs, delta.y.abs, delta.z.abs]
        normal_axis = differences.each_index.min_by { |index| differences[index] }
        (0..2).to_a - [normal_axis]
      end
    end
  end
end
