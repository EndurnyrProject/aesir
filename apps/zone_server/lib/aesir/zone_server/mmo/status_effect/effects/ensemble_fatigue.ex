defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnsembleFatigue do
  @moduledoc "Temporary movement and attack-speed penalty after a paired ensemble."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_ensemblefatigue,
    no_dispel: true,
    properties: [:debuff, :prevents_skills],
    calc_flags: [:movement_speed, :aspd_rate],
    duration: 10_000

  @modifiers %{movement_speed: 20, aspd_rate: -30}

  @impl true
  def modifiers(_instance, _context), do: @modifiers
end
