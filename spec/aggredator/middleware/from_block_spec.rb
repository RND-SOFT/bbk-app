RSpec.describe Aggredator::Middleware::FromBlock do
  let(:app) { SecureRandom.hex }
  let(:message) { SecureRandom.hex }

  it '#call' do
    subj = described_class.new do |nxt, msg|
      expect(nxt).to eq app
      expect(msg).to eq message
    end
    subj.build(app)
    subj.call(message)
  end
end
