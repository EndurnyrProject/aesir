defmodule Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy do
  @moduledoc """
  Bounded actions for a skill-unit group when its caster or target disappears,
  plus an optional cap on simultaneous groups from one caster.

  A group either expires or skips its scheduled action until normal expiry.
  """

  @typedoc "A supported loss action for a persistent skill-unit group."
  @type action :: :expire | :skip_action

  @typedoc "The optional maximum number of live groups for one skill and caster."
  @type max_instances_per_caster :: pos_integer() | nil

  @typedoc """
  The optional mutually exclusive family this group belongs to.

  A caster holds at most one group per family: placing a new member removes the
  caster's existing one (the Sage element fields, rAthena
  `skill_locate_element_field` / `skill_clear_group`). Other casters' groups are
  never touched.
  """
  @type exclusive_family :: atom() | nil

  defstruct on_caster_loss: :expire,
            on_target_loss: :expire,
            max_instances_per_caster: nil,
            exclusive_family: nil,
            inherit_family_duration: false

  @type t() :: %__MODULE__{
          on_caster_loss: action(),
          on_target_loss: action(),
          max_instances_per_caster: max_instances_per_caster(),
          exclusive_family: exclusive_family(),
          inherit_family_duration: boolean()
        }
end
