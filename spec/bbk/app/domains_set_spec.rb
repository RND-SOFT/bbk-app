# frozen_string_literal: true

RSpec.describe BBK::App::DomainsSet do
  let(:first_domain) { BBK::App::Domains::ByBlock.new('a') {} }
  let(:second_domain) { BBK::App::Domains::ByBlock.new('b') {} }

  subject { described_class.new first_domain, second_domain }

  it '#each' do
    domains = subject.each.to_a
    expect(domains.size).to eq 2
    expect(domains.first).to eq first_domain
    expect(domains.second).to eq second_domain
  end

  it '#has?' do
    expect(subject.has?(first_domain.name)).to be_truthy
    expect(subject.has?(SecureRandom.uuid)).to be_falsey
  end

  it '#[]' do
    expect(subject['a']).to eq first_domain
  end

  it '#add' do
    another = BBK::App::Domains::ByBlock.new('c'){}
    expect do
      subject.add(another)
    end.to change{ subject.each.to_a.size }.by(1)
    expect(subject[another.name]).to eq another
  end
end

