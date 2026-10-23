defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgStealcoin do
  @moduledoc """
  Mug (RG_STEALCOIN), a one-time zeny steal from a monster.

  Both modes roll 10 times level plus DEX/2 plus LUK/2 plus twice the level gap
  per mille for 8 to 10 times the target level zeny, 15 SP, and a 0.5 s delay.
  A target that is not a monster, a status-immune monster, or a monster already
  mugged fails with the plain skill failure when the cast ends, before anything
  is spent.
  A success then deals the monster a zero-damage long weapon hit (aggro, coma,
  and the normal-attack additional effects such as Enchant Poison).
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 211,
    name: :rg_stealcoin,
    requires: [],
    display_name: "Mug",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 1,
    sp_cost: List.duplicate(15, 10),
    after_cast_delay: List.duplicate(500, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.Zeny

  @behaviour Active

  @mug_hit_flag BattleFlags.build(:weapon, :long, false)

  @doc """
  The cast-end check: only a monster that is neither status immune nor already
  mugged can be mugged; anything else fails with the plain skill failure before
  anything is spent.
  """
  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :skill_failed}
  def validate(_caster, {:unit, target_id}, _level, _definition) do
    case UnitRegistry.get_unit(:mob, target_id) do
      {:ok, {_module, %MobState{} = mob, _pid}} ->
        if MobState.status_immune?(mob) or mob.coin_stolen,
          do: {:error, :skill_failed},
          else: :ok

      {:ok, _unit} ->
        :ok

      {:error, _not_found} ->
        {:error, :skill_failed}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :skill_failed}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{} = caster, {:unit, target_id}, level, _definition) do
    with {:ok, {_module, _state, pid}} <- UnitRegistry.get_unit(:mob, target_id) do
      case MobSession.attempt_mug(pid, mug_caster(caster), level) do
        {:ok, zeny} ->
          mugged = %{caster | zeny: min(caster.zeny + zeny, Zeny.max_zeny())}
          {:ok, Combat.execute_zero_damage_hit(mugged, target_id, @mug_hit_flag)}

        # A monster another cast mugged between this cast's end checks.
        {:error, reason} when reason in [:immune, :already_mugged] ->
          {:failed, caster, :skill_failed}

        # The failed roll, reported from inside the effect with the generic reply.
        {:error, :no_coin} ->
          {:failed, caster, :no_coin}
      end
    end
  end

  defp mug_caster(caster) do
    %{
      dex: Stats.get_effective_stat(caster.stats, :dex),
      luk: Stats.get_effective_stat(caster.stats, :luk),
      base_level: caster.stats.progression.base_level
    }
  end
end
