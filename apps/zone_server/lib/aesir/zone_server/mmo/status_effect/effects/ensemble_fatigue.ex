defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnsembleFatigue do
  @moduledoc """
  Temporary movement and attack-speed penalty after a paired renewal ensemble.

  Skilled Special Singer is the only usable skill while fatigued. Pre-renewal
  ensembles do not grant fatigue; an explicitly applied status there keeps the
  ASPD penalty but not the slow, which only renewal's speed recipe reads.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_ensemblefatigue,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:debuff, :prevents_skills],
    allow_skills: [5068],
    calc_flags: [:movement_speed, :aspd_rate],
    duration: 10_000

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(_instance, _context) do
    case GameMode.mode() do
      :renewal -> %{movement_speed: 20, aspd_rate: -30}
      :pre_renewal -> %{aspd_rate: -30}
    end
  end
end
