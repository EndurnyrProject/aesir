defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsEnchantpoison do
  @moduledoc """
  Enchant Poison (AS_ENCHANTPOISON). Endows the caster's or a nearby party ally's
  weapon with the poison element for 15 s plus 15 s per level and 20 SP; ordinary
  swings then poison 2.5% plus 0.5% per level of the time for 10 s per level.
  The caster's own homunculus is a valid target; anyone else's is refused
  silently when the use starts (the engine's support rule).

  Renewal and pre-renewal agree.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 138,
    name: :as_enchantpoison,
    status: :sc_encpoison,
    display_name: "Enchant Poison",
    max_level: 10,
    target_type: :target_ally,
    damage_type: :no_damage,
    element: :poison,
    range: 1,
    sp_cost: List.duplicate(20, 10),
    duration: Enum.map(1..10, &(30_000 + 15_000 * (&1 - 1)))

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(_caster, :self, _level, _definition), do: :ok

  def validate(caster, {:unit, {:homunculus, gid}}, _level, _definition) do
    if own_homunculus?(caster, gid), do: :ok, else: {:error, :invalid_target}
  end

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
    apply_endow(caster, caster_id, {:player, caster_id}, level, definition)
  end

  def cast(%{character_id: caster_id} = caster, {:unit, {:homunculus, gid}}, level, definition) do
    apply_endow(caster, caster_id, {:homunculus, gid}, level, definition)
  end

  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    apply_endow(caster, caster_id, {:player, target_id}, level, definition)
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  # A dead party member passes these pre-payment gates: the reference's
  # implementation returns before its effect and the interpreter settles such a
  # cast as a paid skip, so liveness is not a gate here.
  defp eligible_ally?(caster, target, pid) do
    Process.alive?(pid) and
      caster.character_id != target.character_id and
      caster.map_name == target.map_name and
      caster.party_id != 0 and
      caster.party_id == target.party_id
  end

  defp own_homunculus?(%{character_id: caster_id}, gid) do
    match?(
      {:ok, {_module, %HomunculusState{owner_character_id: ^caster_id}, _pid}},
      UnitRegistry.get_unit(:homunculus, gid)
    )
  end

  defp own_homunculus?(_caster, _gid), do: false

  defp apply_endow(caster, caster_id, {target_type, target_id}, level, definition) do
    case StatusInterpreter.apply_status(target_type, target_id, :sc_encpoison,
           val1: level,
           caster_id: caster_id,
           source_type: :player,
           duration: Enum.at(definition.duration, level - 1)
         ) do
      :ok -> {:ok, caster}
      # The reference reports the refusal from inside the implementation.
      {:error, reason} -> {:failed, caster, reason}
    end
  end
end
