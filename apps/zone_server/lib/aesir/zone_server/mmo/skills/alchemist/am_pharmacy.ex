defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPharmacy do
  @moduledoc """
  Pharmacy (AM_PHARMACY) opens a menu of the Pharmacy recipes the caster can make
  now and brews its selection.

  A recipe is listed when the can-produce check (`Production.Produce.producible/4`)
  accepts it at item level 22: its materials are held, one more product fits and
  no other skill's menu is open. A reply is checked again and dropped silently
  when the recipe stopped being makeable. Both modes brew with the same success
  formula for 5 SP and a Medicine Bowl.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 228,
    name: :am_pharmacy,
    display_name: "Pharmacy",
    max_level: 10,
    target_type: :self,
    sp_cost: List.duplicate(5, 10),
    item_cost: [%{id: 7134, amount: 1}],
    damage_kind: :none

  @behaviour Aesir.ZoneServer.Mmo.Skill.Active
  @behaviour Aesir.ZoneServer.Mmo.Skill.Menu

  alias Aesir.ZoneServer.Mmo.Homunculus.Stats, as: HomunculusStats
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Forge
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Produce
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @pharmacy_skill_id 228
  # The item level the Pharmacy list and its replies accept.
  @trigger 22

  @doc "Stages the recipes available at the cast Pharmacy level."
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), :no_materials}
  @impl Aesir.ZoneServer.Mmo.Skill.Active
  def cast(%PlayerState{} = caster, :self, level, _definition) do
    case Produce.offer(caster, @trigger, caster.open_menu_skill_id, @pharmacy_skill_id) do
      [] ->
        # The reference sends the (empty) recipe list after the requirement is
        # paid, so the refusal keeps the cost and reports the failure.
        {:failed, caster, :no_materials}

      product_ids ->
        offer = %{
          skill_id: @pharmacy_skill_id,
          kind: :ITEMS,
          entry_ids: product_ids,
          level: level
        }

        {:ok, %{caster | pending_menu_offer: offer}}
    end
  end

  @doc "Brews the selected Pharmacy recipe without forge catalysts."
  @spec on_menu_reply(
          PlayerState.t(),
          %{id: non_neg_integer(), extras: [non_neg_integer()]},
          pos_integer()
        ) :: {:ok, PlayerState.t()} | {:silent, PlayerState.t()} | {:error, atom()}
  @impl Aesir.ZoneServer.Mmo.Skill.Menu
  def on_menu_reply(%PlayerState{} = caster, selection, level) do
    on_menu_reply(caster, selection, level, %{homunculus: nil})
  end

  @doc """
  Brews the selected Pharmacy recipe with session-owned Homunculus context; a
  selection no longer makeable does nothing, and a reply while trading fails the
  skill.
  """
  @spec on_menu_reply(
          PlayerState.t(),
          %{id: non_neg_integer(), extras: [non_neg_integer()]},
          pos_integer(),
          %{required(:homunculus) => HomunculusState.t() | nil, optional(atom()) => term()}
        ) :: {:ok, PlayerState.t()} | {:silent, PlayerState.t()} | {:error, atom()}
  @impl Aesir.ZoneServer.Mmo.Skill.Menu
  def on_menu_reply(_caster, _selection, _level, %{trading?: true}), do: {:error, :skill_failed}

  def on_menu_reply(
        %PlayerState{} = caster,
        %{id: product_id},
        _level,
        %{homunculus: homunculus}
      ) do
    case Produce.producible(caster, product_id, @trigger, @pharmacy_skill_id) do
      {:ok, recipe} -> Forge.run(caster, recipe, [], active_instruction_change_rank(homunculus))
      :error -> {:silent, caster}
    end
  end

  defp active_instruction_change_rank(%HomunculusState{} = homunculus) do
    if HomunculusState.living?(homunculus),
      do: HomunculusStats.instruction_change_rank(homunculus),
      else: 0
  end

  defp active_instruction_change_rank(nil), do: 0
end
