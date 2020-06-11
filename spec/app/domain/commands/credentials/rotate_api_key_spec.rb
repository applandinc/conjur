require 'spec_helper'

describe Commands::Credentials::RotateApiKey do
  let(:credentials) { double(Credentials) }
  let(:role) { double(Role, credentials: credentials) }

  let(:other_credentials) { double(Credentials) }
  let(:other_role) { double(Role, credentials: other_credentials) }

  let(:err_message) { 'the error message' }

  let(:audit_log) { double(::Audit.logger)}
  let(:audit_success) { double("Successful audit event") }
  let(:audit_failure) { double("Failed audit event") }

  subject do 
    Commands::Credentials::RotateApiKey.new(
      audit_log: audit_log
    )
  end

  context 'when rotating own API key' do
    before do
      # Set up our audit event to return either the success or failure
      # audit event, depending on the arguments received
      allow(::Audit::Event::ApiKey).to receive(:new)
        .with(auth_role: role, subject_role: role, success: true)
        .and_return(audit_success)
  
      allow(::Audit::Event::ApiKey).to receive(:new)
        .with(auth_role: role, subject_role: role, success: false, error_message: err_message)
        .and_return(audit_failure)
    end

    it 'updates the key' do
      # Expect it to rotate the api key on the credentials model, and to save it
      expect(credentials).to receive(:rotate_api_key)
      expect(credentials).to receive(:save)

      # Expect it to log a successful audit message
      expect(audit_log).to receive(:log).with(audit_success)

      # Call the command
      subject.call(role_to_rotate: role, authenticated_role: role)
    end

    it 'bubbles up exceptions' do 
      # Assume the database update fails. This could be caused by an
      # invalid password, database issues, etc.
      allow(credentials).to receive(:rotate_api_key)
      allow(credentials).to receive(:save).and_raise(err_message)

      # Expect it to log a failed audit message
      expect(audit_log).to receive(:log).with(audit_failure)

      # Expect the command to raise the original exception
      expect do
        subject.call(role_to_rotate: role, authenticated_role: role)
      end.to raise_error(err_message)
    end
  end

  context 'when rotating another\'s API key' do
    before do
      # Set up our audit event to return either the success or failure
      # audit event, depending on the arguments received
      allow(::Audit::Event::ApiKey).to receive(:new)
        .with(auth_role: role, subject_role: other_role, success: true)
        .and_return(audit_success)
  
      allow(::Audit::Event::ApiKey).to receive(:new)
        .with(auth_role: role, subject_role: other_role, success: false, error_message: err_message)
        .and_return(audit_failure)
    end

    it 'updates the key' do
      # Expect it to rotate the api key on the credentials model, and to save it
      expect(other_credentials).to receive(:rotate_api_key)
      expect(other_credentials).to receive(:save)

      # Expect it to log a successful audit message
      expect(audit_log).to receive(:log).with(audit_success)

      # Call the command
      subject.call(role_to_rotate: other_role, authenticated_role: role)
    end

    it 'bubbles up exceptions' do 
      # Assume the database update fails. This could be caused by an
      # invalid password, database issues, etc.
      allow(other_credentials).to receive(:rotate_api_key)
      allow(other_credentials).to receive(:save).and_raise(err_message)

      # Expect it to log a failed audit message
      expect(audit_log).to receive(:log).with(audit_failure)

      # Expect the command to raise the original exception
      expect do
        subject.call(role_to_rotate: other_role, authenticated_role: role)
      end.to raise_error(err_message)
    end
  end
end
