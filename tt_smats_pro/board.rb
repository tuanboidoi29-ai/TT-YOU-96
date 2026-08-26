# frozen_string_literal: true

module TTSmatsPro
  module CreateBoard
    extend self

    def start
      values = UI.inputbox(['Dài', 'Rộng', 'Dày'], ['1200mm', '600mm', '18mm'], 'Kích thước ván AUTU')
      return unless values

      lengths = values.map { |value| Sketchup.parse_length(value.to_s) }
      if lengths.any? { |length| !length || length <= 0 }
        UI.messagebox('Kích thước phải lớn hơn 0 và có đơn vị hợp lệ.')
        return
      end
      Sketchup.active_model.select_tool(PlacementTool.new(*lengths))
    end

    class PlacementTool
      def initialize(length, width, thickness)
        @length = length
        @width = width
        @thickness = thickness
      end

      def activate
        Sketchup.set_status_text('Click điểm đặt ván AUTU | Esc để hủy', SB_PROMPT)
      end

      def onLButtonDown(_flags, x, y, view)
        point = view.inputpoint(x, y).position
        model = Sketchup.active_model
        model.start_operation('Vẽ ván AUTU', true)
        group = model.active_entities.add_group
        origin = point
        points = [origin, origin.offset(X_AXIS, @length), origin.offset(X_AXIS, @length).offset(Y_AXIS, @width), origin.offset(Y_AXIS, @width)]
        face = group.entities.add_face(points)
        raise 'Không tạo được mặt ván' unless face

        face.reverse! if face.normal.z < 0
        face.pushpull(@thickness)
        group.name = 'Ván AUTU'
        model.commit_operation
        model.select_tool(nil)
      rescue StandardError => error
        model.abort_operation if model&.operation?
        UI.messagebox("Không thể tạo ván.\n#{error.message}")
      end

      def onCancel(_reason, _view)
        Sketchup.set_status_text('', SB_PROMPT)
      end
    end
  end
end
