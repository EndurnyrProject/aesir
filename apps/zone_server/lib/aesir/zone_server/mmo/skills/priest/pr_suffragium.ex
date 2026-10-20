defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrSuffragium do
  @moduledoc """
  Suffragium (PR_SUFFRAGIUM). Shortens the variable cast time of the next casts.

  Renewal: a self-cast that also reaches every living same-map party member within
  18 cells, cutting variable cast by 10, 15, or 20% for a full minute (the buff is
  not consumed by casting), with a 1 s cast plus 0.5 s fixed, a 1 s delay, and a
  30 s cooldown. Pre-renewal: a single-target support cast at 9 cells cutting cast
  time by 15% per level for 30, 20, or 10 s, consumed by the receiver's next skill
  cast, with no cast time and a 2 s delay. Both modes cost 8 SP.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 67,
    name: :pr_suffragium,
    status: :sc_suffragium,
    display_name: "Suffragium",
    max_level: 3,
    target_type: [renewal: :self, pre_renewal: :target_ally],
    damage_kind: :magic,
    range: 9,
    splash_radius: [renewal: 18, pre_renewal: 0],
    sp_cost: List.duplicate(8, 3),
    cast_time: [renewal: List.duplicate(1_000, 3), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(500, 3), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(1_000, 3), pre_renewal: List.duplicate(2_000, 3)],
    cooldown: [renewal: List.duplicate(30_000, 3), pre_renewal: []],
    duration: [renewal: List.duplicate(60_000, 3), pre_renewal: [30_000, 20_000, 10_000]],
    damage_splash: [renewal: true, pre_renewal: false]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Shared.PartySplash
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    params = params(caster_id, level, definition)

    StatusInterpreter.apply_status(:player, caster_id, :sc_suffragium, params)

    if definition.target_type == :self,
      do: splash_to_party(caster, definition.splash_radius, params)

    {:ok, caster}
  end

  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    StatusInterpreter.apply_status(
      :player,
      target_id,
      :sc_suffragium,
      params(caster_id, level, definition)
    )

    {:ok, caster}
  end

  defp params(caster_id, level, definition) do
    [val1: level, caster_id: caster_id, duration: Enum.at(definition.duration, level - 1)]
  end

  defp splash_to_party(caster, splash_radius, params) do
    caster
    |> PartySplash.nearby_member_ids(splash_radius)
    |> Enum.each(&StatusInterpreter.apply_status(:player, &1, :sc_suffragium, params))
  end
end
