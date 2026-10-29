defmodule Aesir.ZoneServer.Mmo.Skills.Creator.CrSlimpitcher do
  @moduledoc """
  Aid Condensed Potion (CR_SLIMPITCHER).

  A player throws the level's condensed potion at a cell within 3 cells: a Red
  Slim Potion at levels 1-5, a Yellow Slim Potion at 6-9, a White Slim Potion at
  10. The potion is checked when the cast ends with the other requirements, so
  without it nothing is spent, and it is consumed after the throw even when it
  heals nothing. Its script amounts are read once and scaled by the thrower
  (`Combat.PotionRecovery`'s Slim Pitcher terms), then every unit on the
  thrower's side (`Targeting.ground_allies/4`) in the 7x7 square around the
  cell takes the result scaled by its own VIT, INT and recovery terms. The
  Emperium and battlefield objects take nothing. A monster recipient takes the
  HP only.

  Renewal: a 1 s cast plus 1 s fixed. Pre-renewal: a 1 s cast. Both cost 30 SP
  with a 1 s delay. No monster casts it.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 478,
    name: :cr_slimpitcher,
    display_name: "Aid Condensed Potion",
    max_level: 10,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :none,
    range: 3,
    splash_radius: 3,
    sp_cost: List.duplicate(30, 10),
    cast_time: List.duplicate(1_000, 10),
    fixed_cast_time: [renewal: List.duplicate(1_000, 10), pre_renewal: []],
    after_cast_delay: List.duplicate(1_000, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.PotionRecovery
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPotionpitcher
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @potions {545, 545, 545, 545, 545, 546, 546, 546, 546, 547}
  @emperium 1_288
  @slim_pitcher 478

  @doc "The level's condensed potion, the only item the throw needs."
  @impl Active
  @spec dynamic_item_cost(Active.caster(), Active.target(), pos_integer(), Definition.t()) :: [
          %{id: integer(), amount: pos_integer()}
        ]
  def dynamic_item_cost(_caster, _target, level, _definition),
    do: [%{id: elem(@potions, level - 1), amount: 1}]

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:local_effects, PlayerState.t(), [Active.effect()]}
  def cast(%PlayerState{} = caster, {:ground, x, y}, level, definition) do
    thrown =
      case AmPotionpitcher.read_potion(caster, elem(@potions, level - 1)) do
        {:ok, potion} -> PotionRecovery.slim_throw(potion, PotionRecovery.slim_thrower(caster))
        {:error, _reason} -> {0, 0}
      end

    caster
    |> Targeting.ground_allies(caster.map_name, {x, y}, definition.splash_radius)
    |> Enum.flat_map(&heal(caster, &1, thrown))
    |> case do
      [] -> {:ok, caster}
      effects -> {:local_effects, caster, effects}
    end
  end

  # Heals one recipient and returns the effects the caster's own session must
  # settle (its own Homunculus); every other heal is delivered here.
  defp heal(%PlayerState{character_id: id} = caster, {:player, id} = ref, thrown),
    do: deliver(caster, ref, caster, nil, thrown)

  defp heal(caster, {type, id} = ref, thrown) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, state, pid}} ->
        if protected?(state), do: [], else: deliver(caster, ref, state, pid, thrown)

      {:error, :not_found} ->
        []
    end
  end

  defp deliver(caster, ref, state, pid, thrown) do
    case PotionRecovery.slim_receive(thrown, PotionRecovery.recipient(state, @slim_pitcher)) do
      {hp, sp} = amounts when hp > 0 or sp > 0 -> send_heal(caster, ref, state, pid, amounts)
      _nothing -> []
    end
  end

  defp send_heal(
         %PlayerState{character_id: owner_id},
         {:homunculus, _gid} = ref,
         %HomunculusState{owner_character_id: owner_id},
         pid,
         {hp, sp}
       )
       when pid == self(),
       do: [DamageApplication.local_heal_effect(ref, {:potion, hp, sp}, {:player, owner_id})]

  defp send_heal(caster, {:mob, id}, _state, _pid, {hp, _sp}) do
    if hp > 0, do: Combat.apply_heal(:mob, id, hp, caster.character_id)
    []
  end

  defp send_heal(caster, {type, id}, _state, _pid, {hp, sp}) do
    Combat.apply_heal(type, id, {:potion, hp, sp}, caster.character_id)
    []
  end

  defp protected?(%MobState{mob_id: @emperium}), do: true
  defp protected?(%MobState{} = mob), do: MobState.monster_class(mob) == :battlefield
  defp protected?(_state), do: false
end
