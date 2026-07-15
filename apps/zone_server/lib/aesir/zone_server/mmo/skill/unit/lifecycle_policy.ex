defmodule Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy do
  @moduledoc """
  Bounded actions for a skill-unit group when its caster or target disappears,
  plus an optional cap on simultaneous groups from one caster.

  A group either expires or skips its scheduled action until normal expiry.
  """
  use TypedStruct

  @typedoc "A supported loss action for a persistent skill-unit group."
  @type action :: :expire | :skip_action

  @typedoc "The optional maximum number of live groups for one skill and caster."
  @type max_instances_per_caster :: pos_integer() | nil

  typedstruct do
    field :on_caster_loss, action(), default: :expire
    field :on_target_loss, action(), default: :expire
    field :max_instances_per_caster, max_instances_per_caster(), default: nil
  end
end
