defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Edp do
  @moduledoc """
  Enchant Deadly Poison strengthens weapon attacks without replacing their element.

  Renewal scales card-adjusted weapon and equipment ATK by 250 plus 30 per
  level percent, except for Sand Attack, Venom Splasher, Meteor Assault,
  Grimtooth and Venom Knife. Classic adds 50 times (level plus one) percent
  to right-hand damage after its elemental and mastery steps.

  Both modes grant a chance to inflict Deadly Poison on surviving targets of
  connected normal attacks. Research New Poison extends a fresh application
  by 30 seconds plus 15 seconds per learned level. The buff survives death
  and Dispel; only classic discards it on logout. Renewal ends it when the
  right-hand weapon is removed.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_edp,
    no_dispel: true,
    no_clear_buff: false,
    no_save: [renewal: false, pre_renewal: true],
    remove_on_death: false,
    flags: [renewal: [:remove_on_unequip_weapon], pre_renewal: []],
    properties: [:buff],
    calc_flags: [renewal: [:watk], pre_renewal: []],
    icon: :edp

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  @spec resolve_duration(Definition.target(), StatusEntry.t(), pos_integer()) ::
          {pos_integer(), StatusEntry.t()}
  def resolve_duration(target, entry, duration) do
    damage_rate = if GameMode.mode() == :pre_renewal, do: 50 * (entry.val1 + 1), else: 0

    {duration + duration_bonus(target),
     %{entry | val2: div(entry.val1 + 1, 2) + 2, val3: damage_rate}}
  end

  @doc "The live player's Research New Poison duration extension, or zero for other units."
  @spec duration_bonus(Definition.target()) :: non_neg_integer()
  def duration_bonus({:player, id}) do
    with {:ok, {_, %{stats: %{progression: %{learned_skills: learned}}}, _}} <-
           UnitRegistry.get_unit(:player, id),
         level when level > 0 <- Learned.learned_level(learned, 2024) do
      30_000 + 15_000 * level
    else
      _none -> 0
    end
  end

  def duration_bonus(_target), do: 0
end
