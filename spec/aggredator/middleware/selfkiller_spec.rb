RSpec.describe Aggredator::Middleware::SelfKiller, integration: true do
  class TestError < StandardError; end

  let(:dispatcher) { Aggredator::Dispatcher.new(ObserverMock.new) }

  describe '#call' do
    before do
      allow(dispatcher).to receive(:close).and_raise TestError
    end

    context 'when delay = 5, threshold = 10' do
      let(:create_middleware) { described_class.new(dispatcher, delay: 1, threshold: 10) }
      let(:message) { '{ "text": "test" }' }

      it 'stops after 10 messages and 5 seconds' do
        self_killer = create_middleware
        self_killer.build(double.as_null_object)
        expect(self_killer.call(message)).to_not eq 'closed'
        expect{ 10.times { self_killer.call(message) } }.not_to raise_exception(TestError)
        sleep 1
        expect{ self_killer.call(message) }.to raise_exception(TestError)
      end
    end
  end
end
