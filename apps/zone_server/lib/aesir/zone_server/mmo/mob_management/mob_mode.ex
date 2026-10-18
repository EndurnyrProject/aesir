defmodule Aesir.ZoneServer.Mmo.MobManagement.MobMode do
  @moduledoc """
  Decodes rAthena's `Ai` value into `e_mode` behavior atoms.

  Each `Ai` value (1..26) indexes a `MONSTER_TYPE_<n>` constant whose integer
  value is a bitmask over `e_mode` (rAthena `src/common/mmo.hpp`). This module
  holds the `MONSTER_TYPE_<n>` value table (`src/map/mob.hpp`) and the
  bit -> atom table, and exposes `from_ai_type/1` to turn an `Ai` value into the
  set of mode atoms it implies.

  A few `Ai` values are string names rather than numbers (`Abr_Passive`,
  `Abr_Offensive`); `from_ai/1` accepts the raw `Ai` field (integer, numeric
  string, or known name) and normalizes it.

  Types 14-16, 18 and 22-23 are unused in the renewal DB; decoding fails loudly
  on them (and on anything else unmapped) so drift from rAthena surfaces at
  import time. `Ai` value `0` / a missing `Ai` yields no modes.
  """

  import Bitwise

  @monster_types %{
    1 => 0x81,
    2 => 0x83,
    3 => 0x1089,
    4 => 0x3885,
    5 => 0x2085,
    6 => 0x0,
    7 => 0x108B,
    8 => 0x7085,
    9 => 0x3095,
    10 => 0x84,
    11 => 0x84,
    12 => 0x2085,
    13 => 0x308D,
    17 => 0x91,
    19 => 0x3095,
    20 => 0x3295,
    21 => 0x3695,
    24 => 0xA1,
    25 => 0x1,
    26 => 0xB695,
    27 => 0x8084
  }

  @special_types %{
    "abr_passive" => 0x21,
    "abr_offensive" => 0xA5
  }

  @mode_bits [
    {0x0000001, :can_move},
    {0x0000002, :looter},
    {0x0000004, :aggressive},
    {0x0000008, :assist},
    {0x0000010, :cast_sensor_idle},
    {0x0000020, :no_random_walk},
    {0x0000040, :no_cast},
    {0x0000080, :can_attack},
    {0x0000200, :cast_sensor_chase},
    {0x0000400, :change_chase},
    {0x0000800, :angry},
    {0x0001000, :change_target_melee},
    {0x0002000, :change_target_chase},
    {0x0004000, :target_weak},
    {0x0008000, :random_target},
    {0x0010000, :ignore_melee},
    {0x0020000, :ignore_magic},
    {0x0040000, :ignore_ranged},
    {0x0080000, :mvp},
    {0x0100000, :ignore_misc},
    {0x0200000, :knockback_immune},
    {0x0400000, :teleport_block},
    {0x1000000, :fixed_item_drop},
    {0x2000000, :detector},
    {0x4000000, :status_immune},
    {0x8000000, :skill_immune}
  ]

  @doc """
  Decodes a raw `Ai` field into its mode atoms, in ascending bit order.

  Accepts an integer, a numeric string (`"04"`), a known special name
  (`"Abr_Offensive"`, case-insensitive), or `nil`/`0` (no modes). Raises
  `ArgumentError` on an unknown name or unused/unknown numeric type.
  """
  @spec from_ai(integer() | String.t() | nil) :: [atom()]
  def from_ai(nil), do: []
  def from_ai(value) when is_integer(value), do: from_ai_type(value)

  def from_ai(value) when is_binary(value) do
    key = String.downcase(value)

    case Map.fetch(@special_types, key) do
      {:ok, bitmask} ->
        decode(bitmask)

      :error ->
        case Integer.parse(value) do
          {n, _} -> from_ai_type(n)
          :error -> raise ArgumentError, "unknown mob Ai value: #{inspect(value)}"
        end
    end
  end

  @doc """
  Decodes a numeric `Ai` value into its mode atoms, in ascending bit order.

  Returns `[]` for `Ai` value `0` (no Ai). Raises `ArgumentError` for any
  unused or unknown `Ai` value.
  """
  @spec from_ai_type(integer()) :: [atom()]
  def from_ai_type(0), do: []

  def from_ai_type(ai_type) when is_integer(ai_type) do
    case Map.fetch(@monster_types, ai_type) do
      {:ok, bitmask} -> decode(bitmask)
      :error -> raise ArgumentError, "unused or unknown mob ai_type: #{ai_type}"
    end
  end

  @doc "Applies explicit boolean database overrides to a decoded mode set."
  @spec apply_overrides([atom()], map()) :: [atom()]
  def apply_overrides(modes, overrides) when is_map(overrides) do
    overrides
    |> Enum.reduce(mask(modes), fn {name, active}, current ->
      bit = database_mode_bit!(name)

      unless is_boolean(active),
        do: raise(ArgumentError, "invalid mode value #{inspect({name, active})}")

      if active, do: current ||| bit, else: current &&& bnot(bit)
    end)
    |> from_mask()
  end

  defp database_mode_bit!(name) when is_binary(name) do
    normalized = String.downcase(name)

    case Enum.find(@mode_bits, fn {_bit, mode} ->
           mode |> Atom.to_string() |> String.replace("_", "") == normalized
         end) do
      {bit, _mode} -> bit
      nil when normalized == "none" -> 0
      nil -> raise ArgumentError, "unknown monster mode #{inspect(name)}"
    end
  end

  @doc "Encodes mode atoms as the bitmask retained in a calculated snapshot."
  @spec mask([atom()]) :: non_neg_integer()
  def mask(modes) do
    Enum.reduce(modes, 0, fn mode, mask ->
      case List.keyfind(@mode_bits, mode, 1) do
        {bit, ^mode} -> mask ||| bit
        nil -> raise ArgumentError, "unknown monster mode #{inspect(mode)}"
      end
    end)
  end

  @doc "Decodes the recognized mode bits for behavior and class readers."
  @spec from_mask(non_neg_integer()) :: [atom()]
  def from_mask(mask), do: decode(mask)

  @typedoc "The monster class a unit runs as, derived from its current modes."
  @type class :: :normal | :boss | :guardian | :battlefield | :event

  @doc """
  Derives the monster class from a mode list, re-derived whenever the modes
  change: status and skill immune is a battlefield object; status immune,
  knockback immune and detector is a boss; status immune alone is a guardian;
  anything else is normal. A Mode refresh maps Event to normal; the initial
  database class is retained until that refresh.
  """
  @spec class([atom()]) :: class()
  def class(modes) when is_list(modes) do
    cond do
      all?(modes, [:status_immune, :skill_immune]) -> :battlefield
      all?(modes, [:status_immune, :knockback_immune, :detector]) -> :boss
      :status_immune in modes -> :guardian
      true -> :normal
    end
  end

  defp all?(modes, required), do: Enum.all?(required, &(&1 in modes))

  @spec decode(non_neg_integer()) :: [atom()]
  defp decode(bitmask) do
    for {bit, atom} <- @mode_bits, band(bitmask, bit) != 0, do: atom
  end
end
