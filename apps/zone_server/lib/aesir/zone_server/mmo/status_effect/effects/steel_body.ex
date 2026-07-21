defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SteelBody do
  @moduledoc """
  Mental Strength (SC_STEELBODY).

  Reduces every positive incoming damage instance to one tenth, with a minimum
  of one damage, while applying its fixed movement and attack-delay penalties.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_steelbody,
    no_dispel: false,
    no_save: true,
    properties: [:buff, :prevents_skills],
    calc_flags: [:speed, :aspd],
    icon: :steelbody,
    opt3: :steelbody

  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas

  @impl true
  def modifiers(_instance, _context) do
    %{
      walk_speed_override: Formulas.mental_strength_walk_speed(),
      aspd_penalty_rate: Formulas.mental_strength_aspd_penalty_rate()
    }
  end

  @impl true
  def absorb_damage(_target, instance, %{damage: damage}, _context) when damage > 0,
    do: {:ok, Formulas.mental_strength_damage(damage), instance}

  def absorb_damage(_target, instance, %{damage: damage}, _context), do: {:ok, damage, instance}
end
