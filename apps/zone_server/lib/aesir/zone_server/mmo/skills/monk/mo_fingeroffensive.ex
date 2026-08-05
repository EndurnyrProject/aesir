defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoFingeroffensive do
  @moduledoc """
  Throw Spirit Sphere (MO_FINGEROFFENSIVE).

  A five-hit physical strike that costs a single spirit sphere under the local
  default multi-hit configuration, usable against any enemy in range. It deals
  bonus damage when the target is the Monk's own linked Root peer, closing the
  pair after the volley lands, and briefly locks the Monk's own movement above
  level 1.
  """

  @sp_costs Enum.map(
              1..5,
              &Aesir.ZoneServer.Mmo.Skills.Monk.Formulas.throw_spirit_sphere_sp_cost/1
            )
  @timing Aesir.ZoneServer.Mmo.Skills.Monk.Formulas.throw_spirit_sphere_timing()
  @sphere_cost Aesir.ZoneServer.Mmo.Skills.Monk.Formulas.throw_spirit_sphere_cost()
  @hit_count Aesir.ZoneServer.Mmo.Skills.Monk.Formulas.throw_spirit_sphere_hit_count()

  use Aesir.ZoneServer.Mmo.Skill,
    id: 267,
    name: :mo_fingeroffensive,
    # Player-coupled at runtime (character_id), but accepted by the previous mob gate.
    # Kept mob-selectable with [] to preserve exact pre-migration behaviour; a mob caster
    # falls through to the {:error, :invalid_target} clause as it does today.
    requires: [],
    display_name: "Throw Spirit Sphere",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 9,
    hit_count: @hit_count,
    sp_cost: @sp_costs,
    sphere_cost: List.duplicate(@sphere_cost, 5),
    cast_time: List.duplicate(@timing.cast_time, 5),
    fixed_cast_time: List.duplicate(@timing.fixed_cast_time, 5),
    after_cast_delay: List.duplicate(@timing.after_cast_delay, 5),
    cooldown: List.duplicate(@timing.cooldown, 5)

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

      updated =
        PlayerState.apply_walk_delay(
          caster,
          Formulas.throw_spirit_sphere_walk_delay(level),
          now()
        )

      {:ok, updated}
    end
  end

  defp attack_opts(definition, level, target_type, target_id) do
    [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio:
        Formulas.throw_spirit_sphere_ratio(level, Root.rooted?(target_type, target_id)),
      hit_count: definition.hit_count,
      skip_crit: true,
      skip_range: true
    ]
  end

  defp now, do: System.monotonic_time(:millisecond)
end
