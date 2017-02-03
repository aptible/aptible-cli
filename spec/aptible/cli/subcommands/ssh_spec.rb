require 'spec_helper'

describe Aptible::CLI::Agent do
  describe '#ssh' do
    let(:app) { Fabricate(:app) }
    let(:operation) { double('operation') }

    context 'TTY control' do
      before do
        expect(subject).to receive(:ensure_app).and_return(app)
        expect(subject).to receive(:fetch_token).and_return('some token')

        expect(app).to receive(:create_operation!).with(
          type: 'execute', command: '/bin/bash', status: 'succeeded'
        ).and_return(operation)
      end

      it 'allocates a TTY if STDIN and STDOUT are TTYs' do
        allow(STDIN).to receive(:tty?).and_return(true)
        allow(STDOUT).to receive(:tty?).and_return(true)

        expect(subject).to receive(:connect_to_ssh_portal).with(
          operation, '-o', 'SendEnv=ACCESS_TOKEN', '-t'
        )
        subject.ssh
      end

      it 'allocates a TTY even if STDERR is redirected ' do
        allow(STDIN).to receive(:tty?).and_return(true)
        allow(STDOUT).to receive(:tty?).and_return(true)
        allow(STDERR).to receive(:tty?).and_return(false)

        expect(subject).to receive(:connect_to_ssh_portal).with(
          operation, '-o', 'SendEnv=ACCESS_TOKEN', '-t'
        )
        subject.ssh
      end

      it 'does not allocate TTY if STDIN is redirected' do
        allow(STDIN).to receive(:tty?).and_return(false)
        allow(STDOUT).to receive(:tty?).and_return(true)

        expect(subject).to receive(:connect_to_ssh_portal).with(
          operation, '-o', 'SendEnv=ACCESS_TOKEN', '-T'
        )
        subject.ssh
      end

      it 'does not allocate TTY if STDOUT is redirected' do
        allow(STDIN).to receive(:tty?).and_return(true)
        allow(STDOUT).to receive(:tty?).and_return(false)

        expect(subject).to receive(:connect_to_ssh_portal).with(
          operation, '-o', 'SendEnv=ACCESS_TOKEN', '-T'
        )
        subject.ssh
      end

      it 'allocates a TTY if forced' do
        subject.options = { force_tty: true }

        allow(STDIN).to receive(:tty?).and_return(false)
        allow(STDOUT).to receive(:tty?).and_return(false)

        expect(subject).to receive(:connect_to_ssh_portal).with(
          operation, '-o', 'SendEnv=ACCESS_TOKEN', '-tt'
        )
        subject.ssh
      end
    end
  end
end
