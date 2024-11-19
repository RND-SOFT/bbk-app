require 'bbk/app/spec'

RSpec.describe BBK::App::Spec::Dispatcher::Message do
  let(:consumer){ double }
  let(:message_id){ SecureRandom.hex }
  subject { described_class.new(consumer, {}, { message_id: message_id }, '{}') }

  it { is_expected.to be_a(BBK::App::Dispatcher::Message) }
  it { is_expected.to have_attributes(message_id: message_id, reply_to: nil, user_id: nil) }
end

