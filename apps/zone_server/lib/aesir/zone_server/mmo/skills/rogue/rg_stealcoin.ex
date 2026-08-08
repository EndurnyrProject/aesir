defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgStealcoin do
  @moduledoc "Mug (RG_STEALCOIN), a one-time zeny steal from a monster."

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

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @max_zeny 1_000_000_000

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_target}
  def validate(_caster, {:unit, target_id}, _level, _definition) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :ok, else: {:error, :invalid_target}
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{} = caster, {:unit, target_id}, level, _definition) do
    with {:ok, {_module, _state, pid}} <- UnitRegistry.get_unit(:mob, target_id),
         {:ok, zeny} <- MobSession.attempt_mug(pid, mug_caster(caster), level) do
      {:ok, %{caster | zeny: min(caster.zeny + zeny, @max_zeny)}}
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
