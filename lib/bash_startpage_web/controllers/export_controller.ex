defmodule BashStartpageWeb.ExportController do
  use BashStartpageWeb, :controller

  alias BashStartpage.Startpage.{Site, Settings}
  alias BashStartpage.Startpage.Commands

  def download(conn, _params) do
    {:ok, sites} = Ash.read(Ash.Query.sort(Site, position: :asc))
    {:ok, settings} = Ash.read_one(Settings)
    settings = settings || %{theme: "mocha", timezone: "UTC", offset: 0}

    toml = Commands.to_toml(sites, settings)

    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("content-disposition", ~s(attachment; filename="config.toml"))
    |> send_resp(200, toml)
  end
end
