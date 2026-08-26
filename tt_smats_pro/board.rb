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
      end

      def activate
        Sketchup.set_status_text('Click góc chéo thứ nhất của ván AUTU', SB_PROMPT)
      end

      def onLButtonDown(_flags, x, y, view)
        point = view.inputpoint(x, y).position
        if @first_point
          create_board(@first_point, point)
          Sketchup.active_model.select_tool(nil)
        else
          @first_point = point
          Sketchup.set_status_text('Click góc chéo đối diện để tạo ván', SB_PROMPT)
        end
      rescue StandardError => error
        UI.messagebox("Không thể tạo ván.\n#{error.message}")
      end

      def onMouseMove(_flags, x, y, view)
        return unless @first_point

        point = view.inputpoint(x, y).position
        dimensions = rectangle_dimensions(@first_point, point)
        Sketchup.set_status_text("Dài: #{Sketchup.format_length(dimensions[0])} | Rộng: #{Sketchup.format_length(dimensions[1])} | Click để tạo", SB_PROMPT)
      end

      def onCancel(_reason, _view)
        Sketchup.set_status_text('', SB_PROMPT)
      end

      private

      def rectangle_dimensions(first_point, second_point)
        delta = second_point - first_point
        axes = [delta.x.abs, delta.y.abs, delta.z.abs].sort
        [axes[2], axes[1]]
      end

      def create_board(first_point, second_point)
        delta = second_point - first_point
        differences = [delta.x.abs, delta.y.abs, delta.z.abs]
        normal_axis = differences.each_index.min_by { |index| differences[index] }
        plane_axes = (0..2).to_a - [normal_axis]
        raise 'Hai điểm phải khác nhau' if differences[plane_axes[0]] <= 0.001 || differences[plane_axes[1]] <= 0.001

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

        model = Sketchup.active_model
        model.start_operation('Vẽ ván AUTU từ 2 điểm chéo', true)
        group = model.active_entities.add_group
        face = group.entities.add_face([corner_a, corner_b, corner_c, corner_d])
        raise 'Không tạo được mặt ván từ hai điểm chéo' unless face

        face.pushpull(@thickness)
        group.name = 'Ván AUTU'
        model.commit_operation
      rescue StandardError => error
        model.abort_operation if model&.operation?
        UI.messagebox("Không thể tạo ván.\n#{error.message}")
      end
    end
  end
end
