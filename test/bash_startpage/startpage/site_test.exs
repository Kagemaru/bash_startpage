defmodule BashStartpage.Startpage.SiteTest do
  use BashStartpage.DataCase

  alias BashStartpage.Startpage.Site

  describe "create" do
    test "creates a site with valid attributes" do
      assert {:ok, site} =
               Ash.create(Site, %{
                 name: "GitHub",
                 url: "https://github.com",
                 shortcuts: ["gh"],
                 tags: ["dev"],
                 position: 1
               })

      assert site.name == "GitHub"
      assert site.url == "https://github.com"
      assert site.shortcuts == ["gh"]
      assert site.tags == ["dev"]
      assert site.position == 1
    end

    test "creates a site with default shortcuts and tags" do
      {:ok, site} = Ash.create(Site, %{name: "Test", url: "https://test.com"})
      assert site.shortcuts == []
      assert site.tags == []
      assert site.position == 0
    end

    test "returns error when name is missing" do
      assert {:error, _} = Ash.create(Site, %{url: "https://example.com"})
    end

    test "returns error when url is missing" do
      assert {:error, _} = Ash.create(Site, %{name: "Test"})
    end
  end

  describe "read" do
    test "returns all sites" do
      {:ok, _} = Ash.create(Site, %{name: "Site1", url: "https://site1.com"})
      {:ok, _} = Ash.create(Site, %{name: "Site2", url: "https://site2.com"})

      {:ok, sites} = Ash.read(Site)
      assert length(sites) == 2
    end

    test "returns empty list when no sites exist" do
      {:ok, sites} = Ash.read(Site)
      assert sites == []
    end

    test "reads sites sorted by position" do
      {:ok, _} = Ash.create(Site, %{name: "Second", url: "https://b.com", position: 2})
      {:ok, _} = Ash.create(Site, %{name: "First", url: "https://a.com", position: 1})

      {:ok, sites} = Ash.read(Ash.Query.sort(Site, position: :asc))
      assert hd(sites).name == "First"
    end
  end

  describe "update" do
    test "updates site name" do
      {:ok, site} = Ash.create(Site, %{name: "OldName", url: "https://example.com"})
      {:ok, updated} = Ash.update(site, %{name: "NewName"})
      assert updated.name == "NewName"
    end

    test "updates shortcuts and tags" do
      {:ok, site} = Ash.create(Site, %{name: "Test", url: "https://test.com"})
      {:ok, updated} = Ash.update(site, %{shortcuts: ["t", "ts"], tags: ["work"]})
      assert updated.shortcuts == ["t", "ts"]
      assert updated.tags == ["work"]
    end
  end

  describe "destroy" do
    test "destroys a site" do
      {:ok, site} = Ash.create(Site, %{name: "ToDelete", url: "https://example.com"})
      assert :ok = Ash.destroy(site)

      {:ok, sites} = Ash.read(Site)
      assert sites == []
    end

    test "site no longer appears after destroy" do
      {:ok, s1} = Ash.create(Site, %{name: "Keep", url: "https://keep.com"})
      {:ok, s2} = Ash.create(Site, %{name: "Delete", url: "https://delete.com"})

      :ok = Ash.destroy(s2)

      {:ok, sites} = Ash.read(Site)
      assert length(sites) == 1
      assert hd(sites).id == s1.id
    end
  end
end
