defmodule Aesir.ZoneServer.Mmo.Skills.Whitesmith.WsWeaponrefine do
  @moduledoc """
  Upgrade Weapon (WS_WEAPONREFINE). Opens a one-shot inventory-slot menu using
  the caster's learned rank, not the requested cast level. Opening costs 30 SP
  in Renewal or 5 SP in pre-renewal, even when the offer is empty or cancelled.

  Server-owned context captures rank and persisted row identity. Reply performs
  one ore-only refining transaction without charging SP again; a failed roll
  destroys the selected weapon. Non-player casts have no menu or effect.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 477,
    name: :ws_weaponrefine,
    display_name: "Upgrade Weapon",
    max_level: 10,
    target_type: :self,
    sp_cost: [
      renewal: [30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
      pre_renewal: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5]
    ]

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Refine.WeaponSkill
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player, as: PlayerCaster
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Menu
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.RefineOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpecialEffect

  @behaviour Active
  @behaviour Menu

  @doc "Stages the captured-rank offer after opening SP has already been paid."
  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()}
  def cast(%PlayerState{} = caster, :self, _requested_level, definition) do
    rank = PlayerCaster.skill_level(caster, definition.id)
    item_ids = WeaponSkill.offer(caster, rank)

    offer = %{
      skill_id: definition.id,
      kind: :INVENTORY_SLOTS,
      entry_ids: item_ids |> Map.keys() |> Enum.sort(),
      level: rank,
      context: %{learned_rank: rank, item_ids: item_ids},
      preserve_pending_on_empty: true
    }

    {:ok, %{caster | pending_menu_offer: offer}}
  end

  def cast(%MobState{} = caster, _target, _level, _definition), do: {:ok, caster}

  @doc "Refuses a context-free reply, which cannot authorize a persisted selection."
  @impl Menu
  @spec on_menu_reply(PlayerState.t(), Menu.selection(), pos_integer()) :: Menu.result()
  def on_menu_reply(_caster, _selection, _level), do: {:error, :no_item}

  @doc "Uses only the server's frozen rank and row id; trading refuses before attempting a write."
  @impl Menu
  @spec on_menu_reply(PlayerState.t(), Menu.selection(), pos_integer(), Menu.context()) ::
          Menu.result()
  def on_menu_reply(_caster, _selection, _level, %{trading?: true}), do: {:error, :skill_failed}

  def on_menu_reply(caster, %{id: index}, _level, %{
        menu: %{context: %{learned_rank: rank, item_ids: ids}}
      }) do
    with {:ok, expected_id} <- Map.fetch(ids, index),
         %InventoryItem{nameid: nameid} <- Map.get(caster.inventory, index) do
      caster |> RefineOps.weapon_skill(index, expected_id, rank) |> finish(nameid)
    else
      _missing -> {:error, :no_item}
    end
  end

  defp finish({caster, {:ok, :success, _refine}}, nameid) do
    SpecialEffect.play({:player, caster.character_id}, :refineok, :self)
    {:ok, %{caster | pending_production_result: %{success: true, item_id: nameid}}}
  end

  defp finish({caster, {:ok, :broke}}, nameid) do
    SpecialEffect.play({:player, caster.character_id}, :refinefail, :self)
    Emote.show({:player, caster.character_id}, :huk)
    {:ok, %{caster | pending_production_result: %{success: false, item_id: nameid}}}
  end

  defp finish({_caster, {:error, reason}}, _nameid) when is_atom(reason), do: {:error, reason}
  defp finish({_caster, {:error, _reason}}, _nameid), do: {:error, :skill_failed}
end
