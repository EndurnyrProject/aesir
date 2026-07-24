defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autoguard do
  @moduledoc """
  Guard (SC_AUTOGUARD).

  The persistent shield-block stance toggled by CR_AUTOGUARD, carrying the skill
  level in `val1`. While active, every weapon hit that lands on the holder rolls
  against a per-level block chance in `before_weapon_hit/4`; on a successful roll
  the swing is intercepted (it deals nothing) and a guard sprite plays on the
  holder for nearby viewers.

  Unlike Auto Counter this is not a single-use stance: a successful block leaves
  the status in place, so it keeps guarding every subsequent weapon hit until the
  skill is re-cast to toggle it off. Only weapon-class hits reach this hook -
  basic attacks and weapon skills - so magic and misc damage is never blocked.

  The status is a permanent toggle (`permanent: true`, no expiry) that is not
  persisted across logout (`no_save: true`); the shield requirement is checked by
  the skill at cast time only.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_autoguard,
    no_dispel: false,
    no_save: true,
    permanent: true,
    properties: [:buff],
    icon: :autoguard

  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.SpecialEffect

  # Block chance percent indexed by skill level (val1). A level below 1 clamps to
  # the first entry and a level above 10 (a stray mob-skill row) clamps to the
  # last, so an out-of-range level never crashes the roll.
  @block_chance {5, 10, 14, 18, 21, 24, 26, 28, 29, 30}
  @max_level tuple_size(@block_chance)

  @impl true
  @spec before_weapon_hit(
          {Unit.unit_type(), integer()},
          StatusEntry.t(),
          map(),
          map()
        ) :: :continue | {:intercept, :blocked}
  def before_weapon_hit({unit_type, unit_id}, %StatusEntry{val1: level}, _attack_info, _context) do
    if blocked?(level) do
      SpecialEffect.play({unit_type, unit_id}, :guard, :area)
      {:intercept, :blocked}
    else
      :continue
    end
  end

  @spec blocked?(integer()) :: boolean()
  defp blocked?(level) do
    :rand.uniform(100) <= elem(@block_chance, clamp_level(level) - 1)
  end

  @spec clamp_level(integer()) :: pos_integer()
  defp clamp_level(level) when level < 1, do: 1
  defp clamp_level(level) when level > @max_level, do: @max_level
  defp clamp_level(level), do: level
end
