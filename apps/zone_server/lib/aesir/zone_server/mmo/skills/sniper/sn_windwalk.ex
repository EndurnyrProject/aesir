defmodule Aesir.ZoneServer.Mmo.Skills.Sniper.SnWindwalk do
  @moduledoc """
  Wind Walker buffs the caster and living same-map party members within 14 cells
  with FLEE and strongest-only movement haste for `100 + 30 * level` seconds.

  Both modes fail while Quagmired. Renewal has variable and fixed cast components
  of `1200 + 300 * level` and `400 + 100 * level` ms; pre-renewal has a single
  `1600 + 400 * level` ms cast. Both have a 2-second aftercast delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 383,
    name: :sn_windwalk,
    status: :sc_windwalk,
    display_name: "Wind Walker",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :weapon,
    splash_radius: 14,
    sp_cost: Enum.map(1..10, &(40 + 6 * &1)),
    cast_time: [
      renewal: Enum.map(1..10, &(1200 + 300 * &1)),
      pre_renewal: Enum.map(1..10, &(1600 + 400 * &1))
    ],
    fixed_cast_time: [renewal: Enum.map(1..10, &(400 + 100 * &1)), pre_renewal: []],
    after_cast_delay: List.duplicate(2000, 10),
    duration: Enum.map(1..10, &(100_000 + 30_000 * &1)),
    damage_splash: true

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Shared.PartySplash
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{character_id: id} = caster, :self, level, definition) do
    params = [val1: level, caster_id: id, duration: Enum.at(definition.duration, level - 1)]

    StatusInterpreter.apply_status(:player, id, :sc_windwalk, params)

    caster
    |> PartySplash.nearby_member_ids(definition.splash_radius)
    |> Enum.each(&StatusInterpreter.apply_status(:player, &1, :sc_windwalk, params))

    {:ok, caster}
  end
end
