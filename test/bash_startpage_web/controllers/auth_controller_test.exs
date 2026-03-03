defmodule BashStartpageWeb.AuthControllerTest do
  use BashStartpageWeb.ConnCase, async: true

  alias BashStartpageWeb.AuthController

  setup %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Phoenix.Controller.fetch_flash([])

    {:ok, conn: conn}
  end

  # A minimal user struct that satisfies store_in_session, which reads
  # __metadata__.token to persist the session token.
  defp fake_user do
    %BashStartpage.Accounts.User{
      id: Ecto.UUID.generate(),
      __metadata__: %{token: "fake.jwt.token"}
    }
  end

  describe "failure/3" do
    test "redirects to sign-in with a generic error message", %{conn: conn} do
      conn = AuthController.failure(conn, {:password, :sign_in}, %RuntimeError{message: "fail"})

      assert redirected_to(conn) == ~p"/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Incorrect email or password"
    end

    test "shows specific message for CannotConfirmUnconfirmedUser error", %{conn: conn} do
      reason = %AshAuthentication.Errors.AuthenticationFailed{
        caused_by: %Ash.Error.Forbidden{
          errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
        }
      }

      conn = AuthController.failure(conn, :any, reason)

      assert redirected_to(conn) == ~p"/sign-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not confirmed your account"
    end
  end

  describe "sign_out/2" do
    test "redirects to / and flashes sign-out message", %{conn: conn} do
      conn = AuthController.sign_out(conn, %{})

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "You are now signed out"
    end

    test "redirects to return_to session value when present", %{conn: conn} do
      conn =
        conn
        |> put_session(:return_to, "/some-path")
        |> AuthController.sign_out(%{})

      assert redirected_to(conn) == "/some-path"
    end
  end

  describe "success/4" do
    test "flashes signed-in message and redirects to / for generic activity", %{conn: conn} do
      conn = AuthController.success(conn, {:password, :sign_in}, fake_user(), nil)

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "You are now signed in"
    end

    test "flashes email confirmation message for confirm_new_user activity", %{conn: conn} do
      conn = AuthController.success(conn, {:confirm_new_user, :confirm}, fake_user(), nil)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Your email address has now been confirmed"
    end

    test "flashes password reset message for password reset activity", %{conn: conn} do
      conn = AuthController.success(conn, {:password, :reset}, fake_user(), nil)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Your password has successfully been reset"
    end

    test "redirects to return_to session value when present", %{conn: conn} do
      conn =
        conn
        |> put_session(:return_to, "/dashboard")
        |> AuthController.success(:other, fake_user(), nil)

      assert redirected_to(conn) == "/dashboard"
    end
  end
end
