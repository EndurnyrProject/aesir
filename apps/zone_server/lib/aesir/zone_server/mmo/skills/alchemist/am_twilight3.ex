defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmTwilight3 do
  @moduledoc """
  Twilight Alchemy 3 (AM_TWILIGHT3).

  A spirit skill on the Alchemist tree: it is never learned with skill points
  and is usable once granted. It costs 200 SP and 200 Medicine Bowls, and its
  cast ignores DEX. When the cast begins, an online Taekwon or Baby Taekwon
  must be in the caster's party, or the cast fails with nothing spent.

  When the cast ends, all three batches must be producible on the inventory as
  it stands (100 Alcohol, 50 Acid Bottles, 50 Fire Bottles; the Fire Bottles'
  Alcohol must already be held) and the first stack of Empty Bottles must hold
  at least 200; otherwise the cast fails without showing itself, with the SP and
  the Medicine Bowls spent. Then the skill shows itself and brews the three
  batches in that order (`TwilightAlchemy`), each with its own production
  result, without checking them again.

  Renewal: a 3 s fixed cast. Pre-renewal: a 3 s cast and a 10 s delay. No
  monster casts it.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 498,
    name: :am_twilight3,
    display_name: "Twilight Alchemy 3",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :none,
    quest_skill: true,
    quest_owner_job: :alchemist,
    ignore_dex: true,
    sp_cost: [200],
    item_cost: [%{id: 7134, amount: 200}],
    cast_time: [renewal: [], pre_renewal: [3_000]],
    fixed_cast_time: [renewal: [3_000], pre_renewal: []],
    after_cast_delay: [renewal: [], pre_renewal: [10_000]]

  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Produce
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.TwilightAlchemy
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @taekwons [:taekwon, :baby_taekwon]
  @alcohol 970
  @acid_bottle 7136
  @fire_bottle 7135
  @empty_bottle 713
  @empty_bottles_needed 200

  @impl Active
  @spec begin_attempt(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :skill_failed}
  def begin_attempt(caster, _target, _level, _definition),
    do: TwilightAlchemy.require_party_member(caster, @taekwons)

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), :skill_failed}
  def cast(%PlayerState{} = caster, :self, _level, _definition) do
    menu = caster.open_menu_skill_id

    with {:ok, alcohol} <- Produce.producible(caster, @alcohol, -1, menu, 100),
         {:ok, acid} <- Produce.producible(caster, @acid_bottle, -1, menu, 50),
         {:ok, fire} <- Produce.producible(caster, @fire_bottle, -1, menu, 50),
         true <- first_stack_amount(caster.inventory, @empty_bottle) >= @empty_bottles_needed do
      {:ok,
       caster
       |> TwilightAlchemy.add_batch(alcohol, 100)
       |> TwilightAlchemy.add_batch(acid, 50)
       |> TwilightAlchemy.add_batch(fire, 50)}
    else
      _cannot_start -> {:failed, caster, :skill_failed}
    end
  end

  # The amount in the lowest slot holding the item; other stacks do not count.
  defp first_stack_amount(inventory, item_id) do
    inventory
    |> Enum.filter(fn {_index, item} -> item.nameid == item_id end)
    |> Enum.min_by(fn {index, _item} -> index end, fn -> {nil, %{amount: 0}} end)
    |> then(fn {_index, item} -> item.amount end)
  end
end
