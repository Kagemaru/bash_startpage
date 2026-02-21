defmodule BashStartpage.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        BashStartpage.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:bash_startpage, :token_signing_secret)
  end
end
