defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgTarotcard do
  @moduledoc """
  Tarot Card of Fate succeeds on an `8 * level` percent roll and plays one card
  from the weighted fourteen-card deck on an enemy within nine cells (see
  `Aesir.ZoneServer.Mmo.Skills.Clown.Tarot`). Players and mobs cast the same
  card logic.

  The 40 SP cost is required to start the cast but spent only when a card is
  played; a failed roll or a refused target costs nothing, while the after-cast
  delay and cooldown still apply.

  Renewal: 0.5 s variable plus 0.5 s fixed cast, 0.3 s delay and 3 s cooldown.
  The Sun card also grants thirty seconds of immunity to further cards.

  Pre-renewal: 1 s cast, 3 s delay and no cooldown. A Basilica holder cannot be
  targeted, and the Sun grants no immunity.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 489,
    name: :cg_tarotcard,
    display_name: "Tarot Card of Fate",
    max_level: 5,
    requires: [],
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 9,
    sp_cost: List.duplicate(40, 5),
    cast_time: [renewal: List.duplicate(500, 5), pre_renewal: List.duplicate(1000, 5)],
    fixed_cast_time: [renewal: List.duplicate(500, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(300, 5), pre_renewal: List.duplicate(3000, 5)],
    cooldown: [renewal: List.duplicate(3000, 5), pre_renewal: []],
    damage_kind: :misc

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player, as: PlayerCaster
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Clown.Tarot
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref

  @behaviour Active

  @doc "Requires the resolved SP to start the cast but spends none up front."
  @impl Active
  @spec dynamic_cost(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) :: Cost.t()
  def dynamic_cost(caster, _target, level, definition) do
    caster
    |> Cost.from_definition(definition, level, sp: 0)
    |> Map.put(:sp_requirement, Cost.resolve_sp(caster, definition, level))
  end

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()}
  def cast(caster, {:unit, target}, level, definition) do
    with {:ok, ref} <- target_ref(target),
         {:ok, _card} <- Tarot.play(caster, ref, level) do
      {:ok, charge(caster, definition, level)}
    else
      {:error, _reason} -> {:ok, caster}
    end
  end

  @impl Active
  @spec mob_cast(MobState.t(), term(), pos_integer(), Definition.t(), map()) :: :ok
  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, _definition, _row) do
    Tarot.play(caster, {type, id}, level)
    :ok
  end

  defp charge(%PlayerState{stats: %{current_state: %{sp: sp}}} = caster, definition, level),
    do: PlayerCaster.deduct_sp(caster, min(Enum.at(definition.sp_cost, level - 1), sp))

  defp charge(caster, _definition, _level), do: caster

  defp target_ref(target) do
    if Ref.valid?(target) do
      {:ok, target}
    else
      with {:ok, %{unit_type: type, unit_id: id}} <- Combat.resolve_combatant(target),
           do: {:ok, {type, id}}
    end
  end
end
