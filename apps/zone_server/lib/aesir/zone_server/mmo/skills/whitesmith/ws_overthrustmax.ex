defmodule Aesir.ZoneServer.Mmo.Skills.Whitesmith.WsOverthrustmax do
  @moduledoc """
  Maximum Power Thrust (WS_OVERTHRUSTMAX). Spends 15 SP and 3,000 to 5,000
  zeny to add 20 percentage points per level to weapon skill ratios for
  180 seconds. Unfair Trick and Hilt Binding do not change these costs or duration.

  Replaces ordinary Over Thrust in both modes. Renewal ends the buff on weapon
  unequip; pre-renewal retains it and adds a 0.1% natural self-weapon break risk.
  Monster casts apply the same buff to their typed recipient without player costs.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 486,
    name: :ws_overthrustmax,
    display_name: "Maximum Power Thrust",
    max_level: 5,
    target_type: :self,
    sp_cost: [15, 15, 15, 15, 15],
    zeny_cost: [3_000, 3_500, 4_000, 4_500, 5_000],
    duration: [180_000, 180_000, 180_000, 180_000, 180_000],
    status: :sc_maxoverthrust,
    require_weapon: [
      :fist,
      :dagger,
      :one_handed_sword,
      :two_handed_sword,
      :one_handed_spear,
      :two_handed_spear,
      :one_handed_axe,
      :two_handed_axe,
      :mace,
      :two_handed_mace,
      :staff,
      :knuckle,
      :musical,
      :whip,
      :book,
      :katar,
      :revolver,
      :rifle,
      :gatling,
      :shotgun,
      :grenade,
      :huuma
    ]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @doc "Applies the paid self buff, retaining the committed caster on status refusal."
  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(%PlayerState{character_id: id} = caster, :self, level, definition) do
    apply_buff(:player, id, :player, id, level, definition)
    {:ok, caster}
  end

  @doc "Applies the status to the raw monster-cast recipient with its source identity."
  @impl Active
  @spec mob_cast(MobState.t(), {:unit, atom(), integer()}, pos_integer(), Definition.t(), map()) ::
          :ok
  def mob_cast(%MobState{instance_id: source_id}, {:unit, type, id}, level, definition, _row) do
    apply_buff(type, id, :mob, source_id, level, definition)
    :ok
  end

  defp apply_buff(type, id, source_type, source_id, level, definition) do
    Interpreter.apply_status(type, id, :sc_maxoverthrust,
      val1: level,
      caster_id: source_id,
      source_type: source_type,
      duration: Enum.at(definition.duration, level - 1, 180_000)
    )
  end
end
