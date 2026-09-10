defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SteelBody do
  @moduledoc """
  Mental Strength (SC_STEELBODY).

  Reduces every positive incoming damage instance to one tenth, with a minimum
  of one damage, while applying its fixed movement and attack-delay penalties.

  Renewal divides every positive incoming damage by ten. Pre-renewal sets hard DEF
  and MDEF to 90 instead. Both lock the walk to 200 ms per cell, cut attack speed
  by 25%, and block skill use.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_steelbody,
    no_dispel: false,
    no_save: true,
    properties: [:buff, :prevents_skills],
    calc_flags: [:speed, :aspd, :def, :mdef],
    icon: :steelbody,
    opt3: :steelbody

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas

  @impl true
  def modifiers(_instance, _context) do
    shared = %{
      walk_speed_override: Formulas.mental_strength_walk_speed(),
      aspd_penalty_rate: Formulas.mental_strength_aspd_penalty_rate()
    }

    case GameMode.mode() do
      :renewal -> shared
      :pre_renewal -> Map.merge(shared, %{def_override: 90, mdef_override: 90})
    end
  end

  @impl true
  def absorb_damage(_target, instance, %{damage: damage}, _context) when damage > 0 do
    if GameMode.mode() == :renewal,
      do: {:ok, Formulas.mental_strength_damage(damage), instance},
      else: {:ok, damage, instance}
  end

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}
end
