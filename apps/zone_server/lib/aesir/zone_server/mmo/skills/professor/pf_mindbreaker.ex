defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfMindbreaker do
  @moduledoc """
  Mind Breaker (PF_MINDBREAKER). A `55 + 5 * level` percent chance to inflict
  `:sc_mindbreaker` for 30 s (MATK +20% and soft MDEF -12% per level). A
  successful break cancels the target's cast in progress and turns a monster
  on the caster. Undead and status-immune targets refuse it. Against a target
  already affected, or on a missed roll, the SP is spent and nothing happens.

  Identical in both modes: 12 to 24 SP, 9 cells, a 0.8 to 1.2 s after-cast
  delay. Monsters cast it through `mob_cast/5`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 402,
    name: :pf_mindbreaker,
    requires: [],
    status: :sc_mindbreaker,
    display_name: "Mind Breaker",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    sp_cost: [12, 15, 18, 21, 24],
    after_cast_delay: [800, 900, 1_000, 1_100, 1_200],
    duration: List.duplicate(30_000, 5)

  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @behaviour Active

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(_caster, {:unit, target_id}, _level, _definition) do
    with {:ok, _pid, state, _type} <- TargetResolver.resolve(target_id) do
      combatant = state.__struct__.to_combatant(state)

      if combatant.status_immune or RaceModifiers.undead_target?(combatant),
        do: {:error, :invalid_target},
        else: :ok
    end
  end

  def validate(_caster, _target, _level, _definition), do: :ok

  @doc """
  Breaks the target's mind on a successful roll. `opts` accepts `:rng`, a
  `(pos_integer() -> pos_integer())` roll defaulting to `&:rand.uniform/1`.
  """
  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t(), keyword()) ::
          {:ok, Active.caster()} | {:ok, Active.caster(), :no_consume} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition, opts \\ []) do
    with {:ok, pid, state, type} <- TargetResolver.resolve(target_id) do
      target = {type, state.__struct__.get_unit_id(state)}

      case break(
             caster,
             target,
             pid,
             level,
             definition,
             Keyword.get(opts, :rng, &:rand.uniform/1)
           ) do
        :already_affected -> {:ok, caster, :no_consume}
        _landed_or_missed -> {:ok, caster}
      end
    end
  end

  @impl Active
  @spec mob_cast(MobState.t(), term(), pos_integer(), Definition.t(), map()) ::
          :ok | {:error, atom()}
  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, definition, _row) do
    with {:ok, pid, _state, _type} <- TargetResolver.resolve({type, id}) do
      break(caster, {type, id}, pid, level, definition, &:rand.uniform/1)
      :ok
    end
  end

  defp break(caster, {type, id} = target, pid, level, definition, rng) do
    cond do
      StatusStorage.has_status?(type, id, :sc_mindbreaker) ->
        :already_affected

      rng.(100) > 55 + 5 * level ->
        :missed

      true ->
        caster_ref =
          {caster.__struct__.get_unit_type(caster), caster.__struct__.get_unit_id(caster)}

        with :ok <-
               StatusInterpreter.apply_status(type, id, :sc_mindbreaker,
                 val1: level,
                 duration: Enum.at(definition.duration, level - 1),
                 caster_id: elem(caster_ref, 1),
                 source_type: elem(caster_ref, 0)
               ) do
          disrupt(target, pid, caster_ref)
        end
    end
  end

  defp disrupt({:mob, _id}, pid, caster_ref) do
    MobSession.interrupt_cast(pid)
    MobSession.set_target(pid, caster_ref)
  end

  defp disrupt({:player, _id}, pid, _caster_ref), do: PlayerSession.interrupt_cast(pid)
  defp disrupt(_target, _pid, _caster_ref), do: :ok
end
