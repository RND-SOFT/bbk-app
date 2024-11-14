RSpec.shared_examples 'BBK::App::Dispatcher::Message' do
  let(:consumer) { double }

  let(:delivery_info) do
    {
      routing_code: SecureRandom.hex,
      delivery_tag: SecureRandom.hex,
      redelivered?: [true, false].sample
    }
  end

  let(:headers) do
    {
      user_id: SecureRandom.hex,
      reply_to: SecureRandom.hex,
      message_id: SecureRandom.uuid
    }
  end

  let(:body) { JSON.generate(Hash[Random.rand(2..6).times.map { [SecureRandom.hex, SecureRandom.hex] }]) }
  let(:payload) { JSON.parse(body) }

  describe 'Interface' do
    it { is_expected.to respond_to(:consumer).with(0).argument }
    it { is_expected.to respond_to(:delivery_info).with(0).argument }
    it { is_expected.to respond_to(:headers).with(0).argument }
    it { is_expected.to respond_to(:body).with(0).argument }
    it { is_expected.to respond_to(:payload).with(0).argument }

    it { is_expected.to respond_to(:ack).with_unlimited_arguments.with_keywords(:answer).with_any_keywords }
    it { is_expected.to respond_to(:nack).with_unlimited_arguments.with_keywords(:error).with_any_keywords }

    it { is_expected.to respond_to(:message_id).with(0).argument }
    it { is_expected.to respond_to(:reply_to).with(0).argument }
    it { is_expected.to respond_to(:user_id).with(0).argument }
    it { is_expected.to respond_to(:reply_message_id).with(1).argument }
    it { is_expected.to respond_to(:to_h).with(0).argument }
  end

  describe '#initialize' do
    it { expect { message }.not_to raise_error }
  end

  describe 'methods' do
    it { is_expected.to have_attributes(delivery_info: delivery_info) }
    it { is_expected.to have_attributes(headers: headers) }
    it { is_expected.to have_attributes(body: body) }
    it { is_expected.to have_attributes(payload: payload) }

    context 'with invalid body' do
      let(:body) { ']invalid_trash' }

      it { is_expected.to have_attributes(body: body) }
      it { is_expected.to have_attributes(payload: {}) }
    end

    describe '#ack' do
      it do
        expect(consumer).to receive(:ack).with(message, 1, 2, answer: :answer, a1: :a1)
        subject.ack(1, 2, answer: :answer, a1: :a1)
      end
    end

    describe '#nack' do
      it do
        expect(consumer).to receive(:nack).with(message, 1, 2, error: :error, a1: :a1)
        subject.nack(1, 2, error: :error, a1: :a1)
      end
    end

    describe '#to_h' do
      subject(:hash) { message.to_h }

      it { is_expected.to include(headers: headers) }
      it { is_expected.to include(body: body) }
    end

    describe '#reply_message_id' do
      let(:message_id) { SecureRandom.hex }
      let(:addon) { SecureRandom.hex }
      let(:first_call) { message.reply_message_id(addon) }
      subject(:messagreply_message_ide_id) { message.message_id }

      it {
        expect(message).to receive(:message_id).and_return(message_id)
        expect(first_call).to be_a(String)
      }
      it {
        allow(message).to receive(:message_id).and_return(message_id)
        # multuiple calls has same results
        expect(first_call).to eq(message.reply_message_id(addon))
      }
    end

  end
end
