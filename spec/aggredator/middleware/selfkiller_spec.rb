RSpec.describe Aggredator::Middleware::SelfKiller do
  let(:dispatcher) { Aggredator::Dispatcher.new(ObserverMock.new) }

  describe '#call' do
    before do
      allow(dispatcher).to receive(:close) { @closed = true }
    end

    context 'when delay = 5, threshold = 10' do
      let(:create_middleware) { described_class.new(dispatcher, delay: 2, threshold: 10) }
      let(:message) { '{ "text": "test" }' }

      it 'stops after 10 messages and 3 seconds' do
        @closed = false
        self_killer = create_middleware
        self_killer.build(double.as_null_object)
        sleep 1
        self_killer.call(message)
        expect(@closed).to be false
        10.times { self_killer.call(message) }
        expect(@closed).to be false
        sleep 1
        self_killer.call(message)
        sleep 0.5
        expect(@closed).to be true
      end
    end
  end
end

class TestError < StandardError; end
