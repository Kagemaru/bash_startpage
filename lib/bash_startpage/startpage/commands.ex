defmodule BashStartpage.Startpage.Commands do
  @moduledoc "Processes commands entered in the startpage input."

  alias BashStartpage.Startpage.{Site, Settings}

  @available_commands ["add", "del", "tag", "theme", "export", "help", "changelog"]
  @theme_options ["mocha", "tokyo", "matrix", "light"]

  def available_commands, do: @available_commands
  def theme_options, do: @theme_options

  @doc """
  Returns matching command suggestions for the current query.
  """
  def suggestions(query) do
    q = String.downcase(query)

    cond do
      not String.starts_with?(q, ":") ->
        []

      true ->
        parts = q |> String.slice(1..-1//1) |> String.split(" ")

        cond do
          length(parts) == 1 ->
            Enum.filter(@available_commands, &String.starts_with?(&1, hd(parts)))

          hd(parts) == "theme" and length(parts) == 2 ->
            Enum.filter(@theme_options, &String.starts_with?(&1, Enum.at(parts, 1)))

          true ->
            []
        end
    end
  end

  @doc """
  Filters sites based on the query string.
  """
  def filter_sites(sites, query) do
    q = String.downcase(String.trim(query))

    if q == "" or String.starts_with?(q, ":") do
      sites
    else
      terms = String.split(q, ~r/\s+/)

      Enum.filter(sites, fn site ->
        Enum.all?(terms, fn term ->
          cond do
            String.starts_with?(term, "#") ->
              tag = String.slice(term, 1..-1//1)
              Enum.any?(site.tags, &(String.downcase(&1) |> String.contains?(tag)))

            String.starts_with?(term, "!") ->
              shortcut = String.slice(term, 1..-1//1)
              Enum.any?(site.shortcuts, &(String.downcase(&1) |> String.contains?(shortcut)))

            true ->
              String.contains?(String.downcase(site.name), term) or
                String.contains?(String.downcase(site.url), term)
          end
        end)
      end)
    end
  end

  @doc """
  Processes a command and returns `{:ok, result}` or `{:error, reason}`.

  Result is a map with keys:
  - `:action` - one of :add, :del, :theme, :export, :help, :changelog
  - `:theme` - the new theme (if changed)
  - `:site` - the created site (if :add)
  """
  def process(input, settings) do
    trimmed = String.trim(input)

    if String.starts_with?(trimmed, ":") do
      parts = trimmed |> String.slice(1..-1//1) |> String.trim() |> split_parts()
      cmd = parts |> hd() |> String.downcase()
      execute_command(cmd, parts, settings)
    else
      {:ok, %{action: :none}}
    end
  end

  defp split_parts(input) do
    ~r/"[^"]*"|\S+/
    |> Regex.scan(input)
    |> List.flatten()
    |> Enum.map(&String.trim(&1, "\""))
  end

  defp execute_command("help", _parts, _settings), do: {:ok, %{action: :help}}
  defp execute_command("changelog", _parts, _settings), do: {:ok, %{action: :changelog}}
  defp execute_command("export", _parts, _settings), do: {:ok, %{action: :export}}

  defp execute_command("theme", [_, theme | _], _settings)
       when theme in @theme_options do
    case Ash.read_one(Settings) do
      {:ok, current_settings} when not is_nil(current_settings) ->
        case Ash.update(current_settings, %{theme: theme}) do
          {:ok, updated} -> {:ok, %{action: :theme, theme: updated.theme}}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:ok, %{action: :theme, theme: theme}}
    end
  end

  defp execute_command("theme", _, _settings), do: {:error, "Usage: :theme mocha|tokyo|matrix|light"}

  defp execute_command("add", [_, name, url | rest], _settings) when name != "" do
    url = if String.starts_with?(url, "http"), do: url, else: "https://#{url}"
    shortcuts = if rest != [], do: [hd(rest)], else: []

    case Ash.create(Site, %{name: name, url: url, shortcuts: shortcuts, tags: []}) do
      {:ok, site} -> {:ok, %{action: :add, site: site}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_command("add", _, _settings), do: {:error, "Usage: :add name url [shortcut]"}

  defp execute_command("del", [_, identifier | _], _settings) when identifier != "" do
    id = identifier |> String.downcase() |> String.trim_leading("!")
    case Ash.read(Site) do
      {:ok, sites} ->
        target = Enum.find(sites, fn s ->
          String.downcase(s.name) == id or Enum.member?(s.shortcuts, id)
        end)

        if target do
          case Ash.destroy(target) do
            :ok -> {:ok, %{action: :del, id: target.id}}
            {:error, reason} -> {:error, reason}
          end
        else
          {:error, "Site not found: #{identifier}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_command("del", _, _settings), do: {:error, "Usage: :del name_or_shortcut"}

  defp execute_command("tag", [_, identifier | tags], _settings)
       when identifier != "" and tags != [] do
    id = identifier |> String.downcase() |> String.trim_leading("!")

    case Ash.read(Site) do
      {:ok, sites} ->
        target = Enum.find(sites, fn s ->
          String.downcase(s.name) == id or Enum.member?(s.shortcuts, id)
        end)

        if target do
          new_tags = Enum.uniq(target.tags ++ tags)

          case Ash.update(target, %{tags: new_tags}) do
            {:ok, updated} -> {:ok, %{action: :tag, site: updated}}
            {:error, reason} -> {:error, reason}
          end
        else
          {:error, "Site not found: #{identifier}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_command("tag", _, _settings),
    do: {:error, "Usage: :tag name_or_shortcut tag1 [tag2 ...]"}

  defp execute_command(_cmd, _parts, _settings), do: {:ok, %{action: :none}}

  @doc """
  Generates a TOML string from sites and settings.
  """
  def to_toml(sites, settings) do
    theme = settings.theme || "mocha"
    timezone = settings.timezone || "UTC"
    offset = settings.offset || 0

    settings_section = """
    [settings]
    theme = "#{theme}"
    timezone = "#{timezone}"
    offset = #{offset}
    """

    sites_section =
      Enum.map_join(sites, "\n", fn site ->
        shortcuts = Enum.map_join(site.shortcuts, ", ", &~s("#{&1}"))
        tags = Enum.map_join(site.tags, ", ", &~s("#{&1}"))

        """
        [[sites]]
        name = "#{site.name}"
        url = "#{site.url}"
        shortcuts = [#{shortcuts}]
        tags = [#{tags}]
        """
      end)

    settings_section <> "\n" <> sites_section
  end
end
