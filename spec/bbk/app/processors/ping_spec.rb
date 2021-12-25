RSpec.describe BBK::App::Processors::Ping do
  subject { described_class.new pong_message_factory, pong_route }

  let(:ping_message) do
    BBK::App::Dispatcher::Message.new(
      double(stop: nil),
      OpenStruct.new(delivery_tag: SecureRandom.uuid),
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

  let(:pong_message_factory) { double }
  let(:pong_route) { 'test://domain@test' }

  it 'process message' do
    expect(pong_message_factory).to receive(:build) do |orig_msg|
      expect(orig_msg).to eq ping_message
      orig_msg
    end
    results = []
    expect do
      subject.process(ping_message, results: results)
    end.to change { results.size }.by(1)
    res = results.first
    expect(res).to be_a BBK::App::Dispatcher::Result
    expect(res.route.to_s).to eq pong_route
  end
end

