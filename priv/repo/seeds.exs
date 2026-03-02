# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Seeds data from the original config.toml into the database.
# This script is idempotent: it only inserts data if none exists.

alias BashStartpage.Startpage.{Site, Settings}

# Seed settings only if none exist
case Ash.read(Settings) do
  {:ok, []} ->
    Ash.create!(Settings, %{
      theme: "mocha",
      timezone: "Europe/Zurich",
      offset: 1
    })

  _ ->
    :ok
end

# Seed sites only if none exist
case Ash.read(Site) do
  {:ok, []} ->
    sites = [
      %{
        name: "STZH Dev",
        url: "https://mitwirken.pitc-decidim-stzh-dev.ocp.cloudscale.puzzle.ch",
        shortcuts: ["stzh-dev"],
        tags: ["decidim", "zürich", "dev"],
        position: 0
      },
      %{
        name: "STZH Int",
        url: "https://mitwirken.integ.stadt-zuerich.ch",
        shortcuts: ["stzh-int"],
        tags: ["decidim", "zürich", "int"],
        position: 1
      },
      %{
        name: "STZH Prod",
        url: "https://mitwirken.integ.stadt-zuerich.ch",
        shortcuts: ["stzh-prod"],
        tags: ["decidim", "zürich", "prod"],
        position: 2
      }
    ]

    Enum.each(sites, fn attrs ->
      Ash.create!(Site, attrs)
    end)

  _ ->
    :ok
end
