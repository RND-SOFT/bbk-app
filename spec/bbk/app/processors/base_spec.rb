RSpec.describe BBK::App::Processors::Base do
  subject { described_class.new }

  let(:error_text) { SecureRandom.hex }
  let(:message) do
    BBK::App::Dispatcher::Message.new(
      double(stop: nil),
      OpenStruct.new,
      {
        headers: {
          message_id: SecureRandom.uuid,
          reply_to:   SecureRandom.hex,
          user_id:    SecureRandom.hex
        }
      },
      '{}'
    )
  end

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
      expect { derived.new.rule }.to raise_error(NotImplementedError)
    end
  end

  it 'not implemented process' do
    expect { subject.process message }.to raise_error(NotImplementedError)
  end

  it 'call' do
    expect(subject).to receive(:process)
    before_results = []
    after_results = subject.call message
    expect(before_results).to eq after_results
  end
end

