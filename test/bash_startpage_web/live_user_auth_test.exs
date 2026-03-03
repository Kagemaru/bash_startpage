defmodule BashStartpageWeb.LiveUserAuthTest do
  use ExUnit.Case, async: true

  alias BashStartpageWeb.LiveUserAuth

  defp socket_with_user do
    %Phoenix.LiveView.Socket{
      endpoint: BashStartpageWeb.Endpoint,
      router: BashStartpageWeb.Router,
      assigns: %{__changed__: %{}, current_user: %BashStartpage.Accounts.User{}}
    }
  end

  defp socket_without_user do
    %Phoenix.LiveView.Socket{
      endpoint: BashStartpageWeb.Endpoint,
      router: BashStartpageWeb.Router,
      assigns: %{__changed__: %{}}
    }
  end

  describe "on_mount(:current_user, ...)" do
    test "continues and assigns resources from session" do
      {:cont, _socket} = LiveUserAuth.on_mount(:current_user, %{}, %{}, socket_without_user())
    end
  end

  describe "on_mount(:live_user_optional, ...)" do
    test "continues when user is present" do
      assert {:cont, _socket} =
               LiveUserAuth.on_mount(:live_user_optional, %{}, %{}, socket_with_user())
    end

    test "assigns nil current_user and continues when no user" do
      {:cont, socket} = LiveUserAuth.on_mount(:live_user_optional, %{}, %{}, socket_without_user())
      assert socket.assigns.current_user == nil
    end
  end

  describe "on_mount(:live_user_required, ...)" do
    test "continues when user is present" do
      assert {:cont, _socket} =
               LiveUserAuth.on_mount(:live_user_required, %{}, %{}, socket_with_user())
    end

    test "halts and redirects to sign-in when no user" do
      assert {:halt, socket} =
               LiveUserAuth.on_mount(:live_user_required, %{}, %{}, socket_without_user())

      assert {:redirect, %{to: "/sign-in"}} = socket.redirected
    end
  end

  describe "on_mount(:live_no_user, ...)" do
    test "halts and redirects to / when user is present" do
      assert {:halt, socket} =
               LiveUserAuth.on_mount(:live_no_user, %{}, %{}, socket_with_user())

      assert {:redirect, %{to: "/"}} = socket.redirected
    end

    test "assigns nil current_user and continues when no user" do
      {:cont, socket} = LiveUserAuth.on_mount(:live_no_user, %{}, %{}, socket_without_user())
      assert socket.assigns.current_user == nil
    end
  end
end
