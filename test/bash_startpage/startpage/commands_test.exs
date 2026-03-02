defmodule BashStartpage.Startpage.CommandsTest do
  use BashStartpage.DataCase

  alias BashStartpage.Startpage.Commands
  alias BashStartpage.Startpage.Site

  @settings %{theme: "mocha", timezone: "UTC", offset: 0}

  describe "suggestions/1" do
    test "returns empty list for non-command input" do
      assert Commands.suggestions("hello") == []
    end

    test "returns empty list for empty string" do
      assert Commands.suggestions("") == []
    end

    test "returns all commands for bare colon" do
      suggestions = Commands.suggestions(":")
      assert "add" in suggestions
      assert "del" in suggestions
      assert "theme" in suggestions
      assert "help" in suggestions
      assert "changelog" in suggestions
      assert "export" in suggestions
    end

    test "returns matching commands for partial input" do
      assert Commands.suggestions(":th") == ["theme"]
      assert Commands.suggestions(":he") == ["help"]
    end

    test "returns all theme options for ':theme '" do
      suggestions = Commands.suggestions(":theme ")
      assert "mocha" in suggestions
      assert "tokyo" in suggestions
      assert "matrix" in suggestions
      assert "light" in suggestions
    end

    test "returns matching theme options for partial theme input" do
      suggestions = Commands.suggestions(":theme m")
      assert "mocha" in suggestions
      assert "matrix" in suggestions
      refute "tokyo" in suggestions
    end
  end

  describe "filter_sites/2" do
    @sites [
      %{name: "GitHub", url: "https://github.com", shortcuts: ["gh"], tags: ["dev"]},
      %{name: "Reddit", url: "https://reddit.com", shortcuts: ["r"], tags: ["social"]},
      %{name: "Google", url: "https://google.com", shortcuts: [], tags: []}
    ]

    test "returns all sites for empty query" do
      assert Commands.filter_sites(@sites, "") == @sites
    end

    test "returns all sites for whitespace-only query" do
      assert Commands.filter_sites(@sites, "   ") == @sites
    end

    test "returns all sites for colon-prefixed command" do
      assert Commands.filter_sites(@sites, ":help") == @sites
    end

    test "filters by name (case-insensitive)" do
      result = Commands.filter_sites(@sites, "github")
      assert length(result) == 1
      assert hd(result).name == "GitHub"
    end

    test "filters by URL" do
      result = Commands.filter_sites(@sites, "reddit.com")
      assert length(result) == 1
      assert hd(result).name == "Reddit"
    end

    test "filters by tag with # prefix" do
      result = Commands.filter_sites(@sites, "#dev")
      assert length(result) == 1
      assert hd(result).name == "GitHub"
    end

    test "filters by shortcut with ! prefix" do
      result = Commands.filter_sites(@sites, "!gh")
      assert length(result) == 1
      assert hd(result).name == "GitHub"
    end

    test "returns empty list when no sites match" do
      assert Commands.filter_sites(@sites, "nonexistent") == []
    end

    test "filters with multiple terms (AND logic)" do
      result = Commands.filter_sites(@sites, "github dev")
      assert length(result) == 0

      result2 = Commands.filter_sites(@sites, "github #dev")
      assert length(result2) == 1
    end
  end

  describe "process/2" do
    test "returns :help action for :help command" do
      assert {:ok, %{action: :help}} = Commands.process(":help", @settings)
    end

    test "returns :changelog action for :changelog command" do
      assert {:ok, %{action: :changelog}} = Commands.process(":changelog", @settings)
    end

    test "returns :export action for :export command" do
      assert {:ok, %{action: :export}} = Commands.process(":export", @settings)
    end

    test "returns :none for non-command input" do
      assert {:ok, %{action: :none}} = Commands.process("hello", @settings)
    end

    test "returns :none for unknown command" do
      assert {:ok, %{action: :none}} = Commands.process(":unknown", @settings)
    end

    test ":add creates a site and returns it" do
      assert {:ok, %{action: :add, site: site}} =
               Commands.process(":add MyBlog myblog.com", @settings)

      assert site.name == "MyBlog"
      assert site.url == "https://myblog.com"
    end

    test ":add prepends https:// when URL has no scheme" do
      {:ok, %{action: :add, site: site}} = Commands.process(":add Blog blog.com", @settings)
      assert site.url == "https://blog.com"
    end

    test ":add preserves https:// URL as-is" do
      {:ok, %{action: :add, site: site}} =
        Commands.process(":add Blog https://blog.com", @settings)

      assert site.url == "https://blog.com"
    end

    test ":add returns error when called without name and url" do
      assert {:error, _} = Commands.process(":add", @settings)
    end

    test ":del deletes a site by name" do
      {:ok, _} = Ash.create(Site, %{name: "ToDelete", url: "https://delete.me"})
      assert {:ok, %{action: :del}} = Commands.process(":del ToDelete", @settings)
    end

    test ":del returns error when site not found" do
      assert {:error, _} = Commands.process(":del nonexistent", @settings)
    end

    test ":del returns error when called without identifier" do
      assert {:error, _} = Commands.process(":del", @settings)
    end

    test ":theme returns error for invalid theme name" do
      assert {:error, _} = Commands.process(":theme invalid", @settings)
    end

    test ":theme returns error when called without theme name" do
      assert {:error, _} = Commands.process(":theme", @settings)
    end
  end

  describe "to_toml/2" do
    test "generates [settings] section with theme, timezone, and offset" do
      settings = %{theme: "mocha", timezone: "UTC", offset: 0}
      toml = Commands.to_toml([], settings)
      assert toml =~ "[settings]"
      assert toml =~ ~s(theme = "mocha")
      assert toml =~ ~s(timezone = "UTC")
      assert toml =~ "offset = 0"
    end

    test "generates [[sites]] entry for each site" do
      settings = %{theme: "mocha", timezone: "UTC", offset: 0}

      sites = [
        %{name: "GitHub", url: "https://github.com", shortcuts: ["gh"], tags: ["dev"]},
        %{name: "Reddit", url: "https://reddit.com", shortcuts: [], tags: []}
      ]

      toml = Commands.to_toml(sites, settings)
      assert toml =~ "[[sites]]"
      assert toml =~ ~s(name = "GitHub")
      assert toml =~ ~s(url = "https://github.com")
      assert toml =~ ~s(name = "Reddit")
    end

    test "generates no [[sites]] section when sites list is empty" do
      settings = %{theme: "mocha", timezone: "UTC", offset: 0}
      toml = Commands.to_toml([], settings)
      refute toml =~ "[[sites]]"
    end

    test "encodes shortcuts and tags as TOML arrays" do
      settings = %{theme: "mocha", timezone: "UTC", offset: 0}
      sites = [%{name: "X", url: "https://x.com", shortcuts: ["x", "tw"], tags: ["social"]}]
      toml = Commands.to_toml(sites, settings)
      assert toml =~ ~s(shortcuts = ["x", "tw"])
      assert toml =~ ~s(tags = ["social"])
    end
  end
end
