class StubAccount < OpenStruct
  def each_certificate(&block)
    return enum_for(:each_certificate) if block.nil?
    certificates.each(&block)
  end
end

Fabricator(:account, from: :stub_account) do
  bastion_host 'localhost'
  dumptruck_port 1234
  handle 'aptible'
  stack

  apps { [] }
  databases { [] }
  certificates { [] }
end
