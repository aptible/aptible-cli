require 'spec_helper'

describe Aptible::CLI::Agent do
  before { subject.stub(:ask) }
  before { subject.stub(:save_token) }

  describe '#version' do
    it 'should print the version' do
      version = Aptible::CLI::VERSION
      expect(STDOUT).to receive(:puts).with "aptible-cli v#{version}"
      subject.version
    end
  end

  describe '#login' do
    let(:token) { double('Aptible::Auth::Token') }

    before do
      m = -> (code) { @code = code }
      OAuth2::Error.send :define_method, :initialize, m
    end
    before { token.stub(:access_token) { 'access_token' } }
    before { subject.stub(:puts) {} }

    it 'should save a token to ~/.aptible/tokens' do
      Aptible::Auth::Token.stub(:create) { token }
      expect(subject).to receive(:save_token).with('access_token')
      subject.login
    end

    it 'should raise an error if authentication fails' do
      Aptible::Auth::Token.stub(:create).and_raise(OAuth2::Error, 'foo')
      expect do
        subject.login
      end.to raise_error 'Could not authenticate with given credentials: foo'
    end

    it 'should use command line arguments if passed' do
      options = { email: 'test@example.com', password: 'password' }
      subject.stub(:options) { options }
      expect(Aptible::Auth::Token).to receive(:create).with(options) { token }
      subject.login
    end

    context 'with OTP' do
      let(:email) { 'foo@example.org' }
      let(:password) { 'bar' }
      let(:token) { '123456' }

      context 'with options' do
        before do
          allow(subject).to receive(:options)
            .and_return(email: email, password: password, otp_token: token)
        end

        it 'should authenticate without otp_token_required feedback' do
          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, otp_token: token,
                  expires_in: Aptible::CLI::TOKEN_EXPIRY_WITH_OTP)
            .once
            .and_return(token)

          subject.login
        end
      end

      context 'with prompts' do
        before do
          [
            [['Email: '], email],
            [['Password: ', echo: false], password],
            [['2FA Token: '], token]
          ].each do |prompt, val|
            expect(subject).to receive(:ask).with(*prompt).once.and_return(val)
          end
        end

        it 'should prompt for an OTP token and use it' do
          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password)
            .once
            .and_raise(OAuth2::Error, 'otp_token_required')

          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, otp_token: token,
                  expires_in: Aptible::CLI::TOKEN_EXPIRY_WITH_OTP)
            .once
            .and_return(token)

          subject.login
        end

        it 'should not retry non-OTP errors.' do
          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password)
            .once
            .and_raise(OAuth2::Error, 'otp_token_required')

          expect(Aptible::Auth::Token).to receive(:create)
            .with(email: email, password: password, otp_token: token,
                  expires_in: Aptible::CLI::TOKEN_EXPIRY_WITH_OTP)
            .once
            .and_raise(OAuth2::Error, 'foo')

          expect { subject.login }.to raise_error(/Could not authenticate/)
        end
      end
    end
  end
end
