defmodule Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy do
  @moduledoc """
  Bounded actions for a skill-unit group when its caster or target disappears.

  Continuing after loss is permitted only with combat data captured explicitly
  by the originating skill.
  """
  use TypedStruct

  @typedoc "Combat state captured before the live unit became unavailable."
  @type combat_snapshot :: map()

  @typedoc "A supported loss action for a persistent skill-unit group."
  @type action ::
          :expire
          | :skip_action
          | :persist_inert
          | {:continue_with_combat_snapshot, combat_snapshot()}

  typedstruct do
    field :on_caster_loss, action(), default: :expire
    field :on_target_loss, action(), default: :expire
  end
end
