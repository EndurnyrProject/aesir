defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SoulChangeMarker do
  @moduledoc """
  Invisible marker left on a monster that has already yielded SP to Soul
  Exhale, so each monster grants it only once. Permanent for the monster's
  life and identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_soulchange_marker,
    no_dispel: true,
    no_clear_buff: true,
    engine_only: true,
    no_save: true,
    permanent: true,
    bypass_resistance: true,
    properties: [:debuff],
    prevented_by: [:sc_soulchange_marker],
    target_types: [:mob]
end
