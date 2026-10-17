defmodule Aesir.ZoneServer.Mmo.Skill.Unit.TrapCombat do
  @moduledoc """
  Hunter trap targeting and durability, separate from the trap's trigger state.

  Destructible traps have 3,500 durability. Exhaustion is observed on their next
  cell-timer pass, not at damage delivery: a captured Ankle Snare disappears,
  and other traps become untargetable used traps for 1.5 seconds. Talkie Box
  accepts attacks without losing durability, even after it starts talking.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState

  @destructible [
    :ht_blastmine,
    :ht_skidtrap,
    :ht_landmine,
    :ht_shockwave,
    :ht_sandman,
    :ht_flasher,
    :ht_claymoretrap,
    :ht_freezingtrap,
    :ht_anklesnare
  ]
  @traps [:ht_talkiebox | @destructible]

  @doc "Default combat attributes for one materialized Hunter trap cell."
  @spec cell_attrs(Group.t()) :: map()
  def cell_attrs(%Group{skill_name: name, state: %{trap: %TrapState{}}}) when name in @traps do
    hp = if name == :ht_talkiebox, do: 1, else: 3_500

    %{
      hp: hp,
      max_hp: hp,
      flags: [:targetable],
      state: %{trap_target: true, ignores_damage: name == :ht_talkiebox}
    }
  end

  def cell_attrs(_group), do: %{}

  @doc "Whether a cell is still a live attack target, including an exhausted trap awaiting its timer."
  @spec targetable?(Cell.t()) :: boolean()
  def targetable?(%Cell{state: %{trap_target: true}, group_id: group_id}) do
    case Storage.get(group_id) do
      %Group{skill_name: :ht_talkiebox, state: %{trap: %{phase: :used}}} -> true
      %Group{state: %{trap: %{phase: phase}}} -> phase in [:armed, :captured, :spent]
      _gone -> false
    end
  end

  def targetable?(%Cell{hp: hp}), do: hp > 0

  @doc "How a cell accepts damage: ordinary cell removal, trap durability, or no damage."
  @spec damage_mode(Cell.t()) :: :ordinary | :durability | :ignore
  def damage_mode(%Cell{state: %{trap_target: true, ignores_damage: true}}), do: :ignore

  def damage_mode(%Cell{state: %{trap_target: true}} = cell),
    do: if(targetable?(cell), do: :durability, else: :ignore)

  def damage_mode(_cell), do: :ordinary

  @doc "The exhausted trap's action before its timer can affect any units."
  @spec exhaustion(Cell.t(), Group.t()) :: :none | :used | :expire
  def exhaustion(
        %Cell{hp: 0, state: %{trap_target: true, ignores_damage: false}},
        %Group{skill_name: :ht_anklesnare, state: %{trap: %{phase: :captured}}}
      ),
      do: :expire

  def exhaustion(
        %Cell{hp: 0, state: %{trap_target: true, ignores_damage: false}},
        %Group{state: %{trap: %{phase: phase}}}
      )
      when phase in [:armed, :spent], do: :used

  def exhaustion(_cell, _group), do: :none

  @doc "Whether a naturally expired trap still has durability to return its item."
  @spec intact?(Group.t()) :: boolean()
  def intact?(group) do
    group.group_id
    |> Storage.get_cells_by_group()
    |> Enum.all?(fn
      %Cell{state: %{trap_target: true}, hp: hp} -> hp > 0
      _other -> true
    end)
  end
end
