defmodule BashStartpage.Startpage.SettingsTest do
  use BashStartpage.DataCase

  alias BashStartpage.Startpage.Settings

  describe "create" do
    test "creates settings with default values" do
      assert {:ok, settings} = Ash.create(Settings, %{})
      assert settings.theme == "mocha"
      assert settings.timezone == "UTC"
      assert settings.offset == 0
    end

    test "creates settings with custom theme" do
      assert {:ok, settings} = Ash.create(Settings, %{theme: "tokyo"})
      assert settings.theme == "tokyo"
    end

    test "creates settings with custom timezone and offset" do
      assert {:ok, settings} = Ash.create(Settings, %{timezone: "Europe/Berlin", offset: 1})
      assert settings.timezone == "Europe/Berlin"
      assert settings.offset == 1
    end
  end

  describe "read" do
    test "returns nil when no settings exist" do
      assert {:ok, nil} = Ash.read_one(Settings)
    end

    test "returns settings record when present" do
      {:ok, _} = Ash.create(Settings, %{theme: "matrix"})
      assert {:ok, settings} = Ash.read_one(Settings)
      assert settings.theme == "matrix"
    end
  end

  describe "update" do
    test "updates the theme" do
      {:ok, settings} = Ash.create(Settings, %{theme: "mocha"})
      {:ok, updated} = Ash.update(settings, %{theme: "tokyo"})
      assert updated.theme == "tokyo"
    end

    test "updates timezone and offset" do
      {:ok, settings} = Ash.create(Settings, %{})
      {:ok, updated} = Ash.update(settings, %{timezone: "America/New_York", offset: -5})
      assert updated.timezone == "America/New_York"
      assert updated.offset == -5
    end
  end
end
