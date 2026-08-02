defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CpHelm do
  @moduledoc """
  Chemical Protection Helm (SC_CP_HELM).

  Protects the holder's helm from being broken while active.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_cp_helm,
    no_dispel: true,
    properties: [:buff],
    end_on_start: [:sc_cp_helm],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :protecthelm
end
