defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsEnchantpoison do
  @moduledoc """
  Enchant Poison (AS_ENCHANTPOISON) endows the caster or a nearby party ally's
  weapon with Poison and enables its ordinary-swing Poison proc.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 138,
    name: :as_enchantpoison,
    status: :sc_encpoison,
    display_name: "Enchant Poison",
    max_level: 10,
    target_type: :target_ally,
    damage_type: :no_damage,
    range: 1,
    sp_cost: List.duplicate(20, 10),
    duration: Enum.map(1..10, &(30_000 + 15_000 * (&1 - 1)))

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(_caster, :self, _level, _definition), do: :ok

  def validate(caster, {:unit, target_id}, _level, _definition) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, target, pid}} when is_pid(pid) ->
        if eligible_ally?(caster, target, pid), do: :ok, else: {:error, :invalid_target}

      _ ->
        {:error, :invalid_target}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    apply_endow(caster, caster_id, caster_id, level, definition)
  end

  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    apply_endow(caster, caster_id, target_id, level, definition)
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  defp eligible_ally?(caster, target, pid) do
    Process.alive?(pid) and
      caster.character_id != target.character_id and
      caster.map_name == target.map_name and
      caster.party_id != 0 and
      caster.party_id == target.party_id and
      Unit.living?(target)
  end

  defp apply_endow(caster, caster_id, target_id, level, definition) do
    case StatusInterpreter.apply_status(:player, target_id, :sc_encpoison,
           val1: level,
           caster_id: caster_id,
           source_type: :player,
           duration: Enum.at(definition.duration, level - 1)
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
