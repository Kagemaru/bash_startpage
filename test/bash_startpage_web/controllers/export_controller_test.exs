defmodule BashStartpageWeb.ExportControllerTest do
  use BashStartpageWeb.ConnCase, async: true

  alias BashStartpage.Startpage.{Site, Settings}

  setup do
    {:ok, _} = Ash.create(Settings, %{theme: "mocha", timezone: "UTC", offset: 0})

    {:ok, _} =
      Ash.create(Site, %{
        name: "GitHub",
        url: "https://github.com",
        shortcuts: ["gh"],
        tags: ["dev"],
        position: 1
      })

    :ok
  end

  test "GET /export returns 200", %{conn: conn} do
    conn = get(conn, ~p"/export")
    assert response(conn, 200)
  end

  test "GET /export returns content-type text/plain", %{conn: conn} do
    conn = get(conn, ~p"/export")
    [content_type | _] = get_resp_header(conn, "content-type")
    assert content_type =~ "text/plain"
  end

  test "GET /export has attachment content-disposition with config.toml filename", %{conn: conn} do
    conn = get(conn, ~p"/export")
    [disposition | _] = get_resp_header(conn, "content-disposition")
    assert disposition =~ "attachment"
    assert disposition =~ "config.toml"
  end

  test "GET /export body contains [settings] TOML section", %{conn: conn} do
    conn = get(conn, ~p"/export")
    body = response(conn, 200)
    assert body =~ "[settings]"
    assert body =~ ~s(theme = "mocha")
    assert body =~ ~s(timezone = "UTC")
    assert body =~ "offset = 0"
  end

  test "GET /export body contains [[sites]] TOML section for each site", %{conn: conn} do
    conn = get(conn, ~p"/export")
    body = response(conn, 200)
    assert body =~ "[[sites]]"
    assert body =~ ~s(name = "GitHub")
    assert body =~ ~s(url = "https://github.com")
  end

  test "GET /export works with no settings record (uses defaults)", %{conn: conn} do
    Ash.bulk_destroy(Settings, :destroy, %{}, strategy: :atomic_batches, allow_stream_with: :full_read)
    conn = get(conn, ~p"/export")
    body = response(conn, 200)
    assert body =~ "[settings]"
    assert body =~ ~s(theme = "mocha")
  end
end
