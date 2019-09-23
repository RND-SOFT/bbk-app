RSpec.describe Aggredator::Processors::Base do

  subject { described_class.new }
  let(:error_text) { SecureRandom.hex }
  let(:message) {
    Aggredator::Dispatcher::Message.new(
      OpenStruct.new,
      {
        headers: {
          message_id: SecureRandom.uuid,
          reply_to: SecureRandom.hex,
          user_id: SecureRandom.hex
        }
      },
      '{}'
    )
  }

  context 'rule' do

    it 'success' do
      derived = Class.new(described_class) do
        def self.rule
          :value
        end
      end
      expect(derived.new.rule).to eq :value 
    end

    it 'not have static rule method' do
      derived = Class.new(described_class)
      expect{ derived.new.rule }.to raise_error(NotImplementedError)
    end

  end

  it 'not implemented process' do
    expect{ subject.process nil }.to raise_error(NotImplementedError)
  end

  it 'call' do
    expect(subject).to receive(:process)
    before_results = []
    after_results = subject.call nil
    expect(before_results).to eq after_results
  end

  it 'make error' do
    context = {a: SecureRandom.hex}
    error_msg = subject.make_error_answer error_text, message, context
    expect(error_msg).to be_a Aggredator::Api::Error
    headers = error_msg.headers
    expect(headers[:correlation_id]).to eq message.message_id
    expect(headers[:original_user_id]).to eq message.user_id

    payload = error_msg.payload
    expect(payload).to include(context)
    expect(payload[:message]).to eq error_text
    expect(payload[:request_properties]).to eq message.properties
  end

end
