defmodule Aesir.ZoneServer.Npc.Transpiler.ModuleName do
  @moduledoc """
  Derives module names, file slugs and output paths for transpiled NPC
  entries.

  Placed scripts mirror the rAthena source path — directory plus file basename
  (`Content.Npc.<Dir…>.<File>.<Name>` under `content/npc/<dir>/<file>/<slug>.ex`),
  so every NPC in one source file shares a folder and module parent; floating
  scripts and global functions keep their own namespaces. rAthena names are
  sanitized (the `#hidden` suffix and `::exported` prefix stripped for display,
  everything non-alphanumeric squashed for slugs); directory/map names like
  `1-1` or `1@mcd` gain an `M` prefix to stay valid Elixir aliases.
  """

  alias Aesir.ZoneServer.Npc.ContentScope

  @root "Aesir.ZoneServer.Content.Npc"

  @doc "The player-visible display name: everything before the `#` suffix."
  @spec display_name(String.t()) :: String.t()
  def display_name(name) do
    name
    |> String.trim_leading(":")
    |> String.split("#")
    |> hd()
  end

  @doc """
  The `::`-suffixed export/reference name (used for `donpcevent`-style
  targeting), or `nil` when absent. A name that itself starts with `::` has
  no separate export name (the whole thing is already an internal reference,
  handled by `display_name/1`'s leading-colon trim).
  """
  @spec exname(String.t()) :: String.t() | nil
  def exname(name) do
    case String.split(name, "::", parts: 2) do
      [prefix, suffix] when prefix != "" -> suffix
      _ -> nil
    end
  end

  @doc """
  The name a slug is derived from. A leading `#` marks an rAthena invisible NPC rather
  than a display-name suffix, so `#Gate_manager_main` slugs as `gate_manager_main`; a `#`
  after the name still separates the display name from its unique suffix.
  """
  @spec script_name(String.t()) :: String.t()
  def script_name(name) do
    # A few reference rows indent the name (` #paypuzz1`) or prefix it with a marker before the
    # `#` (`¡¡#crypt`), so the first segment that actually has an alphanumeric character wins.
    name
    |> String.trim()
    |> String.trim_leading(":")
    |> String.trim_leading("#")
    |> String.split("#")
    |> Enum.find("", &String.match?(&1, ~r/[A-Za-z0-9]/))
  end

  @doc "A filesystem/function-safe slug for an NPC or map name."
  @spec slug(String.t()) :: String.t()
  def slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
    |> case do
      "" -> "npc"
      slug -> slug
    end
  end

  @doc "Module name for an entry kind + entry/name pair."
  @spec module(:script | :floating | :function, map() | nil, String.t(), ContentScope.t()) ::
          String.t()
  def module(kind, entry, slug, scope \\ :shared)

  def module(:script, entry, slug, _scope),
    do: "#{@root}.#{namespace(entry)}.#{camelize(slug)}"

  def module(:floating, entry, slug, scope),
    do: "#{module_root(scope)}.Floating.#{namespace(entry, scope)}.#{camelize(slug)}"

  def module(:function, _entry, slug, scope),
    do: "#{module_root(scope)}.Functions.#{camelize(slug)}"

  @doc "Output path (relative to the zone_server app root) for an entry."
  @spec path(:script | :floating | :function, map() | nil, String.t(), ContentScope.t()) ::
          String.t()
  def path(kind, entry, slug, scope \\ :shared)

  def path(:script, entry, slug, _scope),
    do: "lib/aesir/zone_server/content/npc/#{dir_slug(entry)}/#{slug}.ex"

  def path(:floating, entry, slug, scope),
    do: "#{output_root(scope)}/floating/#{dir_slug(entry, scope)}/#{slug}.ex"

  def path(:function, _entry, slug, scope), do: "#{output_root(scope)}/functions/#{slug}.ex"

  @doc """
  The slugged output folder for a placed script: its rAthena source directory
  plus file basename (e.g. `cities/morocc.txt` → `cities/morocc`).
  """
  @spec dir_slug(map(), ContentScope.t() | nil) :: String.t()
  def dir_slug(entry, scope \\ nil), do: entry.file |> dir_segments(scope) |> Enum.join("/")

  # A floating body's output root already carries the scope directory (`content/npc/re`, ...), so
  # the source path it mirrors drops that leading segment; a placed script keeps it, matching the
  # `Re`/`PreRe` module roots.
  defp namespace(entry, scope \\ nil) do
    dir_slug(entry, scope) |> String.split("/") |> Enum.map_join(".", &camelize/1)
  end

  defp module_root(:shared), do: @root
  defp module_root(:renewal), do: "#{@root}.Re"
  defp module_root(:pre_renewal), do: "#{@root}.PreRe"

  defp output_root(:shared), do: "lib/aesir/zone_server/content/npc"
  defp output_root(:renewal), do: "lib/aesir/zone_server/content/npc/re"
  defp output_root(:pre_renewal), do: "lib/aesir/zone_server/content/npc/pre_re"

  defp dir_segments(file, scope) do
    dirs = file |> Path.dirname() |> Path.split() |> Enum.reject(&(&1 in [".", "", "/"]))

    (dirs ++ [Path.basename(file, Path.extname(file))])
    |> drop_scope_dir(scope)
    |> Enum.map(&slug/1)
  end

  defp drop_scope_dir([dir | rest], scope) when not is_nil(scope) do
    if dir == scope_dir(scope), do: rest, else: [dir | rest]
  end

  defp drop_scope_dir(segments, _scope), do: segments

  defp scope_dir(:renewal), do: "re"
  defp scope_dir(:pre_renewal), do: "pre-re"
  defp scope_dir(_scope), do: nil

  @doc "Conflict-namespaced variant of a module name and path."
  @spec conflict(String.t(), String.t()) :: {String.t(), String.t()}
  def conflict(module, path) do
    {String.replace(module, "#{@root}.", "#{@root}.Conflicts."),
     String.replace(path, "content/npc/", "content/npc/_conflicts/")}
  end

  defp camelize(name) do
    name
    |> slug()
    |> String.split("_")
    |> Enum.map_join(&String.capitalize/1)
    |> ensure_alias()
  end

  defp ensure_alias(<<c, _::binary>> = name) when c in ?A..?Z, do: name
  defp ensure_alias(name), do: "M" <> name
end
