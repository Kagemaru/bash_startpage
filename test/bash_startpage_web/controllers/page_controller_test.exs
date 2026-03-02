defmodule BashStartpageWeb.PageControllerTest do
  use BashStartpageWeb.ConnCase
  import Phoenix.LiveViewTest

  test "GET / renders the startpage live view", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "search or type :command..."
  end
end
