defmodule BashStartpage.Accounts do
  use Ash.Domain, otp_app: :bash_startpage, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource BashStartpage.Accounts.Token
    resource BashStartpage.Accounts.User
  end
end
