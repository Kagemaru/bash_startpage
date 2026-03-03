defmodule BashStartpage.SecretsTest do
  use ExUnit.Case, async: true

  alias BashStartpage.Secrets

  test "returns the token signing secret for the User resource" do
    assert {:ok, secret} =
             Secrets.secret_for(
               [:authentication, :tokens, :signing_secret],
               BashStartpage.Accounts.User,
               [],
               %{}
             )

    assert is_binary(secret)
    assert byte_size(secret) > 0
  end
end
