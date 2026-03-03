defmodule BashStartpage.AccountsTest do
  use ExUnit.Case, async: true

  test "includes User resource" do
    assert BashStartpage.Accounts.User in Ash.Domain.Info.resources(BashStartpage.Accounts)
  end

  test "includes Token resource" do
    assert BashStartpage.Accounts.Token in Ash.Domain.Info.resources(BashStartpage.Accounts)
  end
end
