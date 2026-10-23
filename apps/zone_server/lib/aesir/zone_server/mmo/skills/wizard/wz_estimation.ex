defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzEstimation do
  @moduledoc """
  Sense (WZ_ESTIMATION). Inspects a monster and sends its live data to the
  caster and, when the caster is in a party, to every party member on the same
  map; player targets are rejected.

  Renewal and pre-renewal agree: a 9-cell range and 10 SP.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 93,
    name: :wz_estimation,
    display_name: "Sense",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    sp_cost: [10]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.EstimationView
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @doc "A target gone when the cast ends fails silently, before anything is spent."
  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :target_not_found}
  def validate(_caster, {:unit, target_id}, _level, _definition) do
    if UnitRegistry.unit_id_exists?(target_id), do: :ok, else: {:error, :target_not_found}
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), atom()} | {:error, atom()}
  def cast(
        %PlayerState{character_id: caster_id} = caster,
        {:unit, target_id},
        _level,
        _definition
      ) do
    case UnitRegistry.get_unit(:player, caster_id) do
      {:ok, {_module, _caster, _caster_pid}} -> deliver_estimation(caster, target_id)
      {:error, :not_found} -> {:error, :target_not_found}
    end
  end

  defp deliver_estimation(caster, target_id) do
    case UnitRegistry.get_unit(:mob, target_id) do
      {:ok, {_module, %MobState{} = target, _pid}} ->
        deliver(caster, EstimationView.result(target_id, target))
        {:ok, caster}

      _not_a_monster ->
        not_a_monster(caster, target_id)
    end
  end

  # The reference charges the completed cast and then reports the failure, so a
  # player or any other non-monster target fails here; only a target that no
  # longer exists is refused without a spend.
  defp not_a_monster(caster, target_id) do
    if UnitRegistry.unit_id_exists?(target_id),
      do: {:failed, caster, :invalid_target},
      else: {:error, :target_not_found}
  end

  # The reference sends the estimation to the caster, or to the whole party on
  # the same map once the caster has one.
  defp deliver(%PlayerState{} = caster, packet) do
    caster
    |> recipients()
    |> Enum.each(&PlayerSession.send_packet(&1, packet))
  end

  defp recipients(%PlayerState{character_id: caster_id, party_id: party_id, map_name: map_name}) do
    (party_member_ids(party_id) ++ [caster_id])
    |> Enum.uniq()
    |> Enum.flat_map(&same_map_pid(&1, map_name))
  end

  defp party_member_ids(party_id) when party_id in [nil, 0], do: []

  defp party_member_ids(party_id) do
    case PartyManager.get(party_id) do
      {:ok, party} -> party |> PartyState.online_members() |> Enum.map(& &1.char_id)
      {:error, _reason} -> []
    end
  end

  defp same_map_pid(character_id, map_name) do
    case UnitRegistry.get_unit(:player, character_id) do
      {:ok, {_module, %PlayerState{map_name: ^map_name}, pid}} when is_pid(pid) -> [pid]
      _unresolved -> []
    end
  end
end
