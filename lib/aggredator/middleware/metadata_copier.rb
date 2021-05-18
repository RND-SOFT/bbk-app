module Aggredator
  module Middleware
    class MetadataCopier < Base
    
      def call(msg)
        results = @app.call(msg)
        in_meta = msg.payload.fetch('metadata') rescue nil
        return results if in_meta.blank?

        results&.each do |res|
          out_msg = res.message
          out_msg.payload[:metadata] = out_msg.payload.fetch(:metadata, {}).reverse_merge(in_meta).except('request_meta')
        end
      end

    end
  end
end