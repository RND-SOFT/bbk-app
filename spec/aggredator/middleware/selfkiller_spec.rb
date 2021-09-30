RSpec.describe Aggredator::Middleware::SelfKiller do
  let(:dispatcher) { instance_double(Aggredator::Dispatcher) }

  describe '#call' do

    context 'when delay = 2, threshold = 10' do
      let(:killer) { described_class.new(dispatcher, delay: 1, threshold: 10).build(double.as_null_object) }
      let(:message) { '{ "text": "test" }' }

      it 'stops on call after 10 messages and 2 seconds' do
        expect(dispatcher).to receive(:close).once.and_return(false)
        killer.call(message)
        sleep 1.1
        11.times { killer.call(message) }
        sleep 0.5 # wait for thread termination
      end
    end
  end
end
