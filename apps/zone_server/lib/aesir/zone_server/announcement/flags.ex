defmodule Aesir.ZoneServer.Announcement.Flags do
  @moduledoc """
  rAthena `bc_*` broadcast flag constants (`src/map/clif.hpp` `enum
  broadcast_flags`) and the runtime decoder that splits a resolved flag
  integer into packet-ready scope/color/source values.

  Single source of truth for the transpiler resolvers, the announce DSL ops,
  and the `@broadcast` GM command.
  """

  import Bitwise

  # NOTE: placeholder RGB uint32 values for the custom client; exact hex is a
  # client-contract detail to confirm with the Rust client, not an rAthena value.
  @blue_color 0x0099FF
  @woe_color 0xCC0000

  @values %{
    "bc_all" => 0x00,
    "bc_map" => 0x01,
    "bc_area" => 0x02,
    "bc_self" => 0x03,
    "bc_pc" => 0x00,
    "bc_npc" => 0x08,
    "bc_yellow" => 0x00,
    "bc_blue" => 0x10,
    "bc_woe" => 0x20
  }

  @scope_mask 0x07
  @source_mask 0x08
  @color_mask 0x30

  @scopes %{0x00 => :all, 0x01 => :map, 0x02 => :area, 0x03 => :self}

  @typedoc "Delivery scope decoded from a broadcast flag's low bits."
  @type scope :: :all | :map | :area | :self

  @doc """
  Resolves an rAthena `bc_*` constant name to its numeric value.

  Lookup is case-insensitive. Returns `:error` for an unknown name.
  """
  @spec value(String.t()) :: {:ok, non_neg_integer()} | :error
  def value(name) when is_binary(name), do: Map.fetch(@values, String.downcase(name))

  @doc """
  Decodes a resolved broadcast flag and explicit color argument into
  packet-ready scope, color, and source values.

  `scope` falls back to `:all` for unrecognized low bits. `color` uses
  `color_arg` verbatim when non-zero, else derives from the color bits in
  `flag`, else defaults to `0` (client default / yellow).
  """
  @spec decode(non_neg_integer(), non_neg_integer()) :: %{
          scope: :all | :map | :area | :self,
          color: non_neg_integer(),
          source: :pc | :npc
        }
  def decode(flag, color_arg) when is_integer(flag) and is_integer(color_arg) do
    %{
      scope: Map.get(@scopes, flag &&& @scope_mask, :all),
      color: color(flag, color_arg),
      source: source(flag)
    }
  end

  @doc """
  Maps a bare `bc_*` scope value to its scope atom, falling back to `default`.

  Unlike `decode/2` this does not mask off color/source bits: `npctalk` takes a
  plain scope argument and rAthena compares it whole (`BUILDIN_FUNC(npctalk)`'s
  switch), so a combined flag is not a scope and falls back — there to `:area`.
  """
  @spec scope(non_neg_integer(), scope()) :: scope()
  def scope(flag, default) when is_integer(flag), do: Map.get(@scopes, flag, default)

  defp source(flag) do
    if (flag &&& @source_mask) == @source_mask, do: :npc, else: :pc
  end

  defp color(_flag, color_arg) when color_arg != 0, do: color_arg

  defp color(flag, 0) do
    case flag &&& @color_mask do
      0x10 -> @blue_color
      0x20 -> @woe_color
      _ -> 0
    end
  end

  @doc """
  Maps a decoded scope to the announcement display style.
  """
  @spec style_for(:all | :map | :area | :self) :: :TOP | :CENTER | :LOCAL
  def style_for(:all), do: :TOP
  def style_for(:map), do: :CENTER
  def style_for(:area), do: :CENTER
  def style_for(:self), do: :LOCAL
end
