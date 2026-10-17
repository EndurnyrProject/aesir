defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AscEdp do
  @moduledoc """
  Enchant Deadly Poison strengthens the caster's weapon attacks and grants
  an additional 25 percent poison property, without replacing the weapon element.

  Renewal lasts 40 to 120 seconds, has a two-second cooldown, requires a
  right-hand weapon and consumes one EDP-group bottle, preferring the bound
  bottle when both shipped variants are held. Classic lasts 40 to 60 seconds,
  has a two-second action delay, permits bare hands and consumes a Poison Bottle.
  Both modes cost 60 to 100 SP. The EDP status owns its damage and poison rules.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 378,
    name: :asc_edp,
    display_name: "Enchant Deadly Poison",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :weapon,
    element: :poison,
    sp_cost: [60, 70, 80, 90, 100],
    duration: [
      renewal: [40_000, 60_000, 80_000, 100_000, 120_000],
      pre_renewal: [40_000, 45_000, 50_000, 55_000, 60_000]
    ],
    cooldown: [renewal: List.duplicate(2_000, 5), pre_renewal: []],
    after_cast_delay: [renewal: [], pre_renewal: List.duplicate(2_000, 5)],
    item_cost: [%{id: 678, amount: 1}]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Element
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(
        %PlayerState{stats: %{equipment: %{right_hand: nil}}},
        _target,
        _level,
        _definition
      ) do
    if GameMode.mode() == :renewal, do: {:error, :wrong_weapon}, else: :ok
  end

  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  @doc "Selects the mode's bottle requirement from the current inventory."
  @spec dynamic_item_cost(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          [Definition.item_cost_entry()]
  def dynamic_item_cost(caster, _target, _level, definition) do
    with :renewal <- GameMode.mode(),
         {:ok, group} <- ItemGroups.fetch(:edp),
         %{item_id: id} <-
           group.subgroups
           |> Enum.flat_map(&Enum.reverse(&1.entries))
           |> Enum.find(&(Inventory.held_amount(caster.inventory, &1.item_id) > 0)) do
      [%{id: id, amount: 1}]
    else
      _missing_or_classic -> definition.item_cost
    end
  end

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, _target, level, definition) do
    adapter = Caster.for(caster)
    type = adapter.unit_type(caster)
    id = adapter.id(caster)
    duration = Enum.at(definition.duration, level - 1, List.last(definition.duration))

    {aura, marker} =
      if GameMode.mode() == :renewal,
        do: {:sc_sub_weaponproperty, definition.id},
        else: {:sc_watk_element, 0}

    source = [caster_id: id, source_type: type, duration: duration]

    Interpreter.apply_status(type, id, :sc_edp, [val1: level] ++ source)

    Interpreter.apply_status(
      type,
      id,
      aura,
      [val1: Element.id(:poison), val2: 25, val3: marker] ++ source
    )

    {:ok, caster}
  end
end
