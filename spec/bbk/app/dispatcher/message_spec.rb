RSpec.describe BBK::App::Dispatcher::Message do
  subject { described_class.new(consumer, delivery_info, headers, body) }

  let(:consumer) { double(stop: nil) }

  let(:delivery_info) do
    OpenStruct.new(
      routing_code: SecureRandom.hex,
      delivery_tag: SecureRandom.hex,
      redelivered?: [true, false].sample
    )
  end

  let(:headers) do
    {
      user_id:    SecureRandom.hex,
      reply_to:   SecureRandom.hex,
      message_id: SecureRandom.uuid
    }
  end

  let(:body) do
    JSON.generate Hash[Random.rand(2..6).times.map { [SecureRandom.hex, SecureRandom.hex] }]
  end


  describe '#ctor' do
    it 'success initialize' do
      subj = described_class.new consumer, delivery_info, headers, body
      expect(subj.delivery_info).to eq delivery_info
      expect(subj.headers).to eq headers.with_indifferent_access
      expect(subj.body).to eq body
      expect(subj.payload).to eq JSON.parse(body)
    end

    it 'body not json' do
      subj = described_class.new consumer, delivery_info, headers, SecureRandom.hex
      expect(subj.payload).to eq({})
    end
  end

  it '#ack' do
    expect(consumer).to receive(:ack)
    subject.ack
  end

  it '#nack' do
    expect(consumer).to receive(:nack)
    subject.nack
  end

  it '#to_h' do
    h = subject.to_h
    expect(h).to be_a Hash
    expect(h[:headers]).to eq subject.headers
    expect(h[:body]).to eq subject.body
  end
end

