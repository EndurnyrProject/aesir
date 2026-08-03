defmodule Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership do
  @moduledoc """
  Determines ranked loot owners and enforces phased ground-item pickup rights.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defstruct first: nil, second: nil, third: nil

  @type t() :: %__MODULE__{
          first: integer() | nil,
          second: integer() | nil,
          third: integer() | nil
        }

  @type party_ctx() :: %{party_id: non_neg_integer(), pickup_share: boolean()}

  @doc """
  Ranks the top three eligible attackers by damage after applying the
  first-eligible-attacker bonus.

  The bonus is based on total damage from the full log, including damage from
  attackers who are no longer eligible.
  """
  @spec determine(MobState.t(), (integer(), String.t() -> boolean())) :: t()
  def determine(mob_state, eligible? \\ &default_eligible?/2) do
    damage_log = MobState.damage_log(mob_state)
    total_damage = Enum.sum_by(damage_log, &elem(&1, 1))
    bonus = div(total_damage * Config.first_attack_loot_bonus(), 100)

    owners =
      damage_log
      |> Enum.filter(fn {attacker_id, _damage} -> eligible?.(attacker_id, mob_state.map_name) end)
      |> add_first_attack_bonus(bonus)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(3)
      |> Enum.map(&elem(&1, 0))

    [first, second, third] = Enum.take(owners ++ [nil, nil, nil], 3)
    %__MODULE__{first: first, second: second, third: third}
  end

  @doc """
  Ranks typed contributors after projecting eligible actual sources to their
  hit-time reward owners and aggregating raw damage by owner.

  The full typed log determines the bonus. It is added once to the reward owner
  of the first eligible actual contributor; ties retain earliest hit order.
  """
  @spec determine_typed(MobState.t(), (map(), String.t() -> boolean())) :: t()
  def determine_typed(mob_state, eligible? \\ &default_typed_eligible?/2) do
    damage_log = MobState.typed_damage_log(mob_state)
    bonus = div(Enum.sum_by(damage_log, & &1.damage) * Config.first_attack_loot_bonus(), 100)
    eligible_entries = Enum.filter(damage_log, &eligible?.(&1, mob_state.map_name))

    ranked =
      eligible_entries
      |> Enum.group_by(& &1.reward_owner_id)
      |> Enum.map(fn {owner_id, entries} ->
        damage = Enum.sum_by(entries, & &1.damage)
        first_hit_order = Enum.min_by(entries, & &1.first_hit_order).first_hit_order
        %{owner_id: owner_id, damage: damage, first_hit_order: first_hit_order}
      end)
      |> add_typed_first_attack_bonus(eligible_entries, bonus)
      |> Enum.sort_by(&{-&1.damage, &1.first_hit_order})
      |> Enum.take(3)
      |> Enum.map(& &1.owner_id)

    [first, second, third] = Enum.take(ranked ++ [nil, nil, nil], 3)
    %__MODULE__{first: first, second: second, third: third}
  end

  @doc """
  Returns cumulative absolute pickup deadlines for a normal or boss item.
  """
  @spec deadlines(boolean(), integer()) :: {integer(), integer(), integer()}
  def deadlines(boss?, now) do
    {first_window, second_window, third_window} = windows(boss?)
    first = now + first_window
    second = first + second_window
    {first, second, second + third_window}
  end

  @doc """
  Checks whether a character may claim a ground item at the given time.

  Direct owners unlock in rank order, party members follow the same owner
  phases when pickup sharing is enabled, and all other characters wait for the
  public deadline.

  A public item must be stamped with `owners: nil`, never `{nil, nil, nil}` —
  an all-nil tuple keeps the ladder active and makes everyone wait for the
  public deadline.
  """
  @spec can_claim?(GroundItem.t(), integer(), party_ctx(), integer(), (integer() -> integer())) ::
          :ok | {:error, :protected}
  def can_claim?(item, char_id, party_ctx, now, owner_party_resolver \\ &default_owner_party/1)

  def can_claim?(%{owners: nil}, _char_id, _party_ctx, _now, _owner_party_resolver), do: :ok

  def can_claim?(
        %{owners: {first, second, third}, unlock_at: {t1, t2, t3}},
        char_id,
        party_ctx,
        now,
        owner_party_resolver
      ) do
    cond do
      char_id == first ->
        :ok

      char_id == second and now >= t1 ->
        :ok

      char_id == third and now >= t2 ->
        :ok

      party_can_claim?(
        {first, second, third},
        {t1, t2},
        party_ctx,
        now,
        owner_party_resolver
      ) ->
        :ok

      now >= t3 ->
        :ok

      true ->
        {:error, :protected}
    end
  end

  defp add_first_attack_bonus([], _bonus), do: []

  defp add_first_attack_bonus([{attacker_id, damage} | rest], bonus) do
    [{attacker_id, damage + bonus} | rest]
  end

  defp add_typed_first_attack_bonus(ranked, [], _bonus), do: ranked

  defp add_typed_first_attack_bonus(ranked, [first_entry | _rest], bonus) do
    Enum.map(ranked, fn
      %{owner_id: owner_id} = entry when owner_id == first_entry.reward_owner_id ->
        %{entry | damage: entry.damage + bonus}

      entry ->
        entry
    end)
  end

  defp windows(false) do
    {
      Config.item_first_get_time(),
      Config.item_second_get_time(),
      Config.item_third_get_time()
    }
  end

  defp windows(true) do
    {
      Config.mvp_item_first_get_time(),
      Config.mvp_item_second_get_time(),
      Config.mvp_item_third_get_time()
    }
  end

  defp party_can_claim?(_owners, _deadlines, %{pickup_share: false}, _now, _resolver),
    do: false

  defp party_can_claim?(_owners, _deadlines, %{party_id: 0}, _now, _resolver), do: false

  defp party_can_claim?(
         {first, second, third},
         {t1, t2},
         %{party_id: party_id, pickup_share: true},
         now,
         resolver
       ) do
    [{first, true}, {second, now >= t1}, {third, now >= t2}]
    |> Enum.any?(fn
      {nil, _unlocked?} -> false
      {owner_id, true} -> resolver.(owner_id) == party_id
      {_owner_id, false} -> false
    end)
  end

  defp default_typed_eligible?(
         %{contributor: {:player, char_id}, reward_owner_id: char_id},
         map_name
       ),
       do: default_eligible?(char_id, map_name)

  defp default_typed_eligible?(
         %{contributor: {:homunculus, gid}, reward_owner_id: owner_id},
         map_name
       ) do
    default_eligible?(owner_id, map_name) and
      case UnitRegistry.get_unit(:homunculus, gid) do
        {:ok,
         {HomunculusState,
          %HomunculusState{owner_character_id: ^owner_id, map_name: ^map_name} = homunculus, _pid}} ->
          HomunculusState.living?(homunculus)

        _other ->
          false
      end
  end

  defp default_typed_eligible?(
         %{contributor: {:mob, _gid}, reward_owner_id: owner_id},
         map_name
       )
       when is_integer(owner_id),
       do: default_eligible?(owner_id, map_name)

  defp default_typed_eligible?(_entry, _map_name), do: false

  defp default_eligible?(attacker_id, map_name) do
    case UnitRegistry.get_unit(:player, attacker_id) do
      {:ok, {PlayerState, %PlayerState{map_name: ^map_name} = player_state, _pid}} ->
        PlayerState.living?(player_state)

      _other ->
        false
    end
  end

  defp default_owner_party(owner_id) do
    case UnitRegistry.get_unit(:player, owner_id) do
      {:ok, {_module, player_state, _pid}} -> player_state.party_id
      {:error, :not_found} -> 0
    end
  end
end
