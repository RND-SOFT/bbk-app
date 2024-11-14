require 'bbk/app/spec/shared/dispatcher/message'

RSpec.describe BBK::App::Dispatcher::Message do
  let(:consumer) { double(stop: nil) }

  include_examples 'BBK::App::Dispatcher::Message' do
    subject(:message) { described_class.new(consumer, delivery_info, headers, body) }
  end

  # let(:consumer) { double(stop: nil) }

  # let(:body) do
  #   JSON.generate Hash[Random.rand(2..6).times.map { [SecureRandom.hex, SecureRandom.hex] }]
  # end

  # describe '#ctor' do
  #   it 'success initialize' do
  #     subj = described_class.new consumer, delivery_info, headers, body
  #     expect(subj.delivery_info).to eq delivery_info
  #     expect(subj.headers).to eq headers.with_indifferent_access
  #     expect(subj.body).to eq body
  #     expect(subj.payload).to eq JSON.parse(body)
  #   end

  #   it 'body not json' do
  #     subj = described_class.new consumer, delivery_info, headers, SecureRandom.hex
  #     expect(subj.payload).to eq({})
  #   end
  # end

  # it '#ack' do
  #   expect(consumer).to receive(:ack)
  #   subject.ack
  # end

  # it '#nack' do
  #   expect(consumer).to receive(:nack)
  #   subject.nack
  # end

  # it '#to_h' do
  #   h = subject.to_h
  #   expect(h).to be_a Hash
  #   expect(h[:headers]).to eq subject.headers
  #   expect(h[:body]).to eq subject.body
  # end
end
