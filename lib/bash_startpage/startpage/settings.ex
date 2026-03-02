defmodule BashStartpage.Startpage.Settings do
  use Ash.Resource,
    otp_app: :bash_startpage,
    domain: BashStartpage.Startpage,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "startpage_settings"
    repo BashStartpage.Repo
  end

  actions do
    defaults [:read, create: [:theme, :timezone, :offset], update: [:theme, :timezone, :offset]]

    read :get do
      get? true
      filter expr(id == ^arg(:id))
      argument :id, :uuid, allow_nil?: false
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :theme, :string do
      default "mocha"
      allow_nil? false
    end

    attribute :timezone, :string do
      default "UTC"
    end

    attribute :offset, :integer do
      default 0
      allow_nil? false
    end

    timestamps()
  end
end
