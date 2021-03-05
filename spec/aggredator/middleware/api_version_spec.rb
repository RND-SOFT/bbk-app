RSpec.describe Aggredator::Middleware::ApiVersion do
  let(:default_api) { SecureRandom.hex }
  subject { described_class.new default_api }

  let(:msg) { OpenStruct.new headers: {} }
  let(:app) do
    proc do
      yield if block_given?
    end
  end

  it 'set not configured api flag' do
    subject.build(proc do |msg|
      expect(msg.headers['api']).to eq default_api
    end).call(msg)
  end

  it 'not changes configured flag' do
    configured_api = SecureRandom.hex
    msg.headers['api'] = configured_api
    subject.build(proc do |msg|
      expect(msg.headers['api']).to eq configured_api
    end).call(msg)
  end
end
