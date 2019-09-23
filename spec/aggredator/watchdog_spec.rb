RSpec.describe Aggredator::Watchdog do

  let(:session){ BunnyMock.new.start }
  let(:channel){ session.channel }
  let(:main){ channel.exchange('main') }
  let(:queue){ channel.queue('testqueue') }
  let(:client){ Aggredator::Client.new(main, 'client1') }
  let(:watcher_delay) { 3 }
  let(:timeout) { 1 }
  let(:delay) { 3 }

  subject { described_class.new client, queue: queue, watcher_delay: watcher_delay, timeout: 1, delay: delay }

  it 'call start' do
    expect(subject).to receive(:startpinger)
    expect(subject).to receive(:startwatcher)
    subject.start
  end

  it 'touch' do
    old_value = subject.instance_variable_get('@timestamp')
    sleep 1
    expect {
      subject.touch
    }.to change {subject.instance_variable_get('@timestamp')}
    expect(subject.instance_variable_get('@timestamp')).to satisfy {|v| v > old_value } 
  end

  it 'watcher' do
    expect(STDERR).to receive(:puts).with(/\[CRITICAL\]/)
    expect(subject).to receive(:exit!).with(8)

    thread = subject.startwatcher

    sleep watcher_delay + 2
    thread.kill
  end

  it 'pinger' do
    client = subject.instance_variable_get('@client')
    expect(client).to receive(:direct_publish).and_call_original
    expect(client).to receive(:direct_publish).and_call_original
    thread = subject.startpinger
    sleep delay + 2
    thread.kill

    messages = channel.default_exchange.messages
    expect(messages.size).to eq 2
    body, props, *_  = messages.first
    expect(body).to eq 'watchdog ping'
    expect(props[:routing_key]).to eq queue.name
    
    headers = props[:headers]
    expect(headers[:reply_to]).to eq queue.name
    expect(headers).to have_key :message_id
    expect(headers[:type]).to eq Aggredator::Api::Ping.type 
  end

end