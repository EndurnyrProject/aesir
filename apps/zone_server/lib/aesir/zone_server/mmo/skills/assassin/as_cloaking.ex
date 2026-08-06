defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsCloaking do
  @moduledoc """
  Cloaking (AS_CLOAKING), a self-toggle concealment skill.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 135,
    name: :as_cloaking,
    requires: [],
    status: :sc_cloaking,
    display_name: "Cloaking",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: List.duplicate(15, 10)

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @drain_intervals [500 | Enum.to_list(1_000..9_000//1_000)]

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(%PlayerState{character_id: caster_id} = caster, :self, level, _definition)
      when level in 1..2 do
    if StatusStorage.has_status?(:player, caster_id, :sc_cloaking) or
         MapCache.adjacent_impassable?(caster.map_name, caster.x, caster.y),
       do: :ok,
       else: {:error, :impassable_neighbor_required}
  end

  def validate(%PlayerState{}, :self, _level, _definition), do: :ok
  def validate(%MobState{}, :self, _level, _definition), do: :ok
  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{character_id: caster_id} = caster, :self, level, _definition) do
    adjacent? = MapCache.adjacent_impassable?(caster.map_name, caster.x, caster.y)

    case StatusInterpreter.toggle_status(:player, caster_id, :sc_cloaking,
           val1: level,
           tick: Enum.at(@drain_intervals, level - 1),
           caster_id: caster_id,
           source_type: :player,
           state: %{adjacent_impassable?: adjacent?}
         ) do
      {:ok, :applied} ->
        {:ok, caster |> PlayerState.stop_walking() |> PlayerState.clear_combat_intent()}

      {:ok, :removed} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  def cast(%PlayerState{character_id: caster_id} = caster, {:unit, caster_id}, level, definition),
    do: cast(caster, :self, level, definition)

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec mob_cast(MobState.t(), term(), pos_integer(), Definition.t(), map()) ::
          :ok | {:error, atom()}
  def mob_cast(%MobState{instance_id: caster_id}, _target, level, _definition, _row) do
    StatusInterpreter.apply_status(:mob, caster_id, :sc_cloaking,
      val1: level,
      caster_id: caster_id,
      source_type: :mob,
      duration: 10_000,
      state: %{adjacent_impassable?: false}
    )
  end
end
