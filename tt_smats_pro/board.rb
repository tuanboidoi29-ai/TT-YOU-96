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
        @planes = [[0, 1], [0, 2], [1, 2]]
        @plane_names = ['Mặt phẳng Đỏ-Xanh lá (XY)', 'Mặt phẳng Đỏ-Xanh dương (XZ)', 'Mặt phẳng Xanh lá-Xanh dương (YZ)']
      end

      def activate
        update_prompt('Click góc chéo thứ nhất của ván AUTU')
      end

      def onKeyDown(key, _repeat, _flags, _view)
        return unless key == 9

        @plane_index = @plane_index.nil? ? 0 : (@plane_index + 1) % @planes.length
        update_prompt(@first_point ? 'Click góc chéo đối diện để tạo ván' : 'Click góc chéo thứ nhất của ván AUTU')
        _view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        point = view.inputpoint(x, y).position
        if @first_point
          if create_board(@first_point, point)
            @first_point = nil
            @preview_point = nil
            update_prompt('Click góc chéo thứ nhất của ván AUTU tiếp theo')
            view.invalidate
          end
        else
          @first_point = point
          @preview_point = point
          update_prompt('Click góc chéo đối diện để tạo ván')
          view.invalidate
        end
      rescue StandardError => error
        UI.messagebox("Không thể tạo ván.\n#{error.message}")
      end

      def onMouseMove(_flags, x, y, view)
        return unless @first_point

        point = view.inputpoint(x, y).position
        dimensions = rectangle_dimensions(@first_point, point)
        update_prompt("Dài: #{Sketchup.format_length(dimensions[0])} | Rộng: #{Sketchup.format_length(dimensions[1])} | Click để tạo")
        @preview_point = point
        view.invalidate
      end

      def draw(view)
        return unless @first_point && @preview_point

        corners = board_corners(@first_point, @preview_point)
        thickness_vector = normal_vector(corners) * @thickness
        top_corners = corners.map { |point| point + thickness_vector }
        view.line_width = 3
        view.drawing_color = [255, 128, 0, 255]
        view.draw(GL_QUADS, corners)
        view.draw(GL_QUADS, top_corners)
        4.times do |index|
          next_index = (index + 1) % 4
          view.draw(GL_QUADS, [corners[index], corners[next_index], top_corners[next_index], top_corners[index]])
        end
        view.drawing_color = [204, 76, 0, 255]
        view.draw(GL_LINE_STRIP, corners + [corners.first])
        view.draw(GL_LINE_STRIP, top_corners + [top_corners.first])
        4.times do |index|
          next_index = (index + 1) % 4
          view.draw(GL_LINES, [corners[index], top_corners[index]])
        end
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

        face.pushpull(@thickness)
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
        direction = @plane_index ? @plane_names[@plane_index] : 'Tự động theo không gian'
        Sketchup.set_status_text("#{message} | Tab: đổi hướng (#{direction})", SB_PROMPT)
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
