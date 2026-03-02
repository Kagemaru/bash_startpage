defmodule BashStartpageWeb.StartpageLiveTest do
  use BashStartpageWeb.ConnCase
  import Phoenix.LiveViewTest

  alias BashStartpage.Startpage.{Site, Settings}

  setup do
    {:ok, _} = Ash.create(Settings, %{theme: "mocha"})

    {:ok, _} =
      Ash.create(Site, %{
        name: "GitHub",
        url: "https://github.com",
        shortcuts: ["gh"],
        tags: ["dev"],
        position: 1
      })

    {:ok, _} =
      Ash.create(Site, %{
        name: "Reddit",
        url: "https://reddit.com",
        shortcuts: ["r"],
        tags: ["social"],
        position: 2
      })

    :ok
  end

  test "mounts and renders the startpage with sites", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "search or type :command..."
    assert html =~ "GitHub"
    assert html =~ "Reddit"
  end

  test "renders with mocha theme from settings", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ ~s(data-sp-theme="mocha")
  end

  test "renders the command input prompt", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")
    assert html =~ "startpage-input"
  end

  test "filtering by name shows matching sites", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    html = render_hook(view, "query_changed", %{query: "github"})
    assert html =~ "GitHub"
    refute html =~ "Reddit"
  end

  test "filtering by URL shows matching sites", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    html = render_hook(view, "query_changed", %{query: "reddit.com"})
    assert html =~ "Reddit"
    refute html =~ "GitHub"
  end

  test "empty query shows all sites", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    render_hook(view, "query_changed", %{query: "github"})
    html = render_hook(view, "query_changed", %{query: ""})
    assert html =~ "GitHub"
    assert html =~ "Reddit"
  end

  test "escape clears query and shows all sites", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    render_hook(view, "query_changed", %{query: "github"})
    html = render_hook(view, "keydown", %{key: "Escape"})
    assert html =~ "GitHub"
    assert html =~ "Reddit"
  end

  test ":help command shows help content", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    render_hook(view, "query_changed", %{query: ":help"})
    html = render_hook(view, "keydown", %{key: "Enter"})
    assert html =~ "HELP"
    assert html =~ ":add"
    assert html =~ ":del"
    assert html =~ ":theme"
  end

  test ":changelog command shows changelog content", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    render_hook(view, "query_changed", %{query: ":changelog"})
    html = render_hook(view, "keydown", %{key: "Enter"})
    assert html =~ "CHANGELOG"
    assert html =~ "v6"
  end

  test ":theme command changes the theme attribute", %{conn: conn} do
    {:ok, view, html} = live(conn, "/")
    assert html =~ ~s(data-sp-theme="mocha")
    render_hook(view, "query_changed", %{query: ":theme tokyo"})
    html = render_hook(view, "keydown", %{key: "Enter"})
    assert html =~ ~s(data-sp-theme="tokyo")
  end

  test "suggestions dropdown appears for colon prefix", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    html = render_hook(view, "query_changed", %{query: ":"})
    assert html =~ "add"
    assert html =~ "help"
    assert html =~ "changelog"
  end

  test "tab autocompletes the selected suggestion", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    render_hook(view, "query_changed", %{query: ":he"})
    html = render_hook(view, "keydown", %{key: "Tab"})
    assert html =~ "help"
  end

  test "arrow down moves suggestion selection", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    render_hook(view, "query_changed", %{query: ":"})
    html = render_hook(view, "keydown", %{key: "ArrowDown"})
    assert html =~ "font-bold"
  end

  test "tooltip becomes visible on show_tooltip event", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    html = render_hook(view, "show_tooltip", %{url: "https://github.com", x: 100, y: 200})
    assert html =~ "https://github.com"
    assert html =~ "pointer-events-none"
  end

  test "tooltip hides on hide_tooltip event", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    render_hook(view, "show_tooltip", %{url: "https://github.com", x: 100, y: 200})
    html = render_hook(view, "hide_tooltip", %{})
    refute html =~ "pointer-events-none"
  end

  test ":add command creates and displays new site", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    render_hook(view, "query_changed", %{query: ":add NewSite newsite.com"})
    html = render_hook(view, "keydown", %{key: "Enter"})
    assert html =~ "NewSite"
  end

  test ":del command removes a site from the list", %{conn: conn} do
    {:ok, view, html} = live(conn, "/")
    assert html =~ "GitHub"
    render_hook(view, "query_changed", %{query: ":del GitHub"})
    html = render_hook(view, "keydown", %{key: "Enter"})
    refute html =~ "GitHub"
  end

  test "close_modal event hides help content", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    render_hook(view, "query_changed", %{query: ":help"})
    render_hook(view, "keydown", %{key: "Enter"})
    html = render_hook(view, "close_modal", %{})
    refute html =~ "HELP"
  end
end
