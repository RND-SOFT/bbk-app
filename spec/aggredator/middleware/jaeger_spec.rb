require 'aggredator/middleware/jaeger'
require 'jaeger/client'

RSpec.describe Aggredator::Middleware::Jaeger do
  let(:service_name) { SecureRandom.hex }
  let(:tracer) {
    Jaeger::Client.build(
      service_name: service_name,
      reporter: Jaeger::Reporters::NullReporter.new
    )
  }
  let(:tags) { (2 + rand(10)).times.map{[SecureRandom.hex, SecureRandom.hex]}.to_h }
  let(:parent_span) { tracer.start_span(SecureRandom.hex) }
  let(:processor) {
    Proc.new {[OpenStruct.new(message: OpenStruct.new(headers: {}))]}
  }
  subject { described_class.new(service_name, tracer, tags: tags) }

  it 'new span' do
    expect(tracer).to receive(:start_span).with('test', hash_including(tags: hash_including(tags))).and_call_original
    expect_any_instance_of(Jaeger::Span).to receive(:finish).and_call_original
    in_msg = OpenStruct.new headers: {type: 'test'}, context: {}
    results = subject.build(processor).call(in_msg)
    for r in results
      expect(Jaeger::Extractors::SerializedJaegerTrace.parse(r.message.headers['uber-trace-id'])).not_to be_nil
    end
  end

  it 'derived from passed span' do
    expect_any_instance_of(Jaeger::Span).to receive(:finish)
    in_msg = OpenStruct.new headers: {type: 'ActionRequest', action: 'test'}, context: {}
    tracer.inject(parent_span.context, OpenTracing::FORMAT_TEXT_MAP, in_msg.headers)
    expect(tracer).to receive(:start_span).with('ActionRequest:test', hash_including(child_of: instance_of(Jaeger::SpanContext), tags: hash_including(tags))).and_call_original
    results = subject.build(processor).call(in_msg)
    for r in results
      uber_id = Jaeger::Extractors::SerializedJaegerTrace.parse(r.message.headers['uber-trace-id'])
      expect(uber_id).not_to be_nil
      expect(uber_id.parent_id).to eq parent_span.context.span_id
    end
  end

end