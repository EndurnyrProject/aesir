defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoInvestigate do
  @moduledoc """
  Occult Impaction (MO_INVESTIGATE).

  A single-target physical strike, usable against any enemy in range. It deals
  bonus damage when the target is the Monk's own linked Root peer, closing the
  pair after the hit lands.
  """

  @sp_costs Enum.map(1..5, &Aesir.ZoneServer.Mmo.Skills.Monk.Formulas.occult_sp_cost/1)
  @timing Aesir.ZoneServer.Mmo.Skills.Monk.Formulas.occult_timing()

  use Aesir.ZoneServer.Mmo.Skill,
    id: 266,
    name: :mo_investigate,
    # Player-coupled at runtime (character_id), but not on the pre-migration mob denylist.
    # Kept mob-selectable with [] to preserve exact pre-migration behaviour; a mob caster
    # falls through to the {:error, :invalid_target} clause as it does today.
    requires: [],
    display_name: "Occult Impaction",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 2,
    sp_cost: @sp_costs,
    sphere_cost: List.duplicate(1, 5),
    cast_time: List.duplicate(@timing.cast_time, 5),
    fixed_cast_time: List.duplicate(@timing.fixed_cast_time, 5),
    after_cast_delay: List.duplicate(@timing.after_cast_delay, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Root
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    with {:ok, target_type, _position} <- Combat.resolve_target_position(target_id) do
      attack(caster, caster_id, target_id, level, definition, target_type)
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  defp attack(caster, caster_id, target_id, level, definition, target_type) do
    with :ok <- Root.check_cast(:player, caster_id, definition.id),
         opts <- attack_opts(definition, level, target_type, target_id),
         :ok <- Combat.execute_skill_attack(caster, target_id, opts) do
      if Root.rooted?(:player, caster_id), do: Root.close(:player, caster_id)
      {:ok, caster}
    end
  end

  defp attack_opts(definition, level, target_type, target_id) do
    [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: Formulas.occult_ratio(level, Root.rooted?(target_type, target_id)),
      skip_crit: true,
      skip_range: true
    ]
  end
end
