defmodule Aesir.ZoneServer.Mmo.Skills.Whitesmith.WsCartboost do
  @moduledoc """
  Cart Boost (WS_CARTBOOST). Requires a mounted player cart at cast begin,
  spends 20 SP, and grants 20-point strongest movement haste for 60 seconds.

  In both modes Decrease AGI is removed instead of granting the buff, and
  Quagmire prevents it. Don't Forget Me prevents it only in pre-renewal.
  Monster casts retain their typed recipient and have no player cart requirement.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 387,
    name: :ws_cartboost,
    display_name: "Cart Boost",
    max_level: 1,
    target_type: :self,
    sp_cost: [20],
    duration: [60_000],
    status: :sc_cartboost

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @doc "Requires a mounted player cart before committing resources."
  @impl Active
  @spec begin_attempt(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, :cart}
  def begin_attempt(%PlayerState{cart_type: 0}, _target, _level, _definition),
    do: {:error, :cart}

  def begin_attempt(caster, _target, _level, _definition), do: {:ok, caster}

  @doc "Attempts the self buff while retaining resources already spent on refusal."
  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(%PlayerState{character_id: id} = caster, :self, level, definition) do
    apply_boost(:player, id, :player, id, level, definition)
    {:ok, caster}
  end

  @doc "Applies the buff to the raw monster cast recipient without player requirements."
  @impl Active
  @spec mob_cast(MobState.t(), {:unit, atom(), integer()}, pos_integer(), Definition.t(), map()) ::
          :ok
  def mob_cast(%MobState{instance_id: source_id}, {:unit, type, id}, level, definition, _row) do
    apply_boost(type, id, :mob, source_id, level, definition)
    :ok
  end

  defp apply_boost(type, id, source_type, source_id, level, definition) do
    Interpreter.apply_status(type, id, :sc_cartboost,
      val1: level,
      caster_id: source_id,
      source_type: source_type,
      duration: Enum.at(definition.duration, level - 1, 60_000)
    )
  end
end
