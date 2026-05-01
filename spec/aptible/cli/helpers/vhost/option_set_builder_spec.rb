require 'spec_helper'

describe Aptible::CLI::Helpers::Vhost::OptionSetBuilder do
  def register_options(builder)
    klass = Class.new(Thor) { include Aptible::CLI::Helpers::App }
    builder.declare_options(klass)
    klass.instance_variable_get(:@method_options)
  end

  describe '--ssl-protocols-override option description' do
    context 'HTTPS endpoints (ALB, alb! flag set)' do
      let(:builder) do
        described_class.new do
          app!
          tls!
          alb!
        end
      end

      it 'includes PFS values' do
        desc = register_options(builder)[:ssl_protocols_override].description
        expect(desc).to include('PFS')
      end
    end

    context 'TLS endpoints (ELB, tls! without alb!)' do
      let(:builder) do
        described_class.new do
          app!
          tls!
        end
      end

      it 'does not include PFS values' do
        desc = register_options(builder)[:ssl_protocols_override].description
        expect(desc).not_to include('PFS')
      end

      it 'is still present' do
        expect(register_options(builder)).to have_key(:ssl_protocols_override)
      end
    end

    context 'gRPC endpoints (ELB, tls! without alb!)' do
      let(:builder) do
        described_class.new do
          app!
          port!
          tls!
        end
      end

      it 'does not include PFS values' do
        desc = register_options(builder)[:ssl_protocols_override].description
        expect(desc).not_to include('PFS')
      end
    end

    context 'TCP endpoints (no tls! flag)' do
      let(:builder) do
        described_class.new do
          app!
          ports!
        end
      end

      it 'is absent' do
        expect(register_options(builder)).not_to have_key(:ssl_protocols_override)
      end
    end
  end

  describe 'SSL_PROTOCOL_ALB_DESC' do
    subject { described_class::SSL_PROTOCOL_ALB_DESC }

    it 'lists all PFS protocol values' do
      pfs_values = described_class::SSL_PROTOCOL_VALUES.select { |v| v.include?('PFS') }
      pfs_values.each { |v| is_expected.to include(v) }
    end
  end

  describe 'SSL_PROTOCOL_ELB_DESC' do
    subject { described_class::SSL_PROTOCOL_ELB_DESC }

    it 'contains no PFS values' do
      is_expected.not_to include('PFS')
    end

    it 'lists all non-PFS protocol values' do
      non_pfs_values = described_class::SSL_PROTOCOL_VALUES.reject { |v| v.include?('PFS') }
      non_pfs_values.each { |v| is_expected.to include(v) }
    end
  end
end
