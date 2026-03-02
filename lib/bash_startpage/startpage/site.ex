defmodule BashStartpage.Startpage.Site do
  use Ash.Resource,
    otp_app: :bash_startpage,
    domain: BashStartpage.Startpage,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "sites"
    repo BashStartpage.Repo
  end

  actions do
    defaults [:read, :destroy, create: [:name, :url, :shortcuts, :tags, :position], update: [:name, :url, :shortcuts, :tags, :position]]
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    attribute :url, :string do
      allow_nil? false
    end

    attribute :shortcuts, {:array, :string} do
      default []
    end

    attribute :tags, {:array, :string} do
      default []
    end

    attribute :position, :integer do
      default 0
    end

    timestamps()
  end
end
