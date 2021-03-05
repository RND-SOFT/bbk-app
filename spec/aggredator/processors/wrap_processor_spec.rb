RSpec.describe Aggredator::Processors::WrapProcessor do
  let(:wrapped) { Aggredator::Processors::PingProcessor }
  let(:message) do
    Aggredator::Dispatcher::Message.new(
      OpenStruct.new,
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

  subject { described_class.new wrapped }

  it 'check action' do
    expect(subject.action).to eq wrapped.action
  end

  it 'check rule' do
    expect(subject.rule).to eq wrapped.rule
  end

  it 'call preprocess message' do
    val = SecureRandom.hex
    expect(subject.preprocess_message(val)).to eq val
  end

  it 'call postprocess result' do
    res, msg = 2.times.map { SecureRandom.hex }
    expect(subject.postprocess_result(res, msg)).to eq res
  end

  it 'process message with wrapped class' do
    results = []
    expect(subject).to receive(:process).with(message, results: results).and_call_original
    expect_any_instance_of(wrapped).to receive(:process).with(message, results: []).and_call_original
    subject.call(message, results: results)
  end

  it 'process message with wrapped object' do
    wrapped_obj = wrapped.new
    subj = described_class.new wrapped_obj
    results = []
    expect(subj).to receive(:process).with(message, results: results).and_call_original
    expect(wrapped_obj).to receive(:process).with(message, results: []).and_call_original
    subj.call(message, results: results)
  end
end
