defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RejectSword do
  @moduledoc """
  Counter Instinct (SC_REJECTSWORD).

  In renewal and pre-renewal, lasts until spent: `val2` is the counter chance
  (15 percent per level) and `val3` the charges left (3). A weapon hit on the
  holder from a monster, or from a player whose right hand holds a dagger, a
  one-handed or a two-handed sword, has a `val2` percent chance to be halved
  after the holder's reductions and the siege rate (only the right hand's part
  of a dual-wield swing); the halved amount is dealt back to the attacker and
  one charge is spent, the last ending the status. It is saved at logout and a
  restore keeps its chance and charges.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_rejectsword,
    permanent: true,
    remove_on_death: true,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    icon: :swordreject

  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @skill_id 390
  @countered_weapons [:dagger, :one_handed_sword, :two_handed_sword]

  @impl true
  @spec on_apply(Definition.target(), StatusEntry.t(), Definition.context()) ::
          {:ok, StatusEntry.t()}
  def on_apply(_target, instance, %{loaded: true}), do: {:ok, instance}

  def on_apply(_target, instance, _context),
    do: {:ok, %{instance | val2: 15 * instance.val1, val3: 3}}

  @impl true
  @spec final_weapon_hit(Definition.target(), StatusEntry.t(), non_neg_integer(), map()) ::
          :continue | {:counter, non_neg_integer(), non_neg_integer()}
  def final_weapon_hit(holder, %StatusEntry{} = instance, damage, %{attacker: attacker}) do
    if countered?(attacker) and :rand.uniform(100) - 1 < instance.val2 and
         claim_charge(holder, instance) do
      show_effect(holder, instance.val1)
      halved = div(damage * 50, 100)
      {:counter, halved, halved}
    else
      :continue
    end
  end

  def final_weapon_hit(_holder, _instance, _damage, _hit_info), do: :continue

  defp countered?({:player, id}) do
    case UnitRegistry.get_unit(:player, id) do
      {:ok, {_module, %PlayerState{stats: %{equipment: equipment}}, _pid}} ->
        PlayerStats.weapon_type(equipment) in @countered_weapons

      _gone ->
        false
    end
  end

  defp countered?({_type, _id}), do: true
  defp countered?(_attacker), do: false

  # Concurrent attackers run in their own processes: a charge is claimed only
  # from the generation read, with one reread when another attacker won it.
  defp claim_charge(holder, instance), do: claim_charge(holder, instance, 1)

  defp claim_charge({type, id} = holder, instance, retries) do
    claimed? =
      if instance.val3 <= 1,
        do: Interpreter.expire_status_if_current(type, id, :sc_rejectsword, instance),
        else:
          StatusStorage.replace_status_if_current(type, id, :sc_rejectsword, instance, %{
            instance
            | val3: instance.val3 - 1
          })

    with false <- claimed?,
         true <- retries > 0,
         %StatusEntry{} = current <- StatusStorage.get_status(type, id, :sc_rejectsword) do
      claim_charge(holder, current, retries - 1)
    else
      result -> result == true
    end
  end

  defp show_effect({type, id}, level) do
    with {:ok, {x, y, map_name}} <- SpatialIndex.get_unit_position(type, id) do
      Broadcast.to_in_range(map_name, x, y, Config.view_range(), %SkillEffect{
        skill_id: @skill_id,
        level: level,
        src_id: id,
        target_id: id,
        result: 1
      })
    end
  end
end
