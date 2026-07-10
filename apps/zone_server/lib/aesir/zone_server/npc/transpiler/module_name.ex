defmodule Aesir.ZoneServer.Npc.Transpiler.ModuleName do
  @moduledoc """
  Derives module names, file slugs and output paths for transpiled NPC
  entries.

  Placed scripts follow the hand-written convention
  (`Content.Npc.<Map>.<Name>` under `content/npc/<map>/<slug>.ex`); floating
  scripts and global functions get their own namespaces. rAthena names are
  sanitized (the `#hidden` suffix and `::exported` prefix stripped for
  display, everything non-alphanumeric squashed for slugs); map names like
  `1@mcd` gain an `m` prefix to stay valid Elixir aliases.
  """

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

  @doc "Module name for an entry kind + map/name pair."
  @spec module(:script | :floating | :function, String.t() | nil, String.t()) :: String.t()
  def module(:script, map, slug), do: "#{@root}.#{camelize(map)}.#{camelize(slug)}"
  def module(:floating, _map, slug), do: "#{@root}.Floating.#{camelize(slug)}"
  def module(:function, _map, slug), do: "#{@root}.Functions.#{camelize(slug)}"

  @doc "Output path (relative to the zone_server app root) for an entry."
  @spec path(:script | :floating | :function, String.t() | nil, String.t()) :: String.t()
  def path(:script, map, slug),
    do: "lib/aesir/zone_server/content/npc/#{slug(map)}/#{slug}.ex"

  def path(:floating, _map, slug), do: "lib/aesir/zone_server/content/npc/floating/#{slug}.ex"
  def path(:function, _map, slug), do: "lib/aesir/zone_server/content/npc/functions/#{slug}.ex"

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
