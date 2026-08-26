# frozen_string_literal: true

module TTSmatsPro
  module CreateBoard
    extend self

    def start
      values = UI.inputbox(['Rộng', 'Dày'], ['600mm', '18mm'], 'Kích thước ván AUTU')
      return unless values

      lengths = values.map { |value| Sketchup.parse_length(value.to_s) }
      if lengths.any? { |length| !length || length <= 0 }
        UI.messagebox('Kích thước phải lớn hơn 0 và có đơn vị hợp lệ.')
        return
      end
      Sketchup.active_model.select_tool(PlacementTool.new(*lengths))
    end

    class PlacementTool
      def initialize(width, thickness)
        @width = width
        @thickness = thickness
        @start_point = nil
      end

      def activate
        Sketchup.set_status_text('Click điểm đầu của ván AUTU', SB_PROMPT)
      end

      def onLButtonDown(_flags, x, y, view)
        point = view.inputpoint(x, y).position
        if @start_point
          create_board(@start_point, point)
          Sketchup.active_model.select_tool(nil)
        else
          @start_point = point
          Sketchup.set_status_text('Click điểm cuối để xác định chiều dài và hướng ván', SB_PROMPT)
        end
      rescue StandardError => error
        model.abort_operation if model&.operation?
        UI.messagebox("Không thể tạo ván.\n#{error.message}")
      end

      def onCancel(_reason, _view)
        Sketchup.set_status_text('', SB_PROMPT)
      end

      private

      def create_board(start_point, end_point)
        direction = end_point - start_point
        raise 'Hai điểm phải khác nhau' if direction.length <= 0.001

        direction.normalize!
        reference_axis = direction.parallel?(Z_AXIS) ? Y_AXIS : Z_AXIS
        side_direction = direction.cross(reference_axis)
        side_direction.normalize!
        side_offset = side_direction.clone
        side_offset.length = @width / 2.0

        model = Sketchup.active_model
        model.start_operation('Vẽ ván AUTU theo 2 điểm', true)
        group = model.active_entities.add_group
        points = [
          start_point.offset(side_offset, -1),
          end_point.offset(side_offset, -1),
          end_point.offset(side_offset),
          start_point.offset(side_offset)
        ]
        face = group.entities.add_face(points)
        raise 'Không tạo được mặt ván từ hai điểm' unless face

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
