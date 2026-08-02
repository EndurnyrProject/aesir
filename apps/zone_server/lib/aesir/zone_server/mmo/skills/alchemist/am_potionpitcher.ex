defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPotionpitcher do
  @moduledoc """
  Potion Pitcher (AM_POTIONPITCHER).

  The caster's skill bonuses are applied before delivery. A tagged heal descriptor
  then lets the recipient session apply its own potion recovery stats before the
  ordinary received-heal-rate step, without reading another player's state from
  the caster process.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 231,
    name: :am_potionpitcher,
    display_name: "Potion Pitcher",
    max_level: 5,
    target_type: :target_ally,
    damage_type: :no_damage,
    range: 9,
    sp_cost: List.duplicate(1, 5),
    after_cast_delay: List.duplicate(500, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @learning_potion_id 227
  @potions %{
    1 => {501, :hp, 45, 65},
    2 => {502, :hp, 105, 145},
    3 => {503, :hp, 175, 235},
    4 => {504, :hp, 325, 405},
    5 => {505, :sp, 40, 60}
  }

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_target}
  def validate(%PlayerState{character_id: id}, target, _level, _definition)
      when target in [:self, {:unit, id}],
      do: :ok

  def validate(%PlayerState{} = caster, {:unit, target_id}, _level, _definition) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, %PlayerState{} = target, _pid}} ->
        if Unit.living?(target) and allied?(caster, target),
          do: :ok,
          else: {:error, :invalid_target}

      _ ->
        {:error, :invalid_target}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{} = caster, target, level, definition) do
    {item_id, resource, minimum, maximum} = potion_for_level(level)

    with :ok <- validate(caster, target, level, definition),
         index when not is_nil(index) <- ItemContainer.stackable_index(caster.inventory, item_id),
         {:ok, inventory, change} <- ItemContainer.remove(caster.inventory, index, 1) do
      amount =
        minimum
        |> roll(maximum)
        |> scale_caster_bonus(level, learning_potion_level(caster))

      target_id = Active.resolve_target_id(caster, target)
      Combat.apply_heal(:player, target_id, {:potion, resource, amount}, caster.character_id)

      {:ok,
       %{
         caster
         | inventory: inventory,
           pending_inventory_persist:
             caster.pending_inventory_persist ++ [{caster.inventory, inventory, change}]
       }}
    else
      nil -> {:error, :missing_potion}
      {:error, :not_found} -> {:error, :missing_potion}
      {:error, :insufficient_amount} -> {:error, :missing_potion}
      {:error, _reason} = error -> error
    end
  end

  @doc false
  @spec potion_for_level(1..5) :: {501..505, :hp | :sp, pos_integer(), pos_integer()}
  def potion_for_level(level), do: Map.fetch!(@potions, level)

  @doc false
  @spec scale_caster_bonus(non_neg_integer(), pos_integer(), non_neg_integer()) ::
          non_neg_integer()
  def scale_caster_bonus(amount, level, learning_potion_level) do
    div(amount * (100 + 10 * level + 5 * learning_potion_level), 100)
  end

  defp roll(minimum, maximum), do: minimum + :rand.uniform(maximum - minimum + 1) - 1

  defp learning_potion_level(caster) do
    Learned.learned_level(caster.stats.progression.learned_skills, @learning_potion_id)
  end

  defp allied?(%PlayerState{} = caster, %PlayerState{} = target) do
    (caster.party_id != 0 and caster.party_id == target.party_id) or
      (caster.guild_id != 0 and caster.guild_id == target.guild_id)
  end
end
