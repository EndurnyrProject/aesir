defmodule Aesir.ZoneServer.Mmo.Skills.ElementField do
  @moduledoc """
  Shared placement and support shape for the Sage element fields.

  Volcano, Deluge and Violent Gale are the same ground field with a different
  element, and Land Protector shares their per-caster exclusivity. rAthena keeps
  the four together in `skill_locate_element_field` (`src/map/skill.cpp:11059-11080`)
  and clears the caster's previous field before placing a new one
  (`src/map/skill.cpp:5883-5907`); `Skill.Unit.Manager` reproduces that from the
  `exclusive_family` lifecycle policy, so the family name lives here once.

  Only the trio sets `inherit_family_duration`: a swap between them carries the
  old field's *remaining* duration, so recasting never refreshes it.
  """
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy

  @family :sage_element_field
  @layout_radius 3

  @doc "The lifecycle policy shared by every member of the element-field family."
  @spec policy(boolean()) :: LifecyclePolicy.t()
  def policy(inherit_family_duration \\ false) do
    %LifecyclePolicy{
      exclusive_family: @family,
      inherit_family_duration: inherit_family_duration
    }
  end

  @doc """
  The trio's common placement: a tickless 7x7 field lasting `60 * level` seconds.

  `skill_db.yml` gives all three `Layout: 3` and `Interval: -1`; the interval is
  inert because the manager never schedules a tick for these groups (see
  `schedule/1`).
  """
  @spec placement(Ground.cell(), pos_integer()) :: Ground.placement()
  def placement(center, level) do
    %{
      cells: Layout.square(center, @layout_radius),
      state: %{},
      interval: 1_000,
      duration: 60_000 * level,
      path_check: true,
      lifecycle_policy: policy(true)
    }
  end

  @doc "The trio's common field support: the matching status for every occupant."
  @spec support(atom(), pos_integer()) :: map()
  def support(status_type, level) do
    %{
      status_type: status_type,
      params: [level: level, val1: level],
      target?: fn _target -> true end
    }
  end
end
