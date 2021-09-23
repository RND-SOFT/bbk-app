RSpec.describe Aggredator::Middleware::SelfKiller, integration: true do
  let(:dispatcher) { Aggredator::Dispatcher.new ObserverMock.new }

  describe '#call' do
    before do
      allow(dispatcher).to receive(:close).and_raise StandardError
    end

    let(:call) { self_killer.call('message') }

    context 'when delay = 5, threshold = 10' do
      let(:self_killer) { described_class.new(dispatcher, delay: 1, threshold: 10) }

      it 'stops after 10 messages and 5 seconds' do
        self_killer.build(double.as_null_object)
        expect(call).to_not eq 'closed'
        expect(10.times { call }).to_not eq 'closed'
        call
        sleep 2
        call
        puts self_killer.inspect
        expect(call).to_not eq 'closed'
      end
    end
  end
end
