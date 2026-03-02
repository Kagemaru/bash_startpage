defmodule BashStartpage.Startpage do
  use Ash.Domain, otp_app: :bash_startpage, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource BashStartpage.Startpage.Site
    resource BashStartpage.Startpage.Settings
  end
end
