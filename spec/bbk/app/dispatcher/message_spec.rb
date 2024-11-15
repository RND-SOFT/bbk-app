require 'bbk/app/spec/shared/dispatcher/message'

RSpec.describe BBK::App::Dispatcher::Message do
  let(:consumer) { double(stop: nil) }

  include_examples 'BBK::App::Dispatcher::Message' do
    subject(:message) { described_class.new(consumer, delivery_info, headers, body) }
  end

end
