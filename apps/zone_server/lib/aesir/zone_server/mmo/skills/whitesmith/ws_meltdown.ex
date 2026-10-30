defmodule Aesir.ZoneServer.Mmo.Skills.Whitesmith.WsMeltdown do
  @moduledoc """
  Shattering Strike (WS_MELTDOWN). Grants weapon and armor breaking rates
  of 1% and 0.7% per level for 15 to 60 seconds, spending 50 to 90 SP.

  Pre-renewal uses 500 to 1,000 ms variable casts. Renewal instead uses literal
  5 to 10 ms fixed casts. Both modes retain the buff through death and Dispel,
  but do not save it. The shared weapon-hit stage handles player breaks and
  non-player strips with separate original-attacker and inherited-source identities.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 384,
    name: :ws_meltdown,
    display_name: "Shattering Strike",
    max_level: 10,
    target_type: :self,
    sp_cost: [50, 50, 60, 60, 70, 70, 80, 80, 90, 90],
    duration: [15_000, 20_000, 25_000, 30_000, 35_000, 40_000, 45_000, 50_000, 55_000, 60_000],
    cast_time: [
      renewal: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      pre_renewal: [500, 500, 600, 600, 700, 700, 800, 800, 900, 1_000]
    ],
    fixed_cast_time: [
      renewal: [5, 5, 6, 6, 7, 7, 8, 8, 9, 10],
      pre_renewal: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    ],
    status: :sc_meltdown

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @doc "Applies the paid self buff, retaining the committed caster on refusal."
  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(%PlayerState{character_id: id} = caster, :self, level, definition) do
    apply_buff(:player, id, :player, id, level, definition)
    {:ok, caster}
  end

  @doc "Applies the buff to the raw monster-cast recipient with a typed source."
  @impl Active
  @spec mob_cast(MobState.t(), {:unit, atom(), integer()}, pos_integer(), Definition.t(), map()) ::
          :ok
  def mob_cast(%MobState{instance_id: source_id}, {:unit, type, id}, level, definition, _row) do
    apply_buff(type, id, :mob, source_id, level, definition)
    :ok
  end

  defp apply_buff(type, id, source_type, source_id, level, definition) do
    Interpreter.apply_status(type, id, :sc_meltdown,
      val1: level,
      caster_id: source_id,
      source_type: source_type,
      duration: Enum.at(definition.duration, level - 1, 60_000)
    )
  end
end
