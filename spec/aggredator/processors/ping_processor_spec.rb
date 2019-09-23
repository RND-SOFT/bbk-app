RSpec.describe Aggredator::Processors::PingProcessor do

  let(:message) {
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
  }

  subject { described_class.new }

  it 'check action' do
    expect(described_class.action).to eq 'ping'
  end

  it 'rule' do
    rule = described_class.rule
    expect(rule).to be_a Array
    expect(rule.size).to eq 2
    expect(rule.first).to eq :meta
    expect(rule.last).to eq Aggredator::Api::Ping.meta_match_rule
  end

  it 'process message' do
    results = []
    expect {
      subject.process(message, results: results)
    }.to change { results.size }.by(1)
    res = results.first
    expect(res).to be_a Aggredator::Dispatcher::Result
    expect(res.route.to_s).to eq "mq://outer@#{message.reply_to}"
  end

end