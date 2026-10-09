defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnsembleFatigue do
  @moduledoc """
  Temporary movement and attack-speed penalty after a paired renewal ensemble.

  Skilled Special Singer is the only usable skill while fatigued. Pre-renewal
  ensembles do not grant fatigue; an explicitly applied status behaves identically.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_ensemblefatigue,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:debuff, :prevents_skills],
    allow_skills: [5068],
    calc_flags: [:movement_speed, :aspd_rate],
    duration: 10_000

  @modifiers %{movement_speed: 20, aspd_rate: -30}

  @impl true
  def modifiers(_instance, _context), do: @modifiers
end
