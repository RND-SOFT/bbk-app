RSpec.describe Aggredator::Processors::PingProcessor do
  let(:message) do
    Aggredator::Dispatcher::Message.new(
      OpenStruct.new(delivery_tab: SecureRandom.uuid),
      {
        headers: {
          message_id: SecureRandom.uuid,
          reply_to: SecureRandom.hex,
          user_id: SecureRandom.hex
        }
      },
      '{}'
    )
  end

  subject { described_class.new }

  it 'check action' do
    expect(described_class.action).to eq 'ping'
  end

  it 'rule' do
    rule = described_class.rule
    expect(rule).to be_a Array
    expect(rule.size).to eq 2
    expect(rule.first).to eq :meta
    expect(rule.last).to eq Aggredator::Api::V1::Ping.meta_match_rule[:headers]
  end

  it 'process message' do
    results = []
    expect do
      subject.process(message, results: results)
    end.to change { results.size }.by(1)
    res = results.first
    expect(res).to be_a Aggredator::Dispatcher::Result
    expect(res.route.to_s).to eq "mq://outer@#{message.reply_to}"
  end
end
