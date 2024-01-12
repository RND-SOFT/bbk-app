RSpec.describe BBK::App::Domains::ByBlock do
  let(:exchange) { SecureRandom.hex }
  let(:routing_key) { SecureRandom.hex }
  subject do
    described_class.new(SecureRandom.hex) do |_route|
      :route
    end
  end

  it '#call' do
    route_info = subject.call(BBK::App::Dispatcher::Route.new('amqp://test'))
    expect(route_info).to eq :route
  end
end

