defmodule Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy do
  @moduledoc """
  Bounded actions for a skill-unit group when its caster or target disappears.

  A group either expires or skips its scheduled action until normal expiry.
  """
  use TypedStruct

  @typedoc "A supported loss action for a persistent skill-unit group."
  @type action :: :expire | :skip_action

  typedstruct do
    field :on_caster_loss, action(), default: :expire
    field :on_target_loss, action(), default: :expire
  end
end
