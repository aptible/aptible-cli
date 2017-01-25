class StubAccount < OpenStruct; end

Fabricator(:account, from: :stub_account) do
  bastion_host 'localhost'
  dumptruck_port 1234
  handle 'aptible'
  stack

  apps { [] }
  databases { [] }
end
