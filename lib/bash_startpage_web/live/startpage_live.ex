defmodule BashStartpageWeb.StartpageLive do
  use BashStartpageWeb, :live_view

  alias BashStartpage.Startpage.{Site, Settings}
  alias BashStartpage.Startpage.Commands

  @changelog [
    %{v: "6.4", f: "Manual UTC Offset via config.toml (Fixed persistent 1h offset)."},
    %{v: "6.3", f: "Manual Timezone override via [settings] config key."},
    %{v: "6.2", f: "Attempted OS TimeZone resolution fix for clock offset."},
    %{v: "6.1", f: "Hard-sync clock to system local time via locale array."},
    %{v: "6.0", f: "Switched to 24h dashboard clock for technical look."},
    %{v: "5.9", f: "Weather caching (15m) for zero-latency dashboard load."},
    %{v: "5.8", f: "Fixed :add/:del logic & expanded input field to 100% width."},
    %{v: "5.7", f: "Dashboard: Added real-time clock & IP-based weather fetch."},
    %{v: "5.6", f: "UX: Internal link launching (_self) & focused clickable input."},
    %{v: "5.5", f: "Arch: Static Build-Time Injection master config system."},
    %{v: "5.0", f: "IO: Switched to config.toml with settings/sites headers."},
    %{v: "4.5", f: "UI: Interactive URL tooltips on hover & mouse tracking."},
    %{v: "4.4", f: "Style: Removed URL text for 'Zen' look & refined tag spacing."},
    %{v: "4.2", f: "A11y: Contrast & legibility overhaul for Glassmorphism."},
    %{v: "4.1", f: "Visuals: Glassmorphism (Blur) & centered palette layout."},
    %{v: "4.0", f: "Theme: Catppuccin Mocha theme & palette-aware variables."},
    %{v: "3.3", f: "Compat: Firefox stacking context & popup rendering fixes."},
    %{v: "3.1", f: "CLI: Contextual command popups & Tab-to-complete logic."},
    %{v: "2.8", f: "Logic: Vim-style ':' prefix for administrative actions."},
    %{v: "2.6", f: "Search: Strict hierarchy (#tags, !keys, name/url)."},
    %{v: "2.2", f: "Assets: Favicon auto-fetching & multiple alias support."},
    %{v: "1.0", f: "Init: Svelte TOML Launcher core release."}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, sites} = Ash.read(Ash.Query.sort(Site, position: :asc))
    {:ok, settings} = Ash.read_one(Settings)

    settings = settings || %{theme: "mocha", timezone: "UTC", offset: 0}

    req_options = Application.get_env(:bash_startpage, :weather_req_options, [])

    socket =
      socket
      |> assign(:sites, sites)
      |> assign(:settings, settings)
      |> assign(:theme, settings.theme || "mocha")
      |> assign(:query, "")
      |> assign(:filtered_sites, sites)
      |> assign(:suggestions, [])
      |> assign(:selected_index, 0)
      |> assign(:show_help, false)
      |> assign(:show_changelog, false)
      |> assign(:editing_id, nil)
      |> assign(:adding, false)
      |> assign(:tooltip, %{visible: false, text: "", x: 0, y: 0})
      |> assign(:time, current_time(settings))
      |> assign_async(:weather, fn -> fetch_weather(req_options) end)

    if connected?(socket), do: schedule_tick()

    {:ok, socket}
  end

  @impl true
  def handle_info(:tick, socket) do
    schedule_tick()
    {:noreply, assign(socket, :time, current_time(socket.assigns.settings))}
  end

  @impl true
  def handle_event("query_changed", %{"query" => query}, socket) do
    sites = socket.assigns.sites
    filtered = Commands.filter_sites(sites, query)
    suggestions = Commands.suggestions(query)

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:filtered_sites, filtered)
     |> assign(:suggestions, suggestions)
     |> assign(:selected_index, 0)
     |> assign(:show_help, false)
     |> assign(:show_changelog, false)}
  end

  def handle_event("keydown", %{"key" => "ArrowUp"}, socket) do
    suggestions = socket.assigns.suggestions
    idx = socket.assigns.selected_index

    new_idx =
      if suggestions != [] do
        rem(idx - 1 + length(suggestions), length(suggestions))
      else
        idx
      end

    {:noreply, assign(socket, :selected_index, new_idx)}
  end

  def handle_event("keydown", %{"key" => "ArrowDown"}, socket) do
    suggestions = socket.assigns.suggestions
    idx = socket.assigns.selected_index

    new_idx =
      if suggestions != [] do
        rem(idx + 1, length(suggestions))
      else
        idx
      end

    {:noreply, assign(socket, :selected_index, new_idx)}
  end

  def handle_event("keydown", %{"key" => "Tab"}, socket) do
    suggestions = socket.assigns.suggestions
    query = socket.assigns.query
    idx = socket.assigns.selected_index

    new_query =
      if suggestions != [] do
        suggestion = Enum.at(suggestions, idx)
        parts = String.split(query, " ")

        if length(parts) == 1 do
          ":#{suggestion} "
        else
          [first | _] = parts
          "#{first} #{suggestion}"
        end
      else
        query
      end

    filtered = Commands.filter_sites(socket.assigns.sites, new_query)
    new_suggestions = Commands.suggestions(new_query)

    {:noreply,
     socket
     |> assign(:query, new_query)
     |> assign(:filtered_sites, filtered)
     |> assign(:suggestions, new_suggestions)}
  end

  def handle_event("keydown", %{"key" => "Enter"}, socket) do
    query = socket.assigns.query
    sites = socket.assigns.sites
    filtered = socket.assigns.filtered_sites
    socket = push_event(socket, "clear_input", %{})

    cond do
      String.starts_with?(query, ":") ->
        handle_command(query, socket)

      String.starts_with?(query, "!") ->
        key = query |> String.slice(1..-1//1) |> String.downcase()
        site = Enum.find(sites, fn s -> Enum.member?(s.shortcuts, key) end)

        if site do
          {:noreply,
           socket
           |> assign(:query, "")
           |> push_event("open_url", %{url: site.url})}
        else
          {:noreply, assign(socket, :query, "")}
        end

      filtered != [] ->
        first = hd(filtered)

        {:noreply,
         socket
         |> assign(:query, "")
         |> push_event("open_url", %{url: first.url})}

      true ->
        {:noreply, assign(socket, :query, "")}
    end
  end

  def handle_event("keydown", %{"key" => "Escape"}, socket) do
    {:noreply,
     socket
     |> push_event("clear_input", %{})
     |> assign(:query, "")
     |> assign(:filtered_sites, socket.assigns.sites)
     |> assign(:suggestions, [])
     |> assign(:show_help, false)
     |> assign(:show_changelog, false)}
  end

  def handle_event("keydown", _params, socket), do: {:noreply, socket}

  def handle_event("start_add", _params, socket) do
    {:noreply, assign(socket, :adding, true)}
  end

  def handle_event("cancel_add", _params, socket) do
    {:noreply, assign(socket, :adding, false)}
  end

  def handle_event("save_new", params, socket) do
    name = Map.get(params, "name", "") |> String.trim()
    url = Map.get(params, "url", "") |> String.trim()
    shortcut = Map.get(params, "shortcut", "") |> String.trim()
    tags_str = Map.get(params, "tags", "")

    if name == "" or url == "" do
      {:noreply, assign(socket, :adding, false)}
    else
      shortcuts = if shortcut != "", do: [shortcut], else: []
      tags = tags_str |> String.split(~r/\s+/) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
      url = if String.starts_with?(url, "http"), do: url, else: "https://#{url}"

      case Ash.create(Site, %{name: name, url: url, shortcuts: shortcuts, tags: tags}) do
        {:ok, _} ->
          {:ok, sites} = Ash.read(Ash.Query.sort(Site, position: :asc))
          filtered = Commands.filter_sites(sites, socket.assigns.query)

          {:noreply,
           socket
           |> assign(:adding, false)
           |> assign(:sites, sites)
           |> assign(:filtered_sites, filtered)}

        {:error, _} ->
          {:noreply, assign(socket, :adding, false)}
      end
    end
  end

  def handle_event("start_edit", %{"id" => id}, socket) do
    {:noreply, assign(socket, :editing_id, id)}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_id, nil)}
  end

  def handle_event("save_edit", %{"site_id" => id} = params, socket) do
    site = Enum.find(socket.assigns.sites, &(to_string(&1.id) == id))

    if site do
      name = Map.get(params, "name", site.name)
      url = Map.get(params, "url", site.url)
      shortcut = Map.get(params, "shortcut", "") |> String.trim()
      tags_str = Map.get(params, "tags", "")

      shortcuts = if shortcut != "", do: [shortcut], else: []
      tags = tags_str |> String.split(~r/\s+/) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
      url = if String.starts_with?(url, "http"), do: url, else: "https://#{url}"

      case Ash.update(site, %{name: name, url: url, shortcuts: shortcuts, tags: tags}) do
        {:ok, _} ->
          {:ok, sites} = Ash.read(Ash.Query.sort(Site, position: :asc))
          filtered = Commands.filter_sites(sites, socket.assigns.query)

          {:noreply,
           socket
           |> assign(:editing_id, nil)
           |> assign(:sites, sites)
           |> assign(:filtered_sites, filtered)}

        {:error, _} ->
          {:noreply, assign(socket, :editing_id, nil)}
      end
    else
      {:noreply, assign(socket, :editing_id, nil)}
    end
  end

  def handle_event("show_tooltip", %{"url" => url, "x" => x, "y" => y}, socket) do
    {:noreply, assign(socket, :tooltip, %{visible: true, text: url, x: x, y: y + 20})}
  end

  def handle_event("hide_tooltip", _params, socket) do
    {:noreply, assign(socket, :tooltip, %{visible: false, text: "", x: 0, y: 0})}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_help, false)
     |> assign(:show_changelog, false)}
  end

  defp handle_command(query, socket) do
    case Commands.process(query, socket.assigns.settings) do
      {:ok, %{action: :help}} ->
        {:noreply,
         socket
         |> assign(:query, "")
         |> assign(:show_help, true)
         |> assign(:show_changelog, false)}

      {:ok, %{action: :changelog}} ->
        {:noreply,
         socket
         |> assign(:query, "")
         |> assign(:show_help, false)
         |> assign(:show_changelog, true)}

      {:ok, %{action: :export}} ->
        {:noreply,
         socket
         |> assign(:query, "")
         |> push_navigate(to: ~p"/export")}

      {:ok, %{action: :theme, theme: theme}} ->
        {:noreply,
         socket
         |> assign(:query, "")
         |> assign(:theme, theme)}

      {:ok, %{action: :add, site: _site}} ->
        {:ok, sites} = Ash.read(Ash.Query.sort(Site, position: :asc))

        {:noreply,
         socket
         |> assign(:query, "")
         |> assign(:sites, sites)
         |> assign(:filtered_sites, sites)}

      {:ok, %{action: :del}} ->
        {:ok, sites} = Ash.read(Ash.Query.sort(Site, position: :asc))

        {:noreply,
         socket
         |> assign(:query, "")
         |> assign(:sites, sites)
         |> assign(:filtered_sites, sites)}

      {:ok, %{action: :tag}} ->
        {:ok, sites} = Ash.read(Ash.Query.sort(Site, position: :asc))

        {:noreply,
         socket
         |> assign(:query, "")
         |> assign(:sites, sites)
         |> assign(:filtered_sites, sites)}

      {:ok, %{action: :none}} ->
        {:noreply, assign(socket, :query, "")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:query, "")
         |> assign(:filtered_sites, socket.assigns.sites)}
    end
  end

  defp fetch_weather(req_options) do
    case Req.get("https://wttr.in/?format=j1", [receive_timeout: 5000, retry: false] ++ req_options) do
      {:ok, %{status: 200, body: body}} ->
        condition = body |> Map.get("current_condition", []) |> List.first()

        if condition do
          temp = Map.get(condition, "temp_C", "--")
          desc = condition |> Map.get("weatherDesc", [%{}]) |> List.first() |> Map.get("value", "Unknown")
          {:ok, %{weather: %{temp: "#{temp}°C", desc: desc}}}
        else
          {:ok, %{weather: %{temp: "--", desc: "Unknown"}}}
        end

      _ ->
        {:error, :unavailable}
    end
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, 1000)
  end

  defp current_time(settings) do
    offset = Map.get(settings, :offset) || 0
    now = DateTime.utc_now()
    adjusted = DateTime.add(now, offset * 3600, :second)

    hour = adjusted.hour |> Integer.to_string() |> String.pad_leading(2, "0")
    min = adjusted.minute |> Integer.to_string() |> String.pad_leading(2, "0")
    sec = adjusted.second |> Integer.to_string() |> String.pad_leading(2, "0")

    "#{hour}:#{min}:#{sec}"
  end

  defp favicon_url(url) do
    domain =
      case URI.parse(url) do
        %URI{host: host} when not is_nil(host) -> host
        _ -> url
      end

    "https://www.google.com/s2/favicons?domain=#{domain}&sz=32"
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :changelog, @changelog)
    assigns = assign(assigns, :favicon_url, &favicon_url/1)

    ~H"""
    <div
      class="sp-page"
      data-sp-theme={@theme}
      id="startpage"
    >
      <div class="w-full max-w-2xl px-4">
        <%!-- Main card --%>
        <div class="sp-card rounded-2xl p-6 shadow-2xl">
          <%!-- Header bar --%>
          <div class="mb-6 flex items-center justify-between border-b pb-4" style="border-color: var(--sp-card-border)">
            <div class="flex items-center gap-3">
              <div class="text-[10px] tracking-widest uppercase sp-text-muted">
                # Dashboard | {@theme}
              </div>
              <button
                phx-click="start_add"
                class="sp-text-accent text-xs font-bold leading-none opacity-60 hover:opacity-100 transition-opacity"
                title="Add site"
              >+</button>
            </div>
            <div class="flex gap-4 text-xs font-bold sp-text-accent">
              <.async_result :let={weather} assign={@weather}>
                <:loading>
                  <span class="inline-block size-3 animate-spin rounded-full border-2 border-current border-t-transparent" role="status" aria-label="Loading weather"></span>
                </:loading>
                <:failed>!!</:failed>
                {weather.temp}
              </.async_result>
              <span class="tabular-nums">{@time}</span>
            </div>
          </div>

          <%!-- Content area --%>
          <div class="sp-scrollbar mb-6 max-h-[50vh] space-y-1 overflow-y-auto pr-2">
            <%= if @show_help do %>
              <.help_content />
            <% else %>
              <%= if @show_changelog do %>
                <.changelog_content changelog={@changelog} />
              <% else %>
                <.site_list
                  sites={@filtered_sites}
                  favicon_url={@favicon_url}
                  editing_id={@editing_id}
                  adding={@adding}
                />
              <% end %>
            <% end %>
          </div>

          <%!-- Command input with suggestions above it --%>
          <div class="relative">
            <.suggestions_dropdown suggestions={@suggestions} selected_index={@selected_index} query={@query} />
            <.command_input query={@query} command_hint={command_hint(@query)} />
          </div>
        </div>
      </div>

      <%!-- Tooltip --%>
      <%= if @tooltip.visible do %>
        <div
          class="pointer-events-none fixed z-[100] rounded border px-3 py-1 text-[10px] text-white shadow-xl"
          style={"left: #{@tooltip.x}px; top: #{@tooltip.y}px; background: rgba(0,0,0,0.9); border-color: rgba(255,255,255,0.2); backdrop-filter: blur(4px);"}
        >
          {@tooltip.text}
        </div>
      <% end %>
    </div>
    """
  end

  defp suggestions_dropdown(assigns) do
    ~H"""
    <%= if @suggestions != [] do %>
      <div class="absolute bottom-full left-0 right-0 z-50 mb-1 rounded-xl border shadow-xl px-4"
           style="background: rgba(0,0,0,0.9); border-color: rgba(255,255,255,0.1); backdrop-filter: blur(20px);">
        <%= for {suggestion, i} <- Enum.with_index(@suggestions) do %>
          <div
            class={"px-3 py-2 text-sm cursor-pointer rounded-lg transition-colors " <> if i == @selected_index, do: "sp-text-accent font-bold", else: "sp-text-secondary opacity-70"}
          >
            {prefix(@query)}{suggestion}
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp help_content(assigns) do
    ~H"""
    <div class="space-y-3 p-2">
      <div class="border-b pb-1 text-xs font-bold sp-text-site-name" style="border-color: rgba(255,255,255,0.1)">
        HELP
      </div>
      <div class="grid grid-cols-[100px_1fr] gap-y-2 text-[11px]">
        <span class="font-bold sp-text-shortcut">:add</span>
        <span class="sp-text-muted">name url [shortcut]</span>
        <span class="sp-text-shortcut">:del</span>
        <span class="sp-text-muted">name_or_shortcut</span>
        <span class="sp-text-shortcut">:tag</span>
        <span class="sp-text-muted">name_or_shortcut tag1 [tag2 ...]</span>
        <span class="sp-text-shortcut">:theme</span>
        <span class="sp-text-muted">mocha / tokyo / matrix / light</span>
        <span class="sp-text-shortcut">:export</span>
        <span class="sp-text-muted">download config.toml</span>
        <span class="sp-text-shortcut">:help</span>
        <span class="sp-text-muted">show this help</span>
        <span class="sp-text-shortcut">:changelog</span>
        <span class="sp-text-muted">show version history</span>
      </div>
      <div class="mt-3 border-t pt-3 text-[10px] sp-text-muted" style="border-color: rgba(255,255,255,0.1)">
        <div class="grid grid-cols-[100px_1fr] gap-y-1">
          <span class="font-bold">!shortcut</span><span>open site directly</span>
          <span class="font-bold">#tag</span><span>filter by tag</span>
          <span class="font-bold">text</span><span>filter by name/url</span>
          <span class="font-bold">↑↓ arrows</span><span>navigate suggestions</span>
          <span class="font-bold">Tab</span><span>autocomplete command</span>
          <span class="font-bold">Enter</span><span>execute / open</span>
          <span class="font-bold">Escape</span><span>clear / close</span>
        </div>
      </div>
    </div>
    """
  end

  defp changelog_content(assigns) do
    ~H"""
    <div class="space-y-2 p-2">
      <div class="border-b pb-1 text-xs font-bold sp-text-site-name" style="border-color: rgba(255,255,255,0.1)">
        CHANGELOG
      </div>
      <%= for entry <- @changelog do %>
        <div class="flex gap-3 text-[11px]">
          <span class="sp-text-shortcut font-bold w-8 flex-shrink-0">v{entry.v}</span>
          <span class="sp-text-muted">{entry.f}</span>
        </div>
      <% end %>
    </div>
    """
  end

  defp site_list(assigns) do
    ~H"""
    <%= if @adding do %>
      <form
        phx-submit="save_new"
        phx-update="ignore"
        class="flex flex-col gap-2 rounded border p-2"
        style="border-color: var(--sp-card-border); background: rgba(255,255,255,0.03);"
        phx-hook="InlineEdit"
        data-cancel-event="cancel_add"
        id="new-site-form"
      >
        <div class="flex items-center gap-2">
          <span class="w-4 h-4 flex-shrink-0 opacity-30 text-xs flex items-center justify-center">?</span>
          <input
            type="text"
            name="name"
            class="flex-grow bg-transparent border-b text-sm font-semibold sp-text-site-name outline-none px-1"
            style="border-color: rgba(255,255,255,0.15);"
            placeholder="Name"
          />
          <input
            type="text"
            name="shortcut"
            class="w-24 bg-transparent border-b text-xs sp-text-shortcut outline-none px-1"
            style="border-color: rgba(255,255,255,0.15);"
            placeholder="shortcut"
          />
        </div>
        <div class="flex items-center gap-2">
          <span class="w-4 flex-shrink-0"></span>
          <input
            type="text"
            name="url"
            class="flex-grow bg-transparent border-b text-xs sp-text-muted outline-none px-1"
            style="border-color: rgba(255,255,255,0.15);"
            placeholder="URL"
          />
          <input
            type="text"
            name="tags"
            class="w-36 bg-transparent border-b text-xs sp-text-tag outline-none px-1"
            style="border-color: rgba(255,255,255,0.15);"
            placeholder="tags (space-separated)"
          />
          <div class="flex gap-1 flex-shrink-0 ml-1">
            <button type="submit" class="sp-text-accent text-xs font-bold px-2 py-0.5 rounded hover:opacity-70">✓</button>
            <button type="button" phx-click="cancel_add" class="sp-text-muted text-xs px-2 py-0.5 rounded hover:opacity-70">✗</button>
          </div>
        </div>
      </form>
    <% end %>
    <%= for site <- @sites do %>
      <%= if @editing_id == to_string(site.id) do %>
        <form
          phx-submit="save_edit"
          phx-update="ignore"
          class="flex flex-col gap-2 rounded border p-2"
          style="border-color: var(--sp-card-border); background: rgba(255,255,255,0.03);"
          phx-hook="InlineEdit"
          id={"edit-#{site.id}"}
        >
          <input type="hidden" name="site_id" value={site.id} />
          <div class="flex items-center gap-2">
            <img src={@favicon_url.(site.url)} alt="" class="w-4 h-4 rounded-sm opacity-80 flex-shrink-0" />
            <input
              type="text"
              name="name"
              value={site.name}
              class="flex-grow bg-transparent border-b text-sm font-semibold sp-text-site-name outline-none px-1"
              style="border-color: rgba(255,255,255,0.15);"
              placeholder="Name"
            />
            <input
              type="text"
              name="shortcut"
              value={if site.shortcuts != [], do: hd(site.shortcuts), else: ""}
              class="w-24 bg-transparent border-b text-xs sp-text-shortcut outline-none px-1"
              style="border-color: rgba(255,255,255,0.15);"
              placeholder="shortcut"
            />
          </div>
          <div class="flex items-center gap-2">
            <span class="w-4 flex-shrink-0"></span>
            <input
              type="text"
              name="url"
              value={site.url}
              class="flex-grow bg-transparent border-b text-xs sp-text-muted outline-none px-1"
              style="border-color: rgba(255,255,255,0.15);"
              placeholder="URL"
            />
            <input
              type="text"
              name="tags"
              value={Enum.join(site.tags, " ")}
              class="w-36 bg-transparent border-b text-xs sp-text-tag outline-none px-1"
              style="border-color: rgba(255,255,255,0.15);"
              placeholder="tags (space-separated)"
            />
            <div class="flex gap-1 flex-shrink-0 ml-1">
              <button type="submit" class="sp-text-accent text-xs font-bold px-2 py-0.5 rounded hover:opacity-70">✓</button>
              <button type="button" phx-click="cancel_edit" class="sp-text-muted text-xs px-2 py-0.5 rounded hover:opacity-70">✗</button>
            </div>
          </div>
        </form>
      <% else %>
        <div
          class="group flex w-full items-center gap-4 rounded border border-transparent p-2 transition-all hover:border-white/10 hover:bg-white/5"
          id={"site-#{site.id}"}
        >
          <span
            class="w-16 text-left text-xs font-bold sp-text-shortcut flex-shrink-0 cursor-pointer hover:opacity-70"
            phx-click="start_edit"
            phx-value-id={site.id}
          >
            {if site.shortcuts != [], do: "!#{hd(site.shortcuts)}", else: "–"}
          </span>
          <a
            href={site.url}
            target="_self"
            class="flex-shrink-0 no-underline"
            phx-hook="StartpageTooltip"
            data-tooltip-url={site.url}
            id={"favicon-#{site.id}"}
          >
            <img src={@favicon_url.(site.url)} alt="" class="w-4 h-4 rounded-sm opacity-80" />
          </a>
          <span
            class="flex-grow text-left text-sm font-semibold sp-text-site-name cursor-pointer hover:opacity-70"
            phx-click="start_edit"
            phx-value-id={site.id}
          >
            {site.name}
          </span>
          <div
            class="flex gap-2 text-right flex-shrink-0 cursor-pointer min-w-8"
            phx-click="start_edit"
            phx-value-id={site.id}
          >
            <%= for tag <- site.tags do %>
              <span class="rounded border px-2 py-0.5 text-[9px] font-bold sp-text-tag"
                    style="border-color: rgba(var(--sp-tag-color), 0.2)">
                #{tag}
              </span>
            <% end %>
          </div>
        </div>
      <% end %>
    <% end %>
    """
  end

  defp command_input(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <span class="sp-text-shortcut font-bold text-lg flex-shrink-0">&gt;</span>
      <div class="flex-grow min-w-0">
        <input
          type="text"
          id="startpage-input"
          name="query"
          value={@query}
          phx-hook="StartpageInput"
          autocomplete="off"
          spellcheck="false"
          class="w-full bg-transparent border-none outline-none text-sm sp-text-secondary placeholder-opacity-40"
          style="font-family: inherit; caret-color: var(--sp-text-primary);"
          placeholder="search or type :command..."
        />
        <%= if @command_hint do %>
          <div class="text-[10px] sp-text-muted opacity-40 pointer-events-none leading-tight">
            {@command_hint}
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp command_hint(query) do
    q = String.trim(query) |> String.downcase()

    cond do
      String.starts_with?(q, ":add") -> ":add name url [shortcut]"
      String.starts_with?(q, ":del") -> ":del name_or_shortcut"
      String.starts_with?(q, ":tag") -> ":tag name_or_shortcut tag1 [tag2 ...]"
      String.starts_with?(q, ":theme") -> ":theme mocha | tokyo | matrix | light"
      true -> nil
    end
  end

  defp prefix(query) do
    parts = String.split(query, " ")
    if length(parts) == 1, do: ":", else: hd(parts) <> " "
  end
end
