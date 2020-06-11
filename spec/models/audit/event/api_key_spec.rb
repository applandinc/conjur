require 'spec_helper'

describe Audit::Event::ApiKey do
  let(:role_id) { 'rspec:user:my_user' }
  let(:role) { double('The User', id: role_id) }

  let(:other_role_id) { 'rspec:user:other_user' }
  let(:other_role) { double('The Other User', id: other_role_id) }

  let(:subject_role) { role }

  let(:success) { true }
  let(:error_message) { nil }

  subject do
    Audit::Event::ApiKey.new(
      auth_role: role,
      subject_role: subject_role,
      success: success,
      error_message: error_message
    )
  end

  context 'when successful' do
    it 'produces the expected message' do
      expect(subject.message)
        .to eq("rspec:user:my_user successfully rotated their API key")
    end

    it 'uses the INFO log level' do
      expect(subject.severity).to eq(Syslog::LOG_INFO)
    end

    it 'renders to string correctly' do
      expect(subject.to_s).to eq('rspec:user:my_user successfully rotated their API key')
    end

    context 'when user rotates another role\'s key' do
      let(:subject_role) { other_role }

      it 'renders to string correctly' do
        expect(subject.to_s).to eq(
          'rspec:user:my_user successfully rotated the api key for rspec:user:other_user'
        )
      end
    end
  end


  context 'when a failure occurs' do
    let(:success) { false }
    let(:error_message) { 'failed rotation' }

    it 'produces the expected message' do
      expect(subject.message)
        .to eq("rspec:user:my_user failed to rotate their API key: failed rotation")
    end

    it 'uses the WARNING log level' do
      expect(subject.severity).to eq(Syslog::LOG_WARNING)
    end


    context 'when user rotates another role\'s key' do
      let(:subject_role) { other_role }

      it 'renders to string correctly' do
        expect(subject.to_s).to eq(
          'rspec:user:my_user failed to rotate the api key for rspec:user:other_user: failed rotation'
        )
      end
    end
  end
end
