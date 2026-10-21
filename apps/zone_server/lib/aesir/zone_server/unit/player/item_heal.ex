defmodule Aesir.ZoneServer.Unit.Player.ItemHeal do
  @moduledoc """
  The HP and SP an item heal (the `itemheal` script command) restores.

  HP starts from a percent bonus of `100 + 2 * VIT + 10 * Increase HP Recovery
  + 5 * Potion Research` plus the flat item heal rate, then compounds the
  matching item-group rate, the healing item's own rate and Increase Heal Rate
  (`val1`), each on the running bonus. SP uses INT, Increase SP Recovery and the
  SP rates, without Increase Heal Rate. A bonus only ever raises an amount.

  The recipient's statuses then apply: No Recovery cancels both, and in renewal
  Apple of Idun adds `val3 / 100` HP and Asura recovery cancels SP.

  Not modelled: ranked (famous Alchemist) potions, and the Critical Wound, Death
  Hurt, Vitality Activation, Water Insignia and Bite Scar terms, whose statuses
  do not exist yet.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @sm_recovery 4
  @mg_srecovery 9
  @am_learningpotion 227

  @doc """
  The `{hp, sp}` an item heal of `hp`/`sp` restores on `game_state`, before the
  heal is applied. `item_id` is the healing item (`nil` outside an item use).
  """
  @spec amounts(PlayerState.t(), pos_integer() | nil, integer(), integer()) ::
          {integer(), integer()}
  def amounts(%PlayerState{stats: stats, character_id: char_id}, item_id, hp, sp) do
    potion_research = 5 * PlayerStats.skill_level(stats, @am_learningpotion)

    hp_bonus =
      (100 + 2 * PlayerStats.get_effective_stat(stats, :vit) +
         10 * PlayerStats.skill_level(stats, @sm_recovery) + potion_research +
         PlayerStats.get_item_heal_rate(stats))
      |> compound(group_rate(stats, :add_item_group_heal, item_id))
      |> compound(PlayerStats.get_equipment_modifier(stats, {:add_item_heal, item_id}))
      |> compound(inc_heal_rate(char_id))

    sp_bonus =
      (100 + 2 * PlayerStats.get_effective_stat(stats, :int) +
         10 * PlayerStats.skill_level(stats, @mg_srecovery) + potion_research +
         PlayerStats.get_equipment_modifier(stats, :item_sp_heal_rate))
      |> compound(group_rate(stats, :add_item_group_sp_heal, item_id))
      |> compound(PlayerStats.get_equipment_modifier(stats, {:add_item_sp_heal, item_id}))

    apply_statuses(raise_by(hp, hp_bonus), raise_by(sp, sp_bonus), char_id)
  end

  defp compound(bonus, rate), do: bonus + div(bonus * rate, 100)

  defp raise_by(amount, bonus) do
    scaled = div(amount * bonus, 100)
    if bonus != 100 and scaled > amount, do: scaled, else: amount
  end

  defp group_rate(_stats, _family, nil), do: 0

  defp group_rate(stats, family, item_id) do
    Enum.reduce(stats.modifiers.equipment, 0, fn
      {{^family, group_key}, rate}, acc ->
        if ItemGroups.member?(group_key, item_id), do: acc + rate, else: acc

      _modifier, acc ->
        acc
    end)
  end

  defp inc_heal_rate(char_id) do
    case StatusStorage.get_status(:player, char_id, :sc_inchealrate) do
      nil -> 0
      entry -> entry.val1
    end
  end

  defp apply_statuses(hp, sp, char_id) do
    renewal? = GameMode.mode() == :renewal
    hp = if renewal?, do: hp + apple_idun(char_id), else: hp

    {hp, sp} =
      if StatusStorage.has_status?(:player, char_id, :sc_norecover_state),
        do: {0, 0},
        else: {hp, sp}

    if renewal? and StatusStorage.has_status?(:player, char_id, :sc_extremityfist),
      do: {hp, 0},
      else: {hp, sp}
  end

  defp apple_idun(char_id) do
    case StatusStorage.get_status(:player, char_id, :sc_appleidun) do
      nil -> 0
      entry -> div(entry.val3, 100)
    end
  end
end
